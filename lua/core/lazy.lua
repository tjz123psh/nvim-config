-- ============================================
-- lazy.nvim 插件管理器配置
-- lazy.nvim 是目前最快的 Neovim 插件管理器
-- ============================================

-- 如果 lazy.nvim 还没安装，自动用 git 下载
-- 用入口文件判断是否完整：clone 被中断会留下只有 .git 的空目录，
-- 只检查目录存在会跳过重新克隆，导致 require("lazy") 失败
-- 注意：新版 lazy.nvim 入口是 lua/lazy/init.lua，老版本是 lua/lazy.lua，都检查
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local entry_ok = vim.uv.fs_stat(lazypath .. "/lua/lazy/init.lua") or vim.uv.fs_stat(lazypath .. "/lua/lazy.lua")
if not entry_ok then
  if vim.uv.fs_stat(lazypath) then
    vim.fn.system({ "rm", "-rf", lazypath })
  end
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 配置 lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  rocks = { enabled = false }, -- 不用 rocks 生态插件，清 checkhealth 警告
  defaults = {
    -- 这两项与 lazy.nvim 自带默认值相同，写出来只为显式；
    -- 真正决定「是否延迟加载」的是各 spec 的 event/ft/keys/cmd ——
    -- lazy 内部判定是 `dep or defaults.lazy or event or keys or ft or cmd`，
    -- 所以 defaults.lazy = false 不会让触发器失效（这一点曾被我误判过）
    lazy = false,
    version = false, -- 不锁定版本，随时更新
  },
  install = {
    colorscheme = { "catppuccin" }, -- 安装插件时用的临时主题
  },
  checker = {
    -- 2026-09-25 审查（§29.2.2 P2）：enabled=true 时 lazy 会在每次启动（距上次 >1h）对
    -- **全部插件跑 git fetch**（lazy.nvim config.lua:343-346 → checker.start → manage git.fetch），
    -- 与本配置「启动期不联网、联网走 Clash 代理」的前提冲突；notify=false 还会让失败静默。
    -- 需要看有没有更新时手动跑一次 :Lazy check 即可（:Lazy 界面里的更新徽标因此不再自动刷新）。
    enabled = false,
    notify = false,
  },
  change_detection = {
    notify = false, -- 配置文件变更时不提示
  },
  performance = {
    reset_packpath = true,
    rtp = {
      reset = true,
      disabled_plugins = { -- 禁用 Neovim 内置的不常用插件
        "gzip",
        "tarPlugin",
        "zipPlugin",
        "tohtml",
        "tutor",
      },
    },
  },
})
