-- ============================================
-- UI 增强：noice.nvim
-- 将命令行、消息通知、弹出菜单替换为浮动窗口
-- 输入框/选择器由 snacks 统一提供（dressing.nvim 已删除），noice 只负责命令行与消息
-- ============================================

return {
  "folke/noice.nvim",
  lazy = false,
  dependencies = {
    "MunifTanjim/nui.nvim",
    {
      "rcarriga/nvim-notify",
      opts = {
        timeout = 2500,
        stages = "fade_in_slide_out",
        -- ⚠ 这是 nvim-notify 的**混合基准色**不是卡片底色：写 #000000 会让 fade 阶段的
        --   边框/正文被压暗（实测 #f9e2af → #f8e2af、#f38ba8 → #c16f86，肉眼可见跳色）。
        --   改成与卡片一致的 base 就自然了（2026-09-25 视觉审查）。
        background_colour = "#1e1e2e",
      },
      config = function(_, opts)
        local notify = require("notify")
        notify.setup(opts)
        vim.notify = notify
      end,
    },
  },

  opts = {
    -- 命令行输入弹窗（居中圆角浮动窗口，窄终端自动收缩）
    views = {
      -- 宽度用 "auto"：noice 只在 auto 时才把宽度夹进
      -- minmax(min_width, max_width(默认 columns-4), 内容宽) —— 写死数字会绕过这层保护，
      -- 60~80 列终端上会裁边（历史：写 78 时浮窗总宽 82 > 80）
      cmdline_popup = {
        position = { row = "50%", col = "50%" },
        size = { width = "auto", min_width = 40, height = "auto" },
        border = { style = "rounded" },
      },
      cmdline_input = {
        position = { row = "50%", col = "50%" },
        size = { width = "auto", min_width = 40, height = "auto" },
        border = { style = "rounded" },
      },
      -- :messages / :Noice 的历史默认是"底部 20% 全宽 split"（noice views.lua 的 messages），
      -- 与全机其它上下文（picker、速查、ui.select）都是居中卡片的风格不一致 ⇒ 换居中 popup。
      -- 2026-09-25 视觉审查指出。
      messages = {
        view = "popup",
        position = { row = "40%", col = "50%" },
        size = { width = "auto", min_width = 40, max_width = 100, height = "auto", max_height = 20 },
        border = { style = "rounded" },
      },
    },

    -- 命令模式（: 开头的命令）
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
      -- vim.fn.input() 的浮窗标题默认取 kind 名（显示为 " Input "）；这里改成中文
      format = { input = { title = " 输入 " } },
    },

    -- 普通消息通知
    messages = {
      enabled = true,
      view = "notify",
      view_error = "notify",
      view_warn = "notify",
    },

    -- 弹出菜单（如代码操作列表）
    popupmenu = {
      enabled = true,
      backend = "nui",
    },

    -- 通知区域（右下角 mini 风格）
    notify = {
      enabled = true,
      view = "mini",
    },

    -- LSP 进度提示
    lsp = {
      progress = {
        enabled = true,
        view = "notify",
        format = "lsp",
      },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },

    -- 路由规则：过滤不需要弹窗的通知
    routes = {
      { filter = { event = "msg_show", kind = "search_count" }, opts = { skip = true } },
      { filter = { event = "lsp", kind = "progress", find = "jdtls" }, opts = { skip = true } },
    },
  },
}
