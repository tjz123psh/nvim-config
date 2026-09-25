-- ============================================
-- 中文标点输入即转半角
-- 插入模式下把 ，。；：！？等全角标点直接变成 ,.;:!?
-- ============================================
-- 为什么不用插件（2026-09-25 查证）：
--   · 没有做「输入即转」的现成插件（cpc.nvim 是命令式转换的 2★ 小插件，只能整篇/选区手动转）；
--   · autocorrect（huacnlee，1.6k★）规则**恰好相反** —— 它把 CJK 旁边的标点转成**全角**，
--     只在英文内容里才转半角（README 规则 fullwidth / halfwidth-punctuation）。
-- 所以用 InsertCharPre + vim.v.char 自己实现（Neovim 0.8+ 允许改写待插入字符），零依赖、无延迟。
--
-- 命令：:CJKPunct 开关（默认开）　:CJKPunctFix 把当前缓冲区/选区里已有的全角标点转半角
-- 默认在 markdown / text / gitcommit / help 里**不转**（这些场景全角才是对的）；
-- 想让它在所有文件类型生效：把下面 exclude_ft 清空即可。粘贴的内容不会触发 InsertCharPre，用 :CJKPunctFix 补。

local M = {}

-- 全角 → 半角对照表（标点 + 全角空格）
M.map = {
  ["，"] = ",",
  ["。"] = ".",
  ["、"] = ",",
  ["；"] = ";",
  ["："] = ":",
  ["！"] = "!",
  ["？"] = "?",
  ["（"] = "(",
  ["）"] = ")",
  ["【"] = "[",
  ["】"] = "]",
  ["《"] = "<",
  ["》"] = ">",
  ["「"] = '"',
  ["」"] = '"',
  ["『"] = "'",
  ["』"] = "'",
  ["“"] = '"',
  ["”"] = '"',
  ["‘"] = "'",
  ["’"] = "'",
  ["—"] = "-",
  ["～"] = "~",
  ["…"] = "...",
  ["·"] = ".",
  ["　"] = " ",
}

-- 这些文件类型里保留全角标点
M.exclude_ft = { markdown = true, text = true, gitcommit = true, help = true }

vim.g.cjk_punct = true -- 默认开启

local function enabled()
  if not vim.g.cjk_punct then
    return false
  end
  return not M.exclude_ft[vim.bo.filetype]
end

-- ⚠ 不能用 Lua 的 [...] 字符类：它按**单字节**匹配，多字节汉字的 UTF-8 序列会被拆成
-- 若干单字节，既匹配不到完整字符、也查不到 M.map。这里按"一个完整 UTF-8 字符"匹配再查表。
local function convert(text)
  return (text:gsub("[\1-\127\194-\244][\128-\191]*", function(c)
    return M.map[c] or c
  end))
end

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = vim.api.nvim_create_augroup("CJKPunct", { clear = true }),
  desc = "全角标点输入即转半角（:CJKPunct 可关）",
  callback = function()
    if not enabled() then
      return
    end
    local repl = M.map[vim.v.char]
    if repl then
      vim.v.char = repl
    end
  end,
})

vim.api.nvim_create_user_command("CJKPunct", function()
  vim.g.cjk_punct = not vim.g.cjk_punct
  vim.notify("中文标点自动转半角：" .. (vim.g.cjk_punct and "已开启" or "已关闭"), vim.log.levels.INFO)
end, { desc = "切换「全角标点输入即转半角」" })

vim.api.nvim_create_user_command("CJKPunctFix", function(cmd)
  local first, last
  if cmd.range == 2 then
    first, last = cmd.line1, cmd.line2
  else
    first, last = 1, vim.api.nvim_buf_line_count(0)
  end
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local changed = 0
  for i, line in ipairs(lines) do
    local new = convert(line)
    if new ~= line then
      lines[i] = new
      changed = changed + 1
    end
  end
  if changed > 0 then
    vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
  end
  vim.notify(string.format("已把 %d 行里的全角标点转成半角", changed), vim.log.levels.INFO)
end, { range = true, desc = "当前缓冲区/选区的全角标点转半角" })

return M
