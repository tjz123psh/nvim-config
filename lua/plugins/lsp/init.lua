-- ============================================
-- LSP（语言服务器协议）配置
-- LSP 提供代码补全、错误检查、跳转定义等功能
-- 这里配置 nvim-lspconfig + mason-lspconfig
-- ============================================

return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = {
    {
      "williamboman/mason.nvim",
      opts = {
        PATH = "prepend",
      },
    },
    -- 让 mason 自动安装 LSP 服务器（但不自动配置，由下方 config 接管）
    {
      "williamboman/mason-lspconfig.nvim",
      dependencies = { "williamboman/mason.nvim" },
      opts = {
        ensure_installed = {
          "clangd", -- C/C++
          "lua_ls", -- Lua（Neovim 配置用）
          "jdtls", -- Java
          "gopls", -- Go
          "rust_analyzer", -- Rust
          "html", -- HTML
          "cssls", -- CSS
          "jsonls", -- JSON
          "yamlls", -- YAML
          "marksman", -- Markdown
          "lemminx", -- XML / pom.xml
        },
        automatic_enable = false, -- 手动管理，跳过自动启用
      },
      config = function(_, opts)
        require("mason").setup({ PATH = "prepend" })
        require("mason-lspconfig").setup(opts)
      end,
    },
    -- 补全引擎（需要 LSP 的能力信息）
    "saghen/blink.cmp",
    -- lua_ls 的「Neovim 环境」来源（2026-09-28 审查 A01 落地）。
    -- lazydev 走 workspace/configuration 应答（lazydev/lsp.lua 的 on_workspace_configuration），
    -- 在 lua_ls 询问时按 buffer 动态给出 Lua.workspace.library —— 不是静态塞 settings。
    -- ft="lua"：只在真正编辑 lua 文件时才加载，不占启动。
    -- ⚠ 它同时提供 require("插件名") 的补全源（blink 集成），但**需要 blink 侧注册 source**才生效，
    --   本机暂未注册（见下面 lua_ls 的注释），所以插件模块补全靠 lua_ls 自己。
    { "folke/lazydev.nvim", ft = "lua", opts = {} },
  },

  opts = {
    -- 要启用哪些 LSP 服务器
    -- clangd/rust_analyzer 直配，其他用 lang/ 单独管理
    servers = {
      clangd = {},
      rust_analyzer = {},
      lua_ls = {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim", "jit" } },
            workspace = {
              checkThirdParty = false,
              -- ⚠ 2026-09-28（审查 A01）：原先这里是 nvim_get_runtime_file("", true)，
              --   实测只展开出 6 条路径（含 $VIMRUNTIME）、第三方插件目录 0 个 ——
              --   报告说的「把所有已安装插件都喂给 lua_ls、内存飙到 GB」并不成立；
              --   但它确实把整个 runtimepath 含的文档/测试一起交给 lua_ls 索引，属于粗糙做法。
              --   现在交给 lazydev（依赖里那个 spec）：它按 buffer 动态给出库路径，
              --   且默认就含 $VIMRUNTIME ⇒ Neovim API 类型不再丢，重复定义来源也少一个。
              --   ⚠ 副作用：lua_ls 不再把每个插件的 lua/ 目录当库，`require("snacks")` 这类
              --     插件模块的补全比原来少（要补上就注册 lazydev 的 blink source）。
              --     本机配置文件自己的模块（require("core.xxx")）不受影响，走工作区解析。
              library = vim.api.nvim_get_runtime_file("lua", true),
            },
            telemetry = { enable = false },
          },
        },
      },
      html = {},
      cssls = {},
      jsonls = {},
      yamlls = {},
      marksman = {},
      -- XML / pom.xml。必须显式给 filetypes：nvim-lspconfig 默认表里含 'xsl'，
      -- 而 Neovim 的 .xsl/.xslt 都识别成 filetype xslt（runtime/lua/vim/filetype.lua:1463），
      -- 'xsl' 这个"扩展名当 filetype"的条目会让 :checkhealth vim.lsp 常驻一条
      -- "Unknown filetype 'xsl'"（2026-09-24 实测，去掉后警告消失）。
      lemminx = { filetypes = { "xml", "xsd", "xslt", "svg" } },
    },

    -- 当 LSP 附加到某个缓冲区时，注册对应的快捷键
    -- 抽到 core/lsp_on_attach.lua，因为 nvim-jdtls 走自己的启动路径、
    -- 不经过这里的自动配置，需要和 lang/java.lua 共用同一份映射。
    on_attach = require("core.lsp_on_attach"),

    -- 需要跳过的服务器（由专门的插件管理）
    setup = {
      jdtls = function()
        return true
      end, -- Java 由 nvim-jdtls 管理
      rust_analyzer = function()
        if vim.fn.executable("rustc") == 1 and vim.fn.executable("cargo") == 1 then
          return false
        end

        vim.schedule(function()
          vim.notify(
            "Rust 工具链未安装，已跳过 rust-analyzer。安装 rust 后重新打开项目即可。",
            vim.log.levels.WARN
          )
        end)
        return true
      end,
    },
  },

  config = function(_, opts)
    -- nvim-lspconfig 0.12+ 的配置存放在 lsp/ 目录，vim.lsp.config 会自动发现
    -- 无需手动 require 旧版 lspconfig.configs

    -- 从 blink.cmp 获取 LSP 补全能力
    local ok, blink = pcall(require, "blink.cmp")
    local caps = ok and blink.get_lsp_capabilities() or {}

    for server, config in pairs(opts.servers) do
      local setup_fn = opts.setup[server]
      if setup_fn and setup_fn(server, config) then
        -- 跳过特殊管理的服务器（如 jdtls）
      else
        config.capabilities = vim.tbl_deep_extend("force", caps, config.capabilities or {})
        config.on_attach = opts.on_attach
        vim.lsp.config(server, config)
        vim.lsp.enable(server)
      end
    end
  end,
}
