-- ============================================
-- sidekick.nvim：在 Neovim 里跑 AI CLI（folke）
-- ============================================
-- 只启用 CLI 那一半：NES（Copilot 的 Next Edit Suggestions）需要 copilot-language-server +
-- GitHub Copilot 订阅，本机都没有 ⇒ nes.enabled = false。
-- 键位沿用上游推荐：<leader>aa 开关 / <leader>as 选工具 / <leader>at 发当前上下文 /
-- <leader>ad 断开 / <C-.> 聚焦。**不用 cli.mux（tmux）** —— CLI 直接跑在 nvim 终端里。
--
-- 2026-09-25 按用户要求「重装干净点」：此前为「滚轮/翻历史」加的一堆自定义键
-- （<M-u> scrollback、<ScrollWheelUp/Down> 翻译、<leader>aR 重启会话、:GrokChat 会话记录）已全部移除。
-- ============================================

return {
  "folke/sidekick.nvim",
  keys = {
    { "<leader>aa", desc = "AI CLI：开关面板" },
    { "<leader>as", desc = "AI CLI：选工具（只列已安装）" },
    { "<leader>at", mode = { "n", "x" }, desc = "AI CLI：发送当前上下文" },
    { "<leader>ad", desc = "AI CLI：断开会话" },
    { "<C-.>", mode = { "n", "t", "i", "x" }, desc = "AI CLI：聚焦 CLI 窗口" },
  },
  opts = {
    nes = { enabled = false }, -- 不接 Copilot（本机既无 copilot-language-server 也无订阅）
    -- 不用 cli.mux（tmux/zellij 会话保持）：上游默认就是关的，本机也**不要**这层 ——
    -- 关掉后 CLI 直接跑在 nvim 的终端里（nvim 终端 → grok），滚轮能按 nvim 的规则转发给程序
    -- （terminal.txt:88-96「程序申请了鼠标事件就转发」）；开 tmux 反而多一层拦鼠标。
  },
  config = function(_, opts)
    require("sidekick").setup(opts)

    local map = vim.keymap.set
    local cli = function()
      return require("sidekick.cli")
    end

    map("n", "<leader>aa", function()
      cli().toggle()
    end, { desc = "AI CLI：开关面板" })
    map("n", "<leader>as", function()
      cli().select({ filter = { installed = true } })
    end, { desc = "AI CLI：选工具（只列已安装）" })
    map({ "n", "x" }, "<leader>at", function()
      cli().send({ msg = "{this}" })
    end, { desc = "AI CLI：发送当前上下文" })
    map("n", "<leader>ad", function()
      cli().close()
    end, { desc = "AI CLI：断开会话" })
    map({ "n", "t", "i", "x" }, "<C-.>", function()
      cli().focus()
    end, { desc = "AI CLI：聚焦 CLI 窗口" })
  end,
}
