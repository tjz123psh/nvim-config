-- ============================================
-- Mason 手动工具清单（含 LSP 服务器）
-- 手动 :MasonToolsInstall 补齐，:MasonToolsUpdate 更新；启动时不检查或下载。
-- ============================================

return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  -- 2026-09-25 审查（§29.2.2 P3）：原先写的 event = "VeryLazy" 是**死触发器** ——
  -- mason.lua 把它列为 eager 插件（lazy=false）的依赖，实测 32ms 就被 source 了，
  -- VeryLazy 永远轮不到。这里删掉声明，与实际加载时机保持一致。
  -- （安装列表本身照旧生效：它随 mason 在启动期加载。）
  dependencies = {
    "williamboman/mason.nvim",
  },
  opts = {
    -- ⚠ 上游默认 run_on_start = true / start_delay = 0 / debounce_hours = nil ⇒ 每次启动都会
    --   check_install → registry.refresh（注册表缓存过期就联网更新），与"启动期不联网"的约定冲突
    --   （2026-09-25 审查 F15：auto_update=false、工具都装好了也不代表不刷新注册表）。
    --   这里关掉启动检查，需要时手动执行：:MasonToolsInstall 补齐缺失工具、:MasonToolsUpdate 更新。
    run_on_start = false,
    -- 清单全部使用 Mason 包名；关闭别名集成，避免 require 把安装插件拖回启动期。
    integrations = { ["mason-lspconfig"] = false },
    ensure_installed = {
      "clangd",
      "lua-language-server",
      "jdtls",
      "gopls",
      "rust-analyzer",
      "html-lsp",
      "css-lsp",
      "json-lsp",
      "yaml-language-server",
      "marksman",
      "codelldb", -- C/C++/Rust 调试器（DAP 用）
      "java-debug-adapter", -- Java 调试器（DAP 用）
      "java-test", -- Java 测试运行器（DAP 用）
      "lemminx", -- XML / pom.xml 语言服务器
      "vscode-spring-boot-tools", -- Spring Boot application.yml/properties 补全
      "delve", -- Go 调试器（DAP 用）
      "stylua", -- Lua 格式化器
      "google-java-format", -- Java 格式化器
      "clang-format", -- C/C++ 格式化器
      "tree-sitter-cli", -- Treesitter 解析器安装器依赖
      -- rustfmt 由 rustup component add rustfmt 提供，无需 mason 安装
    },
  },
}
