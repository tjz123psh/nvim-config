-- ============================================
-- 文件树：neo-tree.nvim
-- 左侧显示项目文件结构
-- 按 <leader>e 打开/关闭
-- ============================================

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "打开/关闭文件树" },
  },
  opts = {
    popup_border_style = "rounded",
    use_popups_for_input = false, -- 走 vim.ui.input，由 snacks 输入框接管（全机统一风格）
    window = {
      position = "left",
      -- 宽终端保持 35 列；窄终端按 40% 收缩（80 列 → 32，60 列 → 24），最少 20
      width = function()
        return math.max(20, math.min(35, math.floor(vim.o.columns * 0.4)))
      end,
      mappings = {
        ["<cr>"] = "open",
        ["o"] = "open",
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      bind_to_cwd = true,
      window = {
        mappings = {
          ["h"] = "navigate_up",
          ["l"] = "set_root",
          ["r"] = "rename",
          ["m"] = "move",
          -- ⚠ 不要把 p 抢去当 toggle_hidden：neo-tree 默认 p = paste_from_clipboard，
          --   抢掉之后 y/x/c 三条复制剪切动作全部失去粘贴入口（2026-09-25 审查发现）。
          --   隐藏文件用 neo-tree 自带的 H（defaults.lua:499），本配置没覆盖它。
          ["Z"] = "expand_all_subnodes", -- 递归展开光标所在节点下的所有子节点
          ["."] = false,
        },
      },
    },
    default_component_configs = {
      indent = {
        with_markers = true,
        with_expanders = true,
        padding = 1,
      },
      icon = {
        folder_closed = "",
        folder_open = "",
        padding = " ",
      },
      git_status = {
        symbols = {
          added = "✚",
          modified = "",
          deleted = "✖",
        },
      },
    },
  },
}
