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

    -- ── 诊断 tag 不要重绘文字颜色（2026-09-26，用户报「写 Java 时代码颜色变来变去」）──
    -- Neovim 0.12 对带 `unnecessary` tag 的诊断（jdtls 的未使用字段/局部变量/import）会
    -- 额外叠一层 DiagnosticUnnecessary（runtime/lua/vim/diagnostic.lua:1832-1856），
    -- 而 runtime/colors/vim.lua:137 把它 link 到 Comment ⇒ catppuccin 下整段文字被染成
    -- 灰 #9399b2 + 斜体。jdtls 每次编辑后 300~700ms 重新发布诊断，于是「刚写下的字段/常量」
    -- 会先变灰、被用上之后又变回来 —— 这正是「写着写着颜色变来变去」里最刺眼的一层。
    -- 清空属性后：文字保持 treesitter 原色，tag 诊断仍有常规严重级别下划线（不受影响）。
    -- DiagnosticDeprecated 只有删除线、不染字色（实测 sp+strikethrough），保持原样。
    local function neutralize_unnecessary_tag()
      vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", {})
    end
    neutralize_unnecessary_tag()
    -- 手动 :colorscheme 会重建高亮组，这里补一次（ColorScheme 事件在主题高亮之后触发）
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("theme_diagnostic_tags", { clear = true }),
      callback = neutralize_unnecessary_tag,
      desc = "诊断 tag（Unnecessary）不重绘文字颜色",
    })
  end,
}
