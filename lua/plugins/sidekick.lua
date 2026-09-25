-- ============================================
-- sidekick.nvim：在 Neovim 里跑 AI CLI（folke）
-- ============================================
-- 为什么装：把 codex / opencode / grok 这类 AI CLI 放进 nvim 面板，能把「当前文件 / 光标处 /
-- 诊断」当上下文直接发过去（{this} / {file} / {diagnostics}），另有预置 prompt 库；
-- 配 tmux 还能保持会话、AI 改了文件 nvim 自动重载。
--
-- 只启用 CLI 那一半：NES（Copilot 的 Next Edit Suggestions）需要 copilot-language-server
-- + GitHub Copilot 订阅，本机两者都没有 ⇒ nes.enabled = false。将来想开：Mason 装
-- copilot-language-server → 写 lsp/copilot.lua → :LspCopilotSignIn 登录 → 把 nes 键位
-- 避开 <Tab>（<Tab> 已是 blink.cmp / neotab 的）。
-- 键位：<leader>a* 此前为空（本配置 leader 组只有 b/c/d/f/h/r/s/t/v/w/G/J/m/o/R）。
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
    cli = { mux = { backend = "tmux", enabled = true } }, -- 会话用 tmux 保持（本机有 tmux）
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
