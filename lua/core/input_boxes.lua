-- ============================================
-- 输入类浮窗的统一几何：snacks 输入框 ↔ noice 命令行弹窗
-- ============================================
-- Snacks 的 width 是内容宽，外框再加 2 列；Noice 还带左右内边距，
-- 因此 min_width 比 Snacks 少 4 列。两者共用尺寸策略，避免分散修改。
-- Snacks 开窗时动态取宽度；Noice 的 min_width 必须是数字，只在加载时取值。
-- 两者沿用现有居中方式，边框行仍可能差 1 行；这里不承诺像素级重合。
local M = {}

--- 内容宽的上限（columns 足够大时就用它，保持宽屏观感不变）
M.max_width = 80

--- 两侧保留余量，避免边框贴到终端边缘。
M.reserved = 6

--- snacks 口径的内容宽：**函数**，开窗时求值（snacks/win.lua:1281 支持函数）
--- @return integer
function M.width()
  return math.max(30, math.min(M.max_width, vim.o.columns - M.reserved))
end

--- Noice 的内容宽；加载时的数字快照，调整终端后重启配置才重新求值。
--- @return integer
function M.noice_min_width()
  return math.max(26, M.width() - 4)
end

--- Snacks 输入框的居中行号（0 基），保持现有垂直位置。
--- @return integer
function M.center_row()
  return math.floor((vim.o.lines - 3) / 2)
end

return M
