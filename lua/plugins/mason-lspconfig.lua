-- 手动 LSP 安装入口：启动与编辑文件不加载本插件、不刷新注册表。
-- 批量补齐工具用 :MasonToolsInstall，清单统一在 mason-tool-installer.lua。
return {
  "williamboman/mason-lspconfig.nvim",
  cmd = { "LspInstall", "LspUninstall" },
  dependencies = { "williamboman/mason.nvim" },
  opts = {
    ensure_installed = {}, -- 手动安装一个服务器时，也不顺带安装其它服务器。
    automatic_enable = false, -- LSP 启动仍由 lsp/init.lua 和语言插件管理。
  },
}
