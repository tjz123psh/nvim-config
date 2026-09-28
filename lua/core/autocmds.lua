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

local QUIT_NAMES = {
  q = true,
  qu = true,
  quit = true,
  qa = true,
  qall = true,
  quita = true,
  quitall = true,
  cq = true,
  cquit = true,
}

--- 这条命令行是不是带 ! 的退出（:q! / :qa! / :3q! / :cq）
--- ⚠ 必须定义在下面那些 autocmd **之前**：Lua 的 local 在声明点才进作用域，
---   写在后面的话闭包里引用到的是全局 nil（本轮实测踩过一次，:q! 仍然被保存）。
local function is_bang_quit(c)
  if c == "" then
    return false
  end
  c = vim.trim(c):gsub("^%d+%s*", "") -- 去掉 :3q! 里的计数
  local name, bang = c:match("^(%a+)(!?)$")
  if name == nil then
    return false
  end
  name = name:lower()
  -- :cq / :cquit 不带 ! 也是"放弃修改"退出（git 用它中止提交），要一并算上
  if name == "cq" or name == "cquit" then
    return true
  end
  return bang == "!" and QUIT_NAMES[name] == true
end

-- ⚠ 用户明确"放弃修改"时不能自动保存（2026-09-25 审查 F01）：
--   QuitPre/VimLeavePre 本身不区分 :q 与 :q!（实测 v:cmdbang 恒为 0、getcmdline 为空），
--   所以在 CmdlineLeave 里记下刚执行的那条命令行，退出链只看这一次的记录。
-- 状态要"粘住"整个退出链（QuitPre → BufLeave → VimLeavePre 都会触发保存），
-- 直到用户开始敲下一条命令才复位。
local discard_pending = false
vim.api.nvim_create_autocmd("CmdlineEnter", {
  group = augroup,
  desc = "开始输入新命令：清除上一次的放弃标记",
  callback = function()
    discard_pending = false
  end,
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = augroup,
  desc = "记住刚执行的命令行（用于识别 :q! / :qa! 的放弃语义）",
  callback = function()
    -- ⚠ <Esc> / <C-c> 中止命令行时也会触发本事件，且此时 getcmdline() 仍返回已敲的内容、
    --   vim.v.event.abort == true。不判 abort 的话，敲了 :q! 又反悔按 Esc 会把
    --   discard_pending 粘成 true，之后所有自动保存被静默 return（数据不落盘）。
    --   2026-09-28 实测：Esc 后切 buffer 不写盘，对照组写盘。
    if vim.v.event.abort then
      return
    end
    discard_pending = is_bang_quit(vim.fn.getcmdline())
  end,
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
  if discard_pending then
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
  -- :q! / :qa! / :cq 是"放弃修改"：这里若照常保存，用户以为丢掉的内容会落盘
  if discard_pending then
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

vim.api.nvim_create_autocmd({ "QuitPre", "VimLeavePre" }, {
  group = augroup,
  desc = "退出前保存所有被修改的普通文件缓冲区",
  callback = autosave_all_bufs,
})
