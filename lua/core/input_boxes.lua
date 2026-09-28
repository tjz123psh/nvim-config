-- ============================================
-- 输入类浮窗的统一几何：snacks 输入框 ↔ noice 命令行弹窗
-- ============================================
-- 为什么单独一个模块：这两个「打字用的浮窗」由不同插件画，但用户要求它们看起来是
-- **同一对框** —— 一样长、一样低（2026-09-26 用户截图反馈）。两边的「宽度」口径不同，
-- 写死在两个文件里迟早漂移，所以这里做唯一事实源。
-- 实测出来的盒模型（2026-09-28 真 pty + nvim_win_get_config / get_width）：
--   • snacks 输入框：win.width = **内容宽** ⇒ 总宽 = width + 2
--   • noice 弹窗（cmdline_popup / cmdline_input）：size.min_width = 内容宽，
--     外面还有 border(1+1) + 内边距(1+1) ⇒ 总宽 = min_width + 6
--   ⚠ 那个「内边距 1+1」是 noice 自己的默认值（border.padding 未显式配置时由 nui 补），
--     不是猜的：114 列下配 min_width=78 实测外框 w=82、内容 w=78 ⇒ 78+4=82；
--     80 列下配 72 实测外框 76 ⇒ 72+4=76。两处都对上 ⇒ 偏移量恒为 4（不含左右边框）。
--   ⇒ 等长条件：noice_min_width = 内容宽 − 4（**不是 −2**）。旧实现少减了 2，
--     所以两个框一直差 2 列 —— 本轮实测 80 列：输入框 74 vs 命令行 76。
-- 垂直方向：noice 的 position.row = 50% 落在 floor((lines−3)/2)，
--   snacks 的 win.row 也配 floor((lines−3)/2)；但实测两个框**差 1 行**（80×24：输入框 row=10、
--   命令行边框 row=11；114×30 同样是 13 vs 14）。这条差异**先于本轮的宽度修复存在**
--   （旧宽度下两框也都是差 1 行），本轮只修宽度，行号差 1 的原样记在这里待查。
-- ⚠ noice 的 min_width 只能是**数字**（noice/util/nui.lua:158 的 minmax 直接进 math.max）；
--   snacks 的 row/width 支持函数（snacks/win.lua:1281）⇒ 宽度能按开窗时的屏幕列数求值。
--   因此下面给出两种口径：width() 给 snacks（开窗求值、跟随 resize），
--   noice_min_width() 是**数字快照**（配置加载时取一次，改终端大小需重启才跟上）。
-- ============================================
-- 宽度策略（2026-09-28 审查 U01 修复）
-- 旧实现把内容宽写死 80 ⇒ 命令行总宽 82，80 列的终端上右边框被推出屏幕：
--   真 pty 实测 80x24 —— 浮窗 w=82 col=-1，屏幕第 11 行右角消失、边框被挤到第 12 行、
--   第 13 行右端出现 @@@ 溢出标记（78 列更糟，col=-2）。
-- 现在按屏幕列数收缩，并给两侧各留余量（114 列下与旧实现同为 82 ⇒ 宽屏零回归）：
--   内容宽 = clamp(columns − reserved, 30, max_width)。
local M = {}

--- 内容宽的上限（columns 足够大时就用它，保持宽屏观感不变）
M.max_width = 80

--- 两侧各留的列数余量：避免圆角贴到屏幕边缘
--- 旧配置在 80 列下命令行框（82）溢出 2 列 ⇒ 留 6 列刚好让收缩后的框完整显示
M.reserved = 6

--- snacks 口径的内容宽：**函数**，开窗时求值（snacks/win.lua:1281 支持函数）
--- @return integer
function M.width()
  return math.max(30, math.min(M.max_width, vim.o.columns - M.reserved))
end

--- noice 口径的内容宽（= width() − 4，见上面盒模型）。⚠ 只能是数字：noice 的 min_width
--- 会直接进 math.max ⇒ 这里是配置加载时的快照，改终端大小需重启
--- @return integer
function M.noice_min_width()
  return math.max(26, M.width() - 4)
end

--- 与 noice 命令行弹窗重合的行号（0 基**边框行**，给 snacks 输入框的 win.row 用）
--- @return integer
function M.center_row()
  return math.floor((vim.o.lines - 3) / 2)
end

return M
