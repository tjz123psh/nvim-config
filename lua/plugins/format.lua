-- ============================================
-- 代码格式化：conform.nvim
-- 保存文件时自动格式化代码
-- 依赖 mason 安装对应格式化工具
-- ============================================

return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },

  opts = {
    -- 保存时自动格式化。Java 半成品代码经常无法被 google-java-format 解析，
    -- 保留手动 <leader>F 格式化，避免保存被格式化器打断或改写。
    format_on_save = function(bufnr)
      if vim.bo[bufnr].filetype == "java" then
        return nil
      end

      return {
        timeout_ms = 2000,
        lsp_format = "fallback", -- 优先用下方明确配置的格式化器，缺失时再走 LSP
      }
    end,

    -- 优先使用下列外部工具；没有可用工具时，fallback 使用支持格式化的 LSP。
    -- 外部工具已经启动但执行失败时，不会再自动改用 LSP。
    -- Go 不额外安装 formatter，直接使用已开启 gofumpt 的 gopls。
    formatters_by_ft = {
      lua = { "stylua" },

      java = { "google-java-format" },
      cpp = { "clang-format" },
      c = { "clang-format" },
      rust = { "rustfmt" },
    },

    formatters = {
      ["google-java-format"] = {
        prepend_args = { "--aosp" },
      },
    },
  },

  keys = {
    {
      "<leader>F",
      function()
        require("conform").format({
          async = false,
          timeout_ms = 2000,
          lsp_format = "fallback",
        })
      end,
      desc = "手动格式化当前文件",
    },
  },
}
