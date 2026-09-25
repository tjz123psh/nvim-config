-- ============================================
-- 启动欢迎页：alpha-nvim
-- Neovim 启动时显示的漂亮界面
-- 有快捷键可以直接打开常用功能
-- ============================================

return {
  "goolord/alpha-nvim",
  -- 有文件参数时不抢占首屏；保留 :Alpha/:A 命令按需加载。
  event = vim.fn.argc() == 0 and "VimEnter" or nil,
  cmd = "Alpha",

  opts = function()
    local dashboard = require("alpha.themes.dashboard")

    -- ── 统一调色（2026-09-25，见工作台账 §27.1）───────────────────────────────
    -- 原来：Logo/页脚用 "Type"(黄)、按钮文字用 "Label"(sapphire)、快捷键用 "Keyword"(mauve)，
    -- 三个来源都和 picker 皮肤（蓝标题 #89b4fa + 灰次要信息 #7f849c + 常规文字 #cdd6f4）不同源。
    -- 现在统一：Logo 与快捷键 = 蓝强调（同 picker 标题）、按钮文字 = 常规文字色、页脚 = 次要灰。
    local function apply_dashboard_hl()
      vim.api.nvim_set_hl(0, "AlphaDashHeader", { fg = "#89b4fa" }) -- blue
      vim.api.nvim_set_hl(0, "AlphaDashButton", { fg = "#cdd6f4" }) -- text
      vim.api.nvim_set_hl(0, "AlphaDashShortcut", { fg = "#89b4fa", bold = true }) -- blue
      vim.api.nvim_set_hl(0, "AlphaDashFooter", { fg = "#7f849c" }) -- overlay1
    end
    apply_dashboard_hl()
    -- :colorscheme 会清空自定义高亮组；欢迎页是静态渲染，重挂一次代价可忽略
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("AlphaDashboardHL", { clear = true }),
      callback = apply_dashboard_hl,
    })

    -- ASCII 艺术字 Logo（NEovIM）
    local logo = {
      "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
      "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
      "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
      "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
      "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
      "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
    }
    -- logo 实测显示宽 52 列，留 6 列余量即可；原来卡 68 会让 58~67 列窗口退化成纯文字
    dashboard.section.header.val = vim.o.columns >= 58 and logo or { "NEOVIM" }
    dashboard.section.header.opts.hl = "AlphaDashHeader" -- 默认是 "Type"(黄)，统一成蓝强调

    -- 快捷按钮
    -- 全部改用 snacks picker（fzf 风格紧凑列表），和 <leader>f* 一套观感
    local config_search = "<cmd>lua require('snacks').picker.files({ cwd = vim.fn.stdpath('config') })<cr>"
    dashboard.section.buttons.val = {
      dashboard.button("f", "  查找文件", "<cmd>lua require('snacks').picker.files()<cr>"),
      dashboard.button("r", "  最近文件", "<cmd>lua require('snacks').picker.recent()<cr>"),
      dashboard.button("c", "  Neovim 配置", config_search),
      dashboard.button("p", "  项目列表", "<cmd>Projects<cr>"),
      dashboard.button("n", "  新建文件", "<cmd>ene <bar> startinsert<cr>"),
      dashboard.button("q", "  退出", "<cmd>qa<cr>"),
    }

    -- 页脚
    local version = vim.version()
    local cwd = vim.o.columns >= 80 and vim.fn.getcwd() or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    dashboard.section.footer.val = {
      "",
      string.format("  Neovim %d.%d.%d  |  %s  ", version.major, version.minor, version.patch, cwd),
    }
    dashboard.section.footer.opts.hl = "AlphaDashFooter"

    -- 设置按钮颜色
    for _, btn in ipairs(dashboard.section.buttons.val) do
      btn.opts.hl = "AlphaDashButton"
      btn.opts.hl_shortcut = "AlphaDashShortcut"
    end

    -- 布局：上边距 3 → Logo → 边距 2 → 按钮 → 边距 1 → 页脚
    dashboard.opts.layout = {
      { type = "padding", val = 3 },
      dashboard.section.header,
      { type = "padding", val = 2 },
      dashboard.section.buttons,
      { type = "padding", val = 1 },
      dashboard.section.footer,
    }

    return dashboard.opts
  end,
}
