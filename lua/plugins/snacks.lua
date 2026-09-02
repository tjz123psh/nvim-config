-- ============================================
-- snacks.nvim：只用它的 picker
-- ============================================
-- 为什么引入：dressing+nui+telescope 这套做不出「图标列 / 分组 / 富文本着色 /
-- 主题化排版」，观感有天花板。snacks.picker 支持 text-node 数组（每段单独
-- 高亮组）、原生多选与预览，能一次做到位。
--
-- ⚠ 必须显式关掉除 picker 以外的一切：snacks 的 notifier 会顶掉 noice、
--   dashboard 会顶掉 alpha、terminal 会顶掉 toggleterm、input 会顶掉 dressing。
-- ============================================
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      picker = {
        enabled = true,
      },

      -- 与现有插件冲突的，全部关掉
      notifier = { enabled = false },
      dashboard = { enabled = false },
      terminal = { enabled = false },
      input = { enabled = false },
      scroll = { enabled = false },
      zoom = { enabled = false },
      zen = { enabled = false },
      toggle = { enabled = false },
      bigfile = { enabled = false },
      quickfile = { enabled = false },
      scratch = { enabled = false },
      scope = { enabled = false },
      image = { enabled = false },
      debug = { enabled = false },
      profiler = { enabled = false },
      util = { enabled = false },
      git = { enabled = false },
      git_linker = { enabled = false },
      git_hosting = { enabled = false },
      rename = { enabled = false },
      bufdelete = { enabled = false },
      explorer = { enabled = false },
      list = { enabled = false },
      job = { enabled = false },
    },
  },
}
