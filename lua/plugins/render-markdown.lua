-- ============================================
-- Markdown 阅读：render-markdown.nvim
-- 在缓冲区里就地渲染 md：标题图标/配色、列表符号、表格边框、代码块底色、
-- 复选框、引用条 —— 不需要浏览器，也不需要外部命令。
-- 只依赖本机已装好的 treesitter 解析器 markdown / markdown_inline。
-- ============================================

return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- 只在打开 markdown 文件时加载（上游推荐的 lazy.nvim 用法）
  ft = "markdown",
  dependencies = {
    "nvim-treesitter/nvim-treesitter", -- 提供 markdown / markdown_inline 解析器
    "nvim-tree/nvim-web-devicons", -- 代码块语言图标
  },
  opts = {
    -- 全部走上游默认值（阅读优先）。以后想调的几个开关：
    --   anti_conceal = { enabled = false } → 光标所在行也保持渲染（纯读文档时更稳）
    --   heading = { sign = false }         → 关掉标题左侧符号列
    --   code = { sign = false }            → 关掉代码块左侧符号列
    -- 改完用 :RenderMarkdown config 看与默认值的差异。
  },
}
