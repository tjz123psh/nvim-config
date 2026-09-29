-- ============================================
-- Neovide GUI 专用配置
-- 只有在 Neovide 中启动时才会加载
-- ============================================

if not vim.g.neovide then
  return
end

-- 缩放比例（默认 1.0）
vim.g.neovide_scale_factor = 1.0

-- 窗口不透明度（0.8 = 80% 不透明，20% 透出桌面）
-- 由 <leader>uo 选择框**持久化**管理（2026-09-29 起）：选一次就定下来，重启后仍是那个值。
--   值写在一行文件里：stdpath("state")/neovide-opacity（读写函数见本文件下方）。
--   下面这行只是「还没选过」时的出厂默认；文件一旦存在就以文件为准。
--   想回出厂默认：删掉那个文件；或者选 0.80 也一样（文件会留着，值等于默认）。
vim.g.neovide_opacity = 0.80

-- 光标特效风格
vim.g.neovide_cursor_vfx_mode = "railgun"

-- 设置字体（Linux 下优先使用 JetBrainsMono Nerd Font）
local font = "JetBrainsMono Nerd Font:h12"
if vim.fn.has("linux") == 1 and vim.fn.executable("fc-match") == 1 then
  local matched = vim.fn.systemlist({ "fc-match", "JetBrainsMono Nerd Font" })[1] or ""
  if not matched:lower():find("jetbrains", 1, true) then
    font = "monospace:h12"
  end
end
vim.o.guifont = font

-- 刷新率（Hz）
vim.g.neovide_refresh_rate = 60

-- 窗口圆角：原写法 neovide_corner_style **不是 Neovide 的选项**（静默无效的死配置），
-- 已订正为 neovide_corner_preference（0.16.0+）；官方标注 Windows only ⇒ Linux 下不生效，
-- 保留正确写法以便上游将来支持（本机 Neovide 0.16.2，已核对官方 configuration.html）。
vim.g.neovide_corner_preference = "round"

-- 打字光标动画
vim.g.neovide_cursor_short_animation_length = 0.13

-- ============================================
-- 缩放快捷键（仅 Neovide，终端里的 nvim 由终端负责缩放）
-- 通过动态改写 neovide_scale_factor 实现，步进 10%
-- ============================================
local function change_scale(delta)
  local current = vim.g.neovide_scale_factor or 1.0
  local next_scale = current + delta
  -- 夹在 0.5x ~ 3.0x，避免缩到看不见或放到卡顿
  next_scale = math.min(3.0, math.max(0.5, next_scale))
  vim.g.neovide_scale_factor = next_scale
end

local map = vim.keymap.set
map("n", "<C-=>", function()
  change_scale(0.1)
end, { desc = "Neovide 放大" })
map("n", "<C-->", function()
  change_scale(-0.1)
end, { desc = "Neovide 缩小" })
map("n", "<C-0>", function()
  vim.g.neovide_scale_factor = 1.0
end, { desc = "Neovide 重置缩放" })

-- ============================================
-- 不透明度：选择框调（2026-09-29）
-- ============================================
-- 为什么用选择框而不是像缩放那样加减键：
--   1) <C-=> / <C--> / <C-0> 已经被缩放占了，再占 Ctrl 组合不划算；
--   2) 不透明度是「挑一档」而不是「微调」，直接选比连按更省事；
--   3) vim.ui.select 已经被 snacks 接管（全机唯一选择器）⇒ 拿到的是同一套紧凑卡片 UI。
-- ✅ 选完会**持久化**：写进 stdpath("state")/neovide-opacity，重启 Neovide 仍是这个值。
--   之所以要自己存：Neovide 的 neovide-settings.json 只存窗口几何、不存不透明度
--   （实测：改成 0.5 → 退出 → 重启又回到文件里的默认值）。
--   （:NeovideConfig 打开的 ~/.config/neovide/config.toml 在 Linux 上不被读取，别指望它。）
local OPACITY_STEPS = {
  { 1.00, "1.00 —— 完全不透明" },
  { 0.95, "0.95" },
  { 0.90, "0.90" },
  { 0.85, "0.85" },
  { 0.80, "0.80 —— 出厂默认" },
  { 0.70, "0.70" },
  { 0.60, "0.60" },
  { 0.50, "0.50 —— 最透（字会开始不好认）" },
}

--- 持久化文件：一行数字。Neovide 自己不存不透明度（neovide-settings.json 只有窗口几何），
--- 所以这里自己存，实现「选一次就定下来」。
local STATE_FILE = vim.fs.joinpath(vim.fn.stdpath("state"), "neovide-opacity")

--- 读已保存的值。文件不存在 / 读不出 / 不是 0~1 的数 ⇒ 返回 nil（调用方回落到出厂默认）
--- @return number?
local function load_saved_opacity()
  local f = io.open(STATE_FILE, "r")
  if not f then
    return nil
  end
  local raw = f:read("*l")
  f:close()
  local n = tonumber(raw)
  if not n or n < 0 or n > 1 then
    return nil -- 文件被改坏就当没存过，别把非法值喂给 Neovide
  end
  return n
end

--- 保存选择。写失败只警告不抛错（例如目录不可写）
--- @param value number
local function save_opacity(value)
  local f, err = io.open(STATE_FILE, "w")
  if not f then
    vim.notify("不透明度已生效，但保存失败：" .. tostring(err), vim.log.levels.WARN)
    return
  end
  f:write(string.format("%.2f\n", value))
  f:close()
end

--- 当前不透明度：已保存的值优先，否则用出厂默认（Neovide 自身默认 1.0）
--- @return number
local function current_opacity()
  return load_saved_opacity() or vim.g.neovide_opacity or 1.0
end

-- 启动即套用已保存的值；没有文件就什么都不做，保持上面那行出厂默认
do
  local saved = load_saved_opacity()
  if saved then
    vim.g.neovide_opacity = saved
  end
end

--- 弹出选择框调不透明度；选中后回车确认、Esc 取消（保持原值）。
--- ⚠ 没有「上下移动即实时预览」：预览要在确认时才生效。曾把 prompt 写成「上下预览」，
---   实测（打开框不确认、读 vim.g.neovide_opacity）值不变 ⇒ 那句是假的，已改掉。
---   想要实时预览就得用 snacks 的 on_move（cursor 变即套用），但它和「Esc 还原原值」
---   需要额外的原值兜底，复杂度不值当 —— 需要的话再说。
local function pick_opacity()
  local original = current_opacity()
  local items = {}
  for _, s in ipairs(OPACITY_STEPS) do
    items[#items + 1] = { value = s[1], label = s[2] }
  end
  -- 当前值不在预设档位里（比如手动设过 0.83）时补一个进去，避免框里看不出「现在是多少」
  local has_current = false
  for _, it in ipairs(items) do
    if math.abs(it.value - original) < 0.001 then
      has_current = true
      break
    end
  end
  if not has_current then
    table.insert(items, 1, { value = original, label = string.format("%.2f —— 当前值", original) })
  end

  vim.ui.select(items, {
    prompt = "不透明度（回车确认，Esc 取消）",
    format_item = function(it)
      local mark = math.abs(it.value - original) < 0.001 and "● " or "  "
      return mark .. it.label
    end,
  }, function(choice)
    -- ⚠ 应用必须写在回调**内部**：vim.ui.select 的回调可能同步也可能异步
    --   （snacks 走 vim.schedule），写成「select 之后再赋值」会拿旧值把预览顶掉。
    local target = choice and choice.value or original
    vim.g.neovide_opacity = target
    if choice and math.abs(target - original) > 0.001 then
      save_opacity(target) -- 选一次就定下来：写文件，下次启动自动套用
      vim.notify(
        string.format("不透明度 = %.2f（已记住，重启后仍是这个值）", target),
        vim.log.levels.INFO
      )
    end
  end)
end

map("n", "<leader>uo", pick_opacity, { desc = "Neovide 不透明度（选择框）" })
