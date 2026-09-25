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

    -- 面板背景必须是实底：sidekick 的终端窗口用 winhighlight 把 Normal 指向 SidekickChat
    -- （lua/sidekick/cli/terminal.lua:47），但它**自己没定义这个组**、官方文档也没提 ⇒
    -- 未定义 = 没有背景色，在 transparent_background 主题下壁纸直接透进面板，CLI 的次要文字
    -- （ANSI 8 灰 #7f849c）糊在壁纸上、看着像"主题被 nvim 带跑偏"（2026-09-25 用户截图）。
    -- 这里补一个实底版本，与 picker / 状态栏同色（base #1e1e2e），换主题后重新应用。
    local function solid_panel_bg()
      local ok, pal = pcall(function()
        return require("catppuccin.palettes").get_palette()
      end)
      vim.api.nvim_set_hl(0, "SidekickChat", {
        bg = ok and pal.base or "#1e1e2e",
        fg = ok and pal.text or "#cdd6f4",
      })
    end
    solid_panel_bg()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = solid_panel_bg,
      desc = "sidekick 终端面板保持实底（补它未定义的 SidekickChat）",
    })

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
