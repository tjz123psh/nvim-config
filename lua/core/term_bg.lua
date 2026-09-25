-- ============================================
-- 终端窗口实底背景（配合透明主题）
-- ============================================
-- 为什么需要：本配置主题开了 transparent_background ⇒ 全局 Normal 的 bg 是 NONE，
-- 于是 :terminal / toggleterm 浮窗 / sidekick 的 AI CLI 面板都会透出桌面壁纸；
-- 而 CLI 的配色是按「实底终端」设计的，暗色文字糊在壁纸上 = 用户说的「两种主题叠加」。
-- 这里统一给终端窗口补实底（与 picker / 状态栏同色 base #1e1e2e），编辑区仍保持透明。
--
-- ⚠ 两个要点（都实测过）：
--   1. **浮窗背景用的是 NormalFloat，不只是 Normal** —— 只映射 Normal 对浮窗无效；
--   2. toggleterm 在 open() 里先 ui.hl_term() 覆盖 winhighlight、之后才调 on_open
--      （terminal.lua:504）⇒ 它的终端必须在 on_open 里再补一次，光靠 TermOpen 会被盖掉。

local M = {}

local HL = "TermSolidBg"

function M.define()
  local ok, pal = pcall(function()
    return require("catppuccin.palettes").get_palette()
  end)
  vim.api.nvim_set_hl(0, HL, { bg = ok and pal.base or "#1e1e2e" })
end

--- 给某个窗口补实底（保留它原有的 winhighlight 条目）
--- @param win integer?
function M.apply(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  M.define()
  local wh = vim.wo[win].winhighlight or ""
  local add = ("Normal:%s,NormalFloat:%s,NormalNC:%s"):format(HL, HL, HL)
  vim.wo[win].winhighlight = wh ~= "" and (wh .. "," .. add) or add
end

function M.setup()
  M.define()
  vim.api.nvim_create_autocmd({ "TermOpen", "ColorScheme" }, {
    callback = function()
      M.define()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal" then
          M.apply(win)
        end
      end
    end,
    desc = "终端窗口实底背景（透明主题下不透出壁纸）",
  })
end

return M
