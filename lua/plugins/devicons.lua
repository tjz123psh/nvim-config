-- ============================================
-- 文件图标：nvim-web-devicons 的缺口补齐
-- ============================================
-- 这份配置主打 Java/Spring + Helm，但 devicons 默认表里没有
-- application.properties 与 *.gotmpl，neo-tree/bufferline/snacks picker 里会退化成默认图标。
-- 字形刻意复用字体里**已有的**码点，避免掉方块：
--   U+E615 = conf/ini 的齿轮（DevIconConf）
--   U+E627 = Go 图标（DevIconGo）
-- ============================================

return {
  "nvim-tree/nvim-web-devicons",
  opts = {
    override = {
      properties = { icon = vim.fn.nr2char(0xE615), color = "#89b4fa", name = "Properties" },
      gotmpl = { icon = vim.fn.nr2char(0xE627), color = "#00ADD8", name = "Gotmpl" },
    },
  },
}
