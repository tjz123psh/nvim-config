-- ============================================
-- 输入类浮窗的统一几何：snacks 输入框 ↔ noice 命令行弹窗
-- ============================================
-- 为什么单独一个模块：这两个「打字用的浮窗」由不同插件画，但用户要求它们看起来是
-- **同一对框** —— 一样长、一样低（2026-09-26 用户截图反馈）。两边的「宽度」口径不同、
-- 差 2 列，写死在两个文件里迟早漂移，所以这里做唯一事实源：
--   • snacks 输入框（vim.ui.input）：win.width = **内容宽**，边框画在窗口之外 ⇒ 总宽 = width + 2
--   • noice 弹窗（cmdline_popup / cmdline_input）：size.min_width = 内容宽，
--     外面还有 border(1+1) + border.padding(1+1) ⇒ 总宽 = min_width + 4
--   ⇒ 等长条件：noice_min_width = width − 2
-- 垂直方向：**两边配置里的 row 都是"边框行"（0 基）**，所以用同一个公式就重合：
--   noice 的 position.row = "50%" 落在 floor((lines − 3) / 2)（弹窗 3 行：边框/内容/边框，
--   它的第 1 行缓冲内容就是边框）；snacks 的 win.row 同理 —— 配 13 时屏幕第 14 行是 ╭、
--   15 行是内容、16 行是 ╰。⇒ center_row() = floor((lines − 3) / 2)。
-- ⚠ 别用 nvim_win_get_position 去"对齐"：对带边框的浮窗它返回的是**边框行**，而 noice 内部那个
--   无边框的输入子窗返回的是**内容行**，拿这两个数比会正好差一行 —— 本轮先按 floor((lines−1)/2)
--   写过一版，就是这么错的，靠 screenstring() 读屏幕帧（第 14/15/16 行 vs 15/16/17）才发现。
-- ⚠ 两个约束：
--   1) noice 的 min_width 只能是**数字**（noice/util/nui.lua:158 的 minmax 直接进 math.max），
--      所以宽度是常量；而 snacks 的 row/width 支持函数（snacks/win.lua:1281）⇒ 位置能在开窗时求值。
--   2) snacks 输入框默认 expand = true：内容比 width 长时会自己变宽（max(width, 文本宽 + 5)）。
-- 实测（真 pty + screenstring 读真实屏幕）：
--   114×30：命令行框 82 列 @ 第 17~98 列；短默认值输入框 82 列 @ 17~98（**逐列相同**）；
--           预填长路径（77 字符）时输入框按 expand 撑到 84 列 @ 16~99（居中，左右各多 1 列）。
--   两者的顶边框/内容/底边框都落在第 14/15/16 行。
-- ⚠ 窄终端：总宽 82 ⇒ ≥86 列完整显示；80~85 列时两个框**一起**贴边（各裁 1~2 列边框）——
--   这是"两边等长"的必然代价，想让 80 列也完整就把 M.width 降到 76（总宽 78），
--   代价是命令行框也一起变短。别只改一边，否则两个框又不一样长了。
-- 调节：想把两个框整体放低/加宽，只改这里的 width 与 center_row() 即可。
local M = {}

-- 内容宽（snacks 口径）。总宽 = 80 + 2 = 82，与 noice 的 78 + 4 相等。
M.width = 80

-- noice 口径的内容宽（= M.width − 2），供 cmdline_popup / cmdline_input 的 size.min_width
M.noice_min_width = M.width - 2

--- 与 noice 命令行弹窗重合的行号（0 基**边框行**，给 snacks 输入框的 win.row 用）
--- @return integer
function M.center_row()
  return math.floor((vim.o.lines - 3) / 2)
end

return M
