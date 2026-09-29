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
-- ⚠ 只作用于**本次会话**：重启 Neovide 仍读上面的 vim.g.neovide_opacity。
--   要永久固定某个值，改上面那一行（或用 :NeovideConfig，不过实测它打开的
--   ~/.config/neovide/config.toml 在 Linux 上并不被读取，别指望它）。
local OPACITY_STEPS = {
  { 1.00, "1.00 —— 完全不透明" },
  { 0.95, "0.95" },
  { 0.90, "0.90" },
  { 0.85, "0.85" },
  { 0.80, "0.80 —— 默认值（neovide.lua 里那个）" },
  { 0.70, "0.70" },
  { 0.60, "0.60" },
  { 0.50, "0.50 —— 最透（字会开始不好认）" },
}

--- 当前不透明度（Neovide 默认 1.0）
local function current_opacity()
  return vim.g.neovide_opacity or 1.0
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
      vim.notify(
        string.format("不透明度 = %.2f（仅本次会话；要持久改 lua/neovide.lua）", target),
        vim.log.levels.INFO
      )
    end
  end)
end

map("n", "<leader>uo", pick_opacity, { desc = "Neovide 不透明度（选择框）" })
