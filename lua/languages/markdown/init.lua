return {
  lsp = { marksman = {} },
  tools = { "marksman" },
  treesitter = {
    parsers = { "markdown", "markdown_inline" },
    filetypes = { "markdown", "markdown.mdx" },
  },
  filetypes = { extension = { mdx = "markdown.mdx" } },
  plugins = { (require("languages.markdown.render")) },
  keys = {
    {
      "<leader>Mp",
      function()
        if vim.bo.filetype ~= "markdown" then
          vim.notify("请先打开 Markdown 文件", vim.log.levels.INFO)
          return
        end
        require("render-markdown").buf_toggle()
      end,
      mode = "n",
      desc = "Markdown：开关当前文档美化",
    },
  },
}
