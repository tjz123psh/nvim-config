-- ============================================
-- :GrokChat —— 用 nvim 打开 grok 最近的会话记录
-- ============================================
-- 为什么需要（2026-09-25 用户反复反馈「翻不动」）：
--   grok 的界面是**全屏 TUI**，跑在终端的**备用屏幕**上 ⇒ 终端里没有历史（实测 tmux
--   alternate_on=1 / history_size=0 / capture-pane 只有当前一屏）；而且它在 sidekick 面板里
--   还隔着 nvim 终端 + tmux 两层，滚轮会被 nvim 吃掉 ⇒ 面板里怎么滚都没内容。
--   但 grok 把**完整对话**写在磁盘上：
--     ~/.grok/sessions/<cwd 的 URL 编码>/<session-id>/chat_history.jsonl
--   这里把它渲染成一个**普通缓冲区**：可 j/k、滚轮、/ 搜索、复制 —— 彻底绕开 TUI 的限制。
--
-- 用法：:GrokChat [目录]（默认当前 cwd）　快捷键 <leader>ah

local M = {}

--- grok 的会话目录名 = cwd 做 URL 编码（/ → %2F、空格 → %20，其余非 [A-Za-z0-9-._] 也编码）
local function encode_dir(dir)
  return (dir:gsub("[^%w%-%._]", function(c)
    return ("%%%02X"):format(c:byte())
  end))
end

--- 取该目录下**最近修改**的会话目录
local function latest_session(dir)
  local root = vim.fn.expand("~/.grok/sessions/") .. encode_dir(dir)
  if vim.fn.isdirectory(root) == 0 then
    return nil
  end
  local best, best_t = nil, -1
  for _, p in ipairs(vim.fn.glob(root .. "/*", false, true)) do
    if vim.fn.isdirectory(p) == 1 then
      local t = vim.fn.getftime(p)
      if t > best_t then
        best, best_t = p, t
      end
    end
  end
  return best
end

--- content 可能是字符串，也可能是 [{type="text", text="..."}] 之类的数组
local function content_text(c)
  if type(c) == "string" then
    return c
  end
  if type(c) == "table" then
    local parts = {}
    for _, x in ipairs(c) do
      if type(x) == "table" and type(x.text) == "string" then
        parts[#parts + 1] = x.text
      elseif type(x) == "string" then
        parts[#parts + 1] = x
      end
    end
    return table.concat(parts, "\n")
  end
  return ""
end

local function first_line(s, max)
  s = tostring(s or ""):gsub("%s+", " "):gsub("^ ", "")
  -- ⚠ 必须按**字符**截断：s:sub 是按字节，会把中文/emoji 切成半个字（显示成 <e3><80> 这种乱码）
  if vim.fn.strchars(s) > max then
    s = vim.fn.strcharpart(s, 0, max) .. " …"
  end
  return s
end

--- 把 chat_history.jsonl 渲染成 markdown 行
local function render(jsonl)
  local out = {}
  local fh = io.open(jsonl, "r")
  if not fh then
    return nil
  end
  for line in fh:lines() do
    if line:match("%S") then
      local ok, o = pcall(vim.json.decode, line)
      if ok and type(o) == "table" then
        local t = o.type
        if t == "user" then
          local txt = content_text(o.content)
          if txt:match("%S") then
            out[#out + 1] = "## 👤 你"
            out[#out + 1] = ""
            for _, l in ipairs(vim.split(txt, "\n", { plain = true })) do
              out[#out + 1] = l
            end
            out[#out + 1] = ""
          end
        elseif t == "assistant" then
          local txt = content_text(o.content)
          if txt:match("%S") then
            out[#out + 1] = "## 🤖 Grok"
            out[#out + 1] = ""
            for _, l in ipairs(vim.split(txt, "\n", { plain = true })) do
              out[#out + 1] = l
            end
            out[#out + 1] = ""
          end
          if type(o.tool_calls) == "table" and #o.tool_calls > 0 then
            local names = {}
            for _, tc in ipairs(o.tool_calls) do
              local fn = type(tc) == "table" and tc["function"] or nil -- 注意：function 是 Lua 关键字
              local n = (type(fn) == "table" and fn.name) or (type(tc) == "table" and tc.name) or "?"
              names[#names + 1] = n
            end
            out[#out + 1] = "> 🔧 调用：" .. table.concat(names, ", ")
            out[#out + 1] = ""
          end
        elseif t == "reasoning" then
          local s = o.summary
          if type(s) == "string" and s:match("%S") then
            out[#out + 1] = "> 🧠 " .. first_line(s, 160)
            out[#out + 1] = ""
          end
        elseif t == "tool_result" then
          local s = first_line(o.content, 160)
          if s ~= "" then
            out[#out + 1] = "> 🔧 结果：" .. s
            out[#out + 1] = ""
          end
        end
      end
    end
  end
  fh:close()
  return out
end

function M.open(dir)
  dir = dir or vim.fn.getcwd()
  local session = latest_session(dir)
  if not session then
    vim.notify(
      "没找到 grok 会话目录：" .. dir .. "\n（grok 只在自己启动过的目录下建会话）",
      vim.log.levels.WARN
    )
    return
  end
  local jsonl = session .. "/chat_history.jsonl"
  local lines = render(jsonl)
  if not lines or #lines == 0 then
    vim.notify("会话记录为空：" .. jsonl, vim.log.levels.WARN)
    return
  end
  local header = {
    "# Grok 会话记录（只读）",
    "",
    "- 会话：`" .. vim.fn.fnamemodify(session, ":t") .. "`",
    "- 来源：`" .. jsonl .. "`",
    "- 提示：`gg` 到最早、`G` 到最新；`/` 搜索；滚轮可直接滚（这是普通缓冲区，不是终端）",
    "",
    "---",
    "",
  }
  vim.list_extend(header, lines)

  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_set_name(buf, "grok-chat://" .. vim.fn.fnamemodify(session, ":t"))
  vim.api.nvim_win_set_cursor(0, { #header, 0 }) -- 直接跳到最新一条回复
  vim.cmd("normal! zz")
  vim.notify("已打开 grok 会话记录（" .. #header .. " 行，已跳到最新）", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("GrokChat", function(cmd)
  M.open(cmd.args ~= "" and cmd.args or nil)
end, { nargs = "?", complete = "dir", desc = "用只读缓冲区打开 grok 最近的会话记录" })

return M
