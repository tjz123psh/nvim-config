-- ============================================
-- UI 美化：dressing.nvim
-- 美化 vim.ui.select（代码操作菜单、查找替换等）和 vim.ui.input
-- 让内置选择/输入弹窗有统一圆角边框风格
-- ============================================

return {
  "stevearc/dressing.nvim",
  event = "VeryLazy",
  opts = {
    input = {
      enabled = true,
      default_prompt = "Input",
      trim_prompt = true,
      title_pos = "left", -- 标题左对齐，与 noice cmdline 一致
      start_mode = "insert",
      border = "rounded", -- 圆角边框
      relative = "editor", -- 相对编辑器居中
      prefer_width = 78,
      max_width = { 78, 0.9 },
      min_width = { 24, 0.4 },
      override = function(conf)
        local width = math.min(conf.width or 78, math.max(20, vim.o.columns - 4))
        conf.width = width
        conf.row = math.floor((vim.o.lines - 3) / 2)
        conf.col = math.max(0, math.floor((vim.o.columns - width) / 2))
        return conf
      end,
      win_options = {
        winblend = 0, -- 不透明
        wrap = false,
        list = true,
        listchars = "precedes:…,extends:…",
        -- 使用与 noice 相同的高亮组
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
      },
    },
    select = {
      enabled = true,
      -- nui 观感更现代（居中、圆角、无编号），builtin 兜底（若 nui 报错）
      backend = { "nui", "builtin" },
      builtin = {
        border = "rounded",
        relative = "editor",
        win_options = {
          cursorline = true,
          cursorlineopt = "both",
        },
      },
      nui = {
        position = "50%",
        relative = "editor",
        border = {
          style = "rounded",
        },
        -- 注意：dressing 读的是这一层的 max_width / min_height 等键。
        -- 之前误把它们塞进 renderer={} 里，等于完全没生效，
        -- 而 nui 默认 min_height=10，于是 2 个选项也撑出 10 行空框。
        -- height 算法是 max(#lines, min_height)，所以 min_height 必须小。
        min_width = 46,
        max_width = 78,
        min_height = 1,
        max_height = 16,
        win_options = {
          winblend = 0,
        },
      },
    },
  },
}
