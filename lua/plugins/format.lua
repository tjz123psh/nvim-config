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

    -- 每种文件类型使用的格式化工具
    -- 需要先通过 :Mason 安装
    -- ⚠ 这里**故意**不给 go 登记 formatter（2026-09-28 审查 G05 查证后决定不改）：
    --   1) conform 的 `lsp_format = "fallback"` 语义是「配了 formatter 就只用它，**没配**才走 LSP」
    --      （conform/init.lua:512-518，判据是 `not any_formatters`）；
    --   2) 本机 mason 里**只有 gopls**，没有 gofumpt / goimports；
    --   ⇒ 一旦写上 `go = { "gofumpt" }` 而工具没装，resolve_formatters 会因 `info.available` 为假
    --      把它过滤掉（conform/init.lua:348）→ 保存时什么格式化都不跑，**比现在更差**。
    --   现状：go 保存时走 gopls 格式化，且 lang/go.lua 已开 `gofumpt = true`，链条是通的。
    --   想换独立 formatter 就两步一起做：`:MasonInstall gofumpt` + 在下面登记。
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
