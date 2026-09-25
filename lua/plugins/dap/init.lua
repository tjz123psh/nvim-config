-- ============================================
-- 调试适配器协议：nvim-dap
-- 提供统一的调试界面，支持打断点、单步执行、变量查看
-- 配合 dap-ui 显示调试面板，配合 dap-virtual-text 行内显示变量值
-- ============================================

return {
  "mfussenegger/nvim-dap",
  keys = {
    { "<F5>", desc = "继续执行" },
    { "<F9>", desc = "切换断点" },
    { "<F10>", desc = "单步跳过" },
    { "<F11>", desc = "单步进入" },
    { "<F12>", desc = "单步跳出" },
    { "<leader>dl", desc = "重跑上次调试" },
    { "<leader>db", desc = "断点列表" },
    { "<leader>dB", desc = "条件断点" },
    { "<leader>dL", desc = "日志断点" },
    { "<leader>dC", desc = "清除所有断点" },
  },
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
    {
      "theHamsta/nvim-dap-virtual-text",
      opts = {
        all_frames = true,
        virt_text_pos = "eol",
      },
    },
  },

  opts = {},

  config = function(_, opts)
    local dap = require("dap")
    local dapui = require("dapui")

    for name, adapter in pairs(opts.adapters or {}) do
      dap.adapters[name] = adapter
    end
    for lang, configs in pairs(opts.configurations or {}) do
      dap.configurations[lang] = configs
    end

    -- 侧栏放右侧，避免和 neo-tree（左侧）冲突
    dapui.setup({
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.25 },
            { id = "breakpoints", size = 0.25 },
            { id = "stacks", size = 0.25 },
            { id = "watches", size = 0.25 },
          },
          -- 45 是 200+ 列下的舒适值；窄终端（80 列）按 32% 收缩，最少 28 列
          size = math.max(28, math.min(45, math.floor(vim.o.columns * 0.32))),
          position = "right",
        },
        {
          elements = { "repl", "console" },
          size = 10,
          position = "bottom",
        },
      },
    })

    -- 调试开始自动打开 UI，结束自动关闭
    -- 监听 attach/launch（非 event_initialized），反应更及时
    dap.listeners.before.attach.dapui_config = dapui.open
    dap.listeners.before.launch.dapui_config = dapui.open
    dap.listeners.before.event_terminated["dapui_config"] = dapui.close
    dap.listeners.before.event_exited["dapui_config"] = dapui.close

    -- 断点符号（默认 B/C/R/L 不够直观，改用 Nerd Font 符号）
    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn" })
    vim.fn.sign_define("DapBreakpointRejected", { text = "✕", texthl = "DiagnosticSignHint" })
    vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticSignInfo" })
    vim.fn.sign_define("DapStopped", { text = "→", texthl = "SignColumn", linehl = "debugPC" })

    -- DAP 全局快捷键（Java 中 <F5> 被 buffer-local 覆盖）
    vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "重跑上次调试" })
    vim.keymap.set("n", "<leader>db", function()
      dap.list_breakpoints(true)
    end, { desc = "断点列表" })
    -- ⚠ vim.fn.input 取消(Esc)返回 ""，而 "" 在 Lua 里为真 ⇒ 旧写法在取消时照样设出一个断点。
    --   2026-09-25 用原始 setBreakpoints 报文实测（java-debug 0.53.2）：空 logMessage / condition /
    --   hitCondition 上游**不报错**，而是退化成**普通断点**（符号 ●、运行时会真的停住，不是"无害的假断点"）。
    --   所以 Esc 取消时必须直接不建，并给出提示。
    vim.keymap.set("n", "<leader>dB", function()
      local cond = vim.fn.input("断点条件（Esc 取消）: ")
      if cond == "" then
        vim.notify("已取消：条件为空，不设置条件断点", vim.log.levels.INFO)
        return
      end
      dap.set_breakpoint(cond)
    end, { desc = "条件断点" })
    vim.keymap.set("n", "<leader>dL", function()
      local log = vim.fn.input("日志（Esc 取消）: ")
      if log == "" then
        vim.notify("已取消：日志为空，不设置日志断点", vim.log.levels.INFO)
        return
      end
      dap.set_breakpoint(nil, nil, log)
    end, { desc = "日志断点" })
    vim.keymap.set("n", "<leader>dC", dap.clear_breakpoints, { desc = "清除所有断点" })
    vim.keymap.set("n", "<F5>", dap.continue, { desc = "继续执行" })
    vim.keymap.set("n", "<F9>", dap.toggle_breakpoint, { desc = "切换断点" })
    vim.keymap.set("n", "<F10>", dap.step_over, { desc = "单步跳过" })
    vim.keymap.set("n", "<F11>", dap.step_into, { desc = "单步进入" })
    vim.keymap.set("n", "<F12>", dap.step_out, { desc = "单步跳出" })
  end,
}
