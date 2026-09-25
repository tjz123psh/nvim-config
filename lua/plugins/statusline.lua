-- ============================================
-- 状态栏：lualine.nvim
-- 屏幕底部的信息栏，显示模式、文件名、Git 分支等
-- ============================================

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "catppuccin/nvim" },
  event = "UIEnter",

  opts = function()
    local ok, theme = pcall(require, "lualine.themes.catppuccin-mocha")
    -- 主题开了 transparent_background ⇒ lualine 的 c 段 bg=NONE：整条状态栏中间是"洞"（透壁纸），
    -- 只有两端 a/b/x/z 是实色块。这里给所有模式（含 inactive）的 c 段补成 mantle，
    -- 整条状态栏变成实底（2026-09-25 视觉审查指出，用户点头统一）。
    if ok and type(theme) == "table" then
      for _, mode in pairs(theme) do
        if type(mode) == "table" then
          -- 有些模式（insert/visual…）主题里没写 c 段，靠 lualine 从 normal 继承；
          -- 这里干脆给每个模式都补上，行为一致。
          mode.c = vim.tbl_extend("force", mode.c or {}, { bg = "#181825" })
        end
      end
    end
    return {
      options = {
        theme = ok and theme or "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
        -- 只对启动页关状态栏。原先这里还写了 neo-tree，与下面 extensions.neo-tree
        -- 互斥：切到文件树时整条状态栏空白，扩展永远轮不到生效（死配置）。
        disabled_filetypes = { "alpha" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
          {
            "filename",
            file_status = true,
            path = 1,
            symbols = { modified = " ●", readonly = " " },
          },
        },
        lualine_x = {
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            colored = true,
            update_in_insert = false,
            symbols = { error = " 󰅚 ", warn = " 󰀪 ", info = " 󰋽 ", hint = " 󰌶 " },
          },
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
      },
      extensions = { "neo-tree" },
    }
  end,
}
