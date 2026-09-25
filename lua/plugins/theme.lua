-- ============================================
-- 主题配色：catppuccin
-- 目前最流行的 Neovim 主题，柔和护眼
-- 风味：mocha（最深色） / macchiato / frappe / latte（浅色）
-- ============================================

return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false, -- 立即加载（主题必须在启动时加载）
  priority = 1000, -- 高优先级，确保在其他插件之前加载

  opts = {
    flavour = "mocha", -- 深色风味
    transparent_background = true, -- kitty 终端已配 background_opacity，Neovim 不设背景色即可透出桌面
    term_colors = true, -- 让终端模拟器的颜色也匹配主题

    -- 与已安装插件的配色集成（让所有插件都统一用主题色）
    integrations = {
      treesitter = true, -- 语法高亮
      native_lsp = { enabled = true }, -- LSP 语义高亮
      blink_cmp = true, -- 补全菜单 blink.cmp
      -- telescope 集成已随插件一起删除（搜索统一走 snacks picker）
      indent_blankline = { enabled = true }, -- 缩进线
      -- 注意：catppuccin 的 lualine 集成必须是 override 表；写 boolean 会让
      -- lualine.themes.catppuccin-mocha 抛错、被 statusline.lua 的 pcall 吞掉，
      -- 状态栏静默退化成 "auto"（中段变纯黑带）
      lualine = { enabled = true }, -- 状态栏
      alpha = true, -- 欢迎页
      mason = true, -- Mason UI
      neotree = true, -- 文件树
      noice = true, -- UI 美化
      dap = true, -- 调试器
      dap_ui = true, -- 调试界面
      which_key = true, -- 快捷键提示
      -- 下面三个之前漏了：snacks 是现在所有选择器的宿主（不接进来它的组只能是默认黑底），
      -- flash 是 s/S 跳转，notify 是通知卡片
      snacks = true,
      flash = true,
      notify = true,
    },
  },

  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin") -- 应用主题
  end,
}
