-- ============================================
-- Markdown 阅读：markview.nvim
-- 在缓冲区里就地渲染 md：标题、列表、表格（圆角框线）、代码块、复选框、引用。
-- 不需要浏览器，也不需要外部命令；只依赖本机已装好的 treesitter 解析器
-- markdown / markdown_inline 与 nvim-web-devicons。
-- ============================================

return {
  "OXY2DEV/markview.nvim",
  -- 上游建议 lazy = false；本配置按惯例用 ft 懒加载（打开 md 才加载）
  ft = { "markdown", "markdown.mdx" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter", -- 提供 markdown / markdown_inline 解析器
    "nvim-tree/nvim-web-devicons", -- 代码块语言图标
  },
  opts = {
    markdown = {
      code_blocks = {
        -- 代码块**不画整行底色**：本机是透明主题（catppuccin transparent_background
        -- + Neovide 80% 不透明度），整行底色会和壁纸混成一条条"斑马带"，
        -- 阅读时非常花。这里让底色跟着 Normal 走（等于透明），只留语言标签。
        default = { block_hl = "Normal", pad_hl = "Normal" },
        border_hl = "Normal",
      },
    },
  },
}
