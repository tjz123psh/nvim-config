-- ============================================
-- Markdown 预览：md-render.nvim
-- 把 md 渲染到**独立窗口**（浮动窗 / 标签页 / 分屏 / pager），编辑缓冲区原样不动，
-- 因此不会像"就地渲染"那样把编辑视图改得面目全非。
-- 纯 Lua、无外部命令依赖；对中文有专门优化（JIS 禁则处理 + BudouX 断句）。
-- 需要 Neovim >= 0.12（本机 0.12.5）。
-- ============================================

return {
  "delphinus/md-render.nvim",
  ft = "markdown",
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- 代码块语言图标（可选）
  },
}
