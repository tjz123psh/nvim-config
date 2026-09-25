-- ============================================
-- 浮动/分屏终端：toggleterm.nvim
-- 替代 :term，支持多终端实例、浮动窗口、快速切换
-- ============================================

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = "ToggleTerm",
  keys = {
    { "<leader>tt", desc = "切换浮动终端" },
    { "<leader>th", desc = "水平分割终端" },
    { "<leader>tv", desc = "垂直分割终端" },
  },
  config = function()
    local toggleterm = require("toggleterm")

    toggleterm.setup({
      size = 20, -- 水平/垂直终端高度
      open_mapping = nil, -- 不用默认映射，用下方自定义
      shading_factor = 2, -- 终端背景暗化程度
      direction = "float", -- 默认浮动
      close_on_exit = false, -- 命令结束后保留终端和输出，便于查看测试结果
      auto_scroll = true,
      -- 终端窗口恢复实底：toggleterm 在 open() 里先 ui.hl_term() 覆盖 winhighlight、之后才调
      -- on_open（terminal.lua:504），所以必须在这里再补一次，否则透明主题下浮窗会透出壁纸。
      on_open = function(term)
        require("core.term_bg").apply(term.window)
      end,
      float_opts = {
        border = "rounded",
        winblend = 0, -- 匹配 kitty background_opacity 0.8
      },
    })

    local map = vim.keymap.set

    -- 两个实测出来的坑（都在真 TTY 里复现过）：
    -- 1) 用 :ToggleTerm direction=xxx（smart_toggle）在已有终端时只会「关掉它」并忽略方向；
    --    传 count >= 1 才走 toggle_nth_term，按 id 各自记忆方向与尺寸。
    -- 2) 浮窗聚焦时 Terminal:open() 建 split 会静默失败（headless 与真 pty 都是"什么都不发生"），
    --    所以先切到非浮动窗口再 toggle；副作用是浮窗被关掉 —— 与「切到分屏」的预期一致。
    local function toggle_dir(id, size, direction)
      if vim.api.nvim_win_get_config(0).relative ~= "" then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_config(win).relative == "" then
            vim.api.nvim_set_current_win(win)
            break
          end
        end
      end
      toggleterm.toggle(id, size, nil, direction)
    end

    map("n", "<leader>tt", function()
      toggle_dir(1, 20, "float")
    end, { desc = "切换浮动终端" })

    map("n", "<leader>th", function()
      toggle_dir(2, 15, "horizontal")
    end, { desc = "水平分割终端" })

    -- 垂直分屏按终端宽度的 45% 取（80 列 → 36，200 列 → 80），避免窄终端下只剩十几列编辑区
    local vcols = function()
      return math.max(30, math.min(80, math.floor(vim.o.columns * 0.45)))
    end

    map("n", "<leader>tv", function()
      toggle_dir(3, vcols(), "vertical")
    end, { desc = "垂直分割终端" })
  end,
}
