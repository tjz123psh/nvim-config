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

-- 把按键**直接写进 CLI 的 pty**（终端模式下 nvim 会原样转发给程序）。
-- ⚠ 不用 sidekick 的 t:send()：它走 nvim_put 模拟键入，ESC 序列可能被 nvim 当成
-- "退出终端模式"而不是转发（滚轮 → PageUp 这类转义序列必须走 pty）。
-- ⚠ 必须定义在文件顶层：opts 表里的闭包在 spec 解析期就建好了，定义在 config 里会拿到 nil。
local function pty_send(t, keys)
  local chan = t.job or (t.buf and vim.bo[t.buf].channel)
  if chan and chan > 0 then
    vim.api.nvim_chan_send(chan, keys)
  end
end

return {
  "folke/sidekick.nvim",
  keys = {
    { "<leader>aa", desc = "AI CLI：开关面板" },
    { "<leader>as", desc = "AI CLI：选工具（只列已安装）" },
    { "<leader>at", mode = { "n", "x" }, desc = "AI CLI：发送当前上下文" },
    { "<leader>ad", desc = "AI CLI：断开会话" },
    { "<leader>aR", desc = "AI CLI：重启当前会话（重读 CLI 主题/配置）" },
    { "<C-.>", mode = { "n", "t", "i", "x" }, desc = "AI CLI：聚焦 CLI 窗口" },
  },
  opts = {
    nes = { enabled = false }, -- 不接 Copilot（本机既无 copilot-language-server 也无订阅）
    cli = {
      mux = { backend = "tmux", enabled = true }, -- 会话用 tmux 保持（本机有 tmux）
      win = {
        keys = {
          -- 往上翻看 AI 输出（2026-09-25 用户提问）：
          -- codex / opencode 这类 CLI 跑在**全屏 TUI（备用屏幕）**里，历史输出**不进** nvim 的
          -- 终端缓冲 ⇒ 按 jk 回普通模式后 k / 滚轮都翻不到东西（那不是 bug，是备用屏幕的特性）。
          -- sidekick 的做法是让 tmux 抓最近 2000 行（cli.mux.dump）另开一个可翻可搜的缓冲区。
          -- 上游默认只在你**把滚轮放在面板上滚**时打开它；这里再给一个键盘入口（Alt+U）。
          -- 打开后：j/k、<C-u>/<C-d>、gg/G、/ 搜索都能用；按 i 回到实时 CLI。
          -- ⚠ opencode 被上游标记 native_scroll = true ⇒ 它没有 scrollback，要用它自己的滚动键。
          -- 鼠标滚轮 → 翻页键（2026-09-25 用户要「滚轮滚动」）：
          -- grok / codex 这类全屏 TUI **不支持鼠标**（实测 grok 二进制里 EnableMouseCapture /
          -- MouseEvent / ScrollWheelUp 都是 0 处），滚轮只会被 nvim 拿去滚那个**空的**终端缓冲
          -- （历史在备用屏幕里，终端没有历史）。而它们的 pager 认 PageUp/PageDown
          -- （grok 自带文档：PageUp/PageDown 翻整页；Ctrl+J 在终端里等于回车、Ctrl+U 被输入行占用，
          -- 所以只有 PageUp/PageDown 可靠）。这里把滚轮翻译成翻页键**发进 pty**。
          -- mode 含 "t"：实测终端模式下映射也会触发 ⇒ 聊天时直接滚即可，不用先按 jk。
          -- ⚠ 必须直接写 pty（nvim_chan_send），不能用 t:send()：后者走 nvim_put 模拟键入，
          -- ESC 序列可能被当成"退出终端模式"而不是转发给程序。
          wheel_up = {
            "<ScrollWheelUp>",
            function(t)
              pty_send(t, "\x1b[5~") -- PageUp
            end,
            mode = "nt",
            desc = "滚轮上滚（→ PageUp，TUI 自己翻页）",
          },
          wheel_down = {
            "<ScrollWheelDown>",
            function(t)
              pty_send(t, "\x1b[6~") -- PageDown
            end,
            mode = "nt",
            desc = "滚轮下滚（→ PageDown）",
          },
          scrollback = {
            "<M-u>",
            function(t)
              local sb = t.scrollback
              if not (sb and require("sidekick.cli.scrollback").is_enabled(t)) then
                vim.notify(
                  "这个 CLI 自己处理滚动（如 opencode）：用它自己的翻页键或鼠标",
                  vim.log.levels.INFO
                )
                return
              end
              if sb:is_open() then
                sb:close() -- 再按一次：回到实时 CLI
              else
                sb:update({ open = true })
                if vim.fn.mode() == "t" then
                  vim.cmd.stopinsert() -- 直接进普通模式，可以立刻 j/k 翻
                end
              end
            end,
            mode = "nt",
            desc = "历史输出：开关 scrollback（打开后 j/k、<C-u>/<C-d>、gg/G、/ 搜索；再按一次或按 i 回实时）",
          },
        },
      },
    },
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
    -- 重启会话（2026-09-25 用户反馈「关了面板再开还是旧主题」）：
    -- 会话是用 tmux 保持的（cli.mux.enabled = true）⇒ close() 只是 **detach**，
    -- CLI 进程还活着，它只在启动时读一次自己的主题/配置 ⇒ 必须**结束进程**才会重读。
    -- 这里：杀掉该会话对应的 tmux 会话 → 断开 → 用同一个工具重开（= 全新进程）。
    -- 取"当前会话"：优先当前窗口（面板聚焦时），否则取任意一个活着的会话
    local function current_terminal()
      local terminals = require("sidekick.cli.terminal").terminals
      local sid = vim.w[vim.api.nvim_get_current_win()].sidekick_session_id
      if sid and terminals[sid] then
        return terminals[sid]
      end
      for _, t in pairs(terminals) do
        return t
      end
    end
    map("n", "<leader>aR", function()
      local t = current_terminal()
      if not t then
        vim.notify("当前没有 sidekick 会话（先用 <leader>aa / <leader>as 打开）", vim.log.levels.INFO)
        return
      end
      local tool = t.tool and t.tool.name
      local name = (t.id or ""):gsub("^terminal: ", "") -- tmux 会话名就是 "<工具> <hash>"
      if name ~= "" then
        vim.fn.system({ "tmux", "kill-session", "-t", name })
      end
      cli().close()
      vim.defer_fn(function()
        cli().show({ name = tool })
      end, 150)
      vim.notify(
        "已重启 " .. tostring(tool) .. " 会话（会重新读取它自己的主题/配置）",
        vim.log.levels.INFO
      )
    end, { desc = "AI CLI：重启当前会话（重读 CLI 主题/配置）" })
    map({ "n", "t", "i", "x" }, "<C-.>", function()
      cli().focus()
    end, { desc = "AI CLI：聚焦 CLI 窗口" })
  end,
}
