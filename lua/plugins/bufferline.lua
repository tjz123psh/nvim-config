-- =============================================================================
-- 标签栏（缓冲区列表）：bufferline.nvim
-- =============================================================================
-- 在窗口顶部显示标签栏，展示所有打开的缓冲区。
-- 支持图标、诊断信息、neo-tree 文件树偏移等。
-- 快捷键：<S-h> 切换到上一个标签，<S-l> 切换到下一个标签。
-- =============================================================================

return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "catppuccin/nvim",
  },
  event = "VeryLazy",
  keys = {
    { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "切换到上一个缓冲区" },
    { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "切换到下一个缓冲区" },
  },
  opts = function()
    -- ── 统一调色（2026-09-25，见工作台账 §27.1）───────────────────────────────
    -- 背景：主题开了 transparent_background ⇒ catppuccin 的 bufferline 主题把所有 bg 都写成
    --   "NONE"，标签栏变成"悬浮文字"（透出壁纸），与已经改实的底部状态栏
    --   （statusline.lua 把 c 段补成 mantle #181825）不一致。这里把 bg 补成实底：
    --   「选中」类 = base #1e1e2e（与 picker 面板同色），其余 = mantle #181825（与状态栏同色）。
    -- 强调：分隔符统一 overlay1 #7f849c（与 picker 边框同色）、选中指示条 blue #89b4fa
    --   （与 picker 标题同色）、未保存圆点 yellow #f9e2af（与 picker 匹配高亮同色）。
    local SOLID_BG, SOLID_BG_ACTIVE = "#181825", "#1e1e2e"
    local BORDER, ACCENT, MODIFIED, RED = "#7f849c", "#89b4fa", "#f9e2af", "#f38ba8"

    local highlights
    local ok, bufferline_theme = pcall(require, "catppuccin.special.bufferline")
    if ok then
      -- get_theme() 返回的是**函数**（bufferline 的 Config:resolve 里 type(user) == "function"
      -- 时调用它，换主题时重算），所以这里包一层：拿上游结果 → 透明底换实底 → 换统一强调色。
      local upstream = bufferline_theme.get_theme()
      highlights = function()
        local hl = upstream()
        for name, spec in pairs(hl) do
          if type(spec) == "table" and spec.bg == "NONE" then
            spec.bg = name:find("_selected", 1, true) and SOLID_BG_ACTIVE or SOLID_BG
          end
        end
        -- 上游透明模式下用 surface1(#45475a) 当分隔符/未选中标签色：压在实底上太暗，统一提亮
        for _, name in ipairs({
          "buffer_visible",
          "separator",
          "separator_visible",
          "separator_selected",
          "offset_separator",
          "close_button",
          "close_button_visible",
        }) do
          if hl[name] then
            hl[name].fg = (name == "buffer_visible") and "#a6adc8" or BORDER
          end
        end
        if hl.indicator_selected then
          hl.indicator_selected = { fg = ACCENT, bg = SOLID_BG_ACTIVE, bold = true }
        end
        if hl.indicator_visible then
          hl.indicator_visible = { fg = BORDER, bg = SOLID_BG }
        end
        if hl.close_button_selected then
          hl.close_button_selected.fg = RED
        end
        for _, name in ipairs({ "modified", "modified_visible", "modified_selected" }) do
          if hl[name] then
            hl[name].fg = MODIFIED
          end
        end
        return hl
      end
    end

    return {
      highlights = highlights,
      options = {
        mode = "buffers",
        numbers = "none",
        -- 只有一个缓冲区时不画整条标签栏（bufferline 默认 always_show_bufferline=true）。
        -- 配合上面的"实底"调色：否则启动页/单文件编辑时顶部会多出一条**空的**实色横条
        -- （transparent 时代它是隐形的，所以以前看不出来）。LazyVim 也是 false。
        always_show_bufferline = false,
        close_command = "bdelete %d",
        right_mouse_command = "bdelete %d",
        indicator = {
          style = "icon",
          icon = "▎",
        },
        buffer_close_icon = "󰅖",
        modified_icon = "●",
        left_trunc_marker = "",
        right_trunc_marker = "",
        separator_style = "thin",
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(_, _, diagnostics)
          local parts = {}
          for _, item in ipairs({
            { "error", "󰅚" },
            { "warning", "󰀪" },
            { "info", "󰋽" },
            { "hint", "󰌶" },
          }) do
            local count = diagnostics[item[1]] or 0
            if count > 0 then
              table.insert(parts, item[2] .. " " .. count)
            end
          end
          return #parts > 0 and " " .. table.concat(parts, " ") or ""
        end,
        offsets = {
          {
            filetype = "neo-tree",
            text = "文件树",
            highlight = "Directory",
            text_align = "left",
            -- +1 列：bufferline 的 offset 宽度 = 树窗宽（**不含**分隔符那 1 列，上游
            -- bufferline/offset.lua:162 直接用 nvim_win_get_width）⇒ 第一个标签会从
            -- **分隔符列**开始，比编辑窗首列早 1 列（79/80/81/120 列全都差 1，与终端宽度无关）。
            -- padding = 1 把 offset 撑到「树宽 + 分隔符列」，标签起点正好落在编辑窗首列
            --（真 pty 实测：120 列下 ▎ 指示条 35 → 36 列 = 编辑窗首列；80 列下 33 → 34）。
            padding = 1,
          },
        },
      },
    }
  end,
}
