-- AI 面板：toggle 只隐藏/显示，close 才结束直连会话；不启用 tmux/NES。
return {
  "folke/sidekick.nvim",
  opts = { nes = { enabled = false } },
  keys = {
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle()
      end,
      desc = "AI CLI：开关面板",
    },
    {
      "<leader>as",
      function()
        require("sidekick.cli").select({ filter = { installed = true } })
      end,
      desc = "AI CLI：选工具（只列已安装）",
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").send({ msg = "{this}" })
      end,
      mode = { "n", "x" },
      desc = "AI CLI：发送当前上下文",
    },
    {
      "<leader>ad",
      function()
        require("sidekick.cli").close()
      end,
      desc = "AI CLI：断开会话",
    },
    {
      "<C-.>",
      function()
        require("sidekick.cli").focus()
      end,
      mode = { "n", "t", "i", "x" },
      desc = "AI CLI：聚焦 CLI 窗口",
    },
  },
}
