-- ============================================
-- 自动命令（Autocmds）
-- 在特定事件发生时自动执行某些操作
-- ============================================

-- 创建自动命令组（方便统一管理）
local augroup = vim.api.nvim_create_augroup("core", { clear = true })

-- Lua 文件跟随 stylua.toml，保持编辑缩进和格式化结果一致
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = "lua",
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
  end,
})

-- 打开 C/C++/Java/Python 文件时，设置缩进为 4 空格
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "cpp", "c", "java", "python" },
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end,
})

-- 进入插入模式时自动清除搜索高亮
-- 这样搜索后按 i 进入编辑，不会看到满屏黄色
vim.api.nvim_create_autocmd("InsertEnter", {
  group = augroup,
  callback = function()
    if vim.o.hlsearch then
      vim.o.hlsearch = false
    end
  end,
})

-- ============================================
-- 自动保存
-- 在离开缓冲区、失去焦点、退出等"告一段落"的时机写盘，免去手动保存。
-- 刻意不用 CursorHold 空闲触发：那会让每次停顿都叠加 format_on_save，
-- 尤其 Java 格式化需起 JVM，开销大。
-- 临时关闭：vim.g.core_autosave = false
-- ============================================
local function is_savable(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return false
  end

  local bo = vim.bo[buf]
  -- 仅保存有文件名、可修改、非只读且有改动的普通文件缓冲区
  if bo.buftype ~= "" or not bo.modifiable or bo.readonly then
    return false
  end

  return vim.api.nvim_buf_get_name(buf) ~= "" and bo.modified
end

-- 原生解析器负责命令缩写、计数和 :silent 等修饰符，不自己维护缩写白名单。
-- 只处理直接的 Ex 退出命令；插件/Lua 需要丢弃退出时可调用本模块的 quit_without_save。
local QUIT_COMMANDS = {
  quit = true,
  qall = true,
  quitall = true,
  cquit = true,
  wq = true,
  wqall = true,
  exit = true,
  xit = true,
  xall = true,
}
local function quit_commands(line)
  local commands = {}
  while line ~= "" do
    local ok, cmd = pcall(vim.api.nvim_parse_cmd, line, {})
    if not ok then
      break -- 无效命令不应让自动命令本身报错。
    end
    if QUIT_COMMANDS[cmd.cmd] then
      commands[#commands + 1] = {
        name = cmd.cmd,
        discard = cmd.cmd == "cquit" or (cmd.bang and (cmd.cmd == "quit" or cmd.cmd == "qall" or cmd.cmd == "quitall")),
      }
    end
    local nextcmd = cmd.nextcmd or ""
    if nextcmd == line then
      break
    end
    line = nextcmd
  end
  return commands
end

local pending_quits = {}
local discard_window -- 本次正在关闭的窗口；WinClosed 后不再阻止剩余会话的保存。
local discard_exit = false -- 最后一次 QuitPre 的意图，供进程退出时的 VimLeavePre 使用。
local protected_discard = 0 -- ZQ 的同步调用范围；即使其它自动命令 vim.wait，也不能提前清除。
local function clear_quit_state()
  pending_quits = {}
  discard_window = nil
  discard_exit = false
end

vim.api.nvim_create_autocmd("CmdlineEnter", {
  group = augroup,
  callback = clear_quit_state,
  desc = "新命令不继承旧的退出意图",
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = augroup,
  pattern = ":", -- 搜索命令行里的 q! 不是退出命令。
  callback = function()
    if not vim.v.event.abort then
      pending_quits = quit_commands(vim.fn.getcmdline())
    end
  end,
  desc = "按原生语法记录退出命令及丢弃意图",
})
vim.api.nvim_create_autocmd("WinClosed", {
  group = augroup,
  callback = function(ev)
    if tonumber(ev.match) == discard_window then
      discard_window = nil
    end
  end,
  desc = "目标窗口关闭后，立即恢复其余窗口的自动保存",
})
vim.api.nvim_create_autocmd("SafeState", {
  group = augroup,
  callback = function()
    if protected_discard == 0 then
      clear_quit_state()
    end
  end,
  -- SafeState 不在执行命令/映射中触发；不能用 schedule 代替，vim.wait 会提前运行它。
  desc = "命令执行完且回到输入等待时清理退出状态（含失败的退出）",
})

local saving = false -- 重入保护：写盘时可能触发 BufLeave/退出类事件

local function write_current()
  -- lockmarks 保留跳转列表和列位置，避免自动保存打断光标历史
  vim.cmd("silent! lockmarks write")
end

local function autosave_current_buf()
  if vim.g.core_autosave == false or saving then
    return
  end
  if discard_window or protected_discard > 0 then
    return
  end

  if is_savable(vim.api.nvim_get_current_buf()) then
    saving = true
    write_current()
    saving = false
  end
end

-- 退出前保存**所有**被改过的缓冲区。旧实现只存当前 buffer，
-- 后台改过的文件仍会让 :qa 弹"E37: 已修改但未保存"，自动保存等于白做。
-- nvim_buf_call 让 :write 作用在指定缓冲区上，结束后当前缓冲区/窗口不变。
local function autosave_all_bufs()
  if vim.g.core_autosave == false or saving then
    return
  end
  saving = true
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_savable(buf) then
      vim.api.nvim_buf_call(buf, write_current)
    end
  end
  saving = false
end

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  group = augroup,
  desc = "自动保存当前普通文件缓冲区",
  callback = autosave_current_buf,
})

vim.api.nvim_create_autocmd("QuitPre", {
  group = augroup,
  callback = function()
    local intent = protected_discard == 0 and table.remove(pending_quits, 1) or nil
    discard_exit = protected_discard > 0 or (intent and intent.discard) or false
    discard_window = discard_exit and vim.api.nvim_get_current_win() or nil
    -- 每次 QuitPre 单独决定，:q! | q 的第二个普通退出仍应保存。
    if not discard_exit then
      autosave_all_bufs()
    end
  end,
  desc = "普通退出保存全部修改；丢弃退出不自动写盘",
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = augroup,
  callback = function()
    -- :cquit 不触发 QuitPre，需在最终退出阶段读取它的意图。
    if pending_quits[1] and pending_quits[1].name == "cquit" then
      discard_exit = true
    end
    if not discard_exit and protected_discard == 0 then
      autosave_all_bufs()
    end
  end,
  desc = "进程退出时保留本次明确的保存/丢弃语义",
})

return {
  quit_without_save = function()
    protected_discard = protected_discard + 1
    local ok, err = pcall(vim.cmd.quit, { bang = true })
    protected_discard = protected_discard - 1
    discard_window, discard_exit = nil, false
    if not ok then
      error(err, 0)
    end
  end,
}
