-- ============================================
-- Neovim 全局设置
-- 这里控制编辑器的基本行为
-- ============================================

-- 禁用不用的外部 provider，清 checkhealth 警告
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- 让 :terminal 里的 TUI 知道"这里支持真彩色"
-- nvim 给 :terminal 子进程只设 TERM=xterm-256color、**不设 COLORTERM**（实测），
-- 于是 grok / opencode 这类 TUI 会判定为非真彩色并**隐藏需要 truecolor 的主题**：
--   TERM=xterm-256color           → grok doctor: color 256   · themes 2/5
--   COLORTERM=truecolor 再加上    → grok doctor: color truecolor · themes all
-- nvim 自己的终端模拟器与 Neovide 都支持 24 位色，所以补上这个变量；
-- 用户已显式设过 COLORTERM 时不覆盖。
if (vim.env.COLORTERM or "") == "" then
  vim.env.COLORTERM = "truecolor"
end

-- 界面显示
vim.o.number = true -- 显示行号
vim.o.relativenumber = false -- 不显示相对行号，保持行号稳定易读
vim.o.signcolumn = "yes" -- 始终显示左侧符号列（LSP 诊断图标、Git 标记等）
vim.o.cursorline = true -- 高亮光标所在行
vim.o.termguicolors = true -- 启用真彩色（需要终端支持）
vim.opt.fillchars:append({ eob = " " }) -- 文件末尾的 ~ 改成空格
vim.o.scrolloff = 8 -- 光标上下保留上下文
vim.o.sidescrolloff = 8 -- 水平滚动时保留左右上下文
vim.o.splitbelow = true -- 新水平窗口在下方
vim.o.splitright = true -- 新垂直窗口在右侧
if vim.fn.exists("+winborder") == 1 then
  vim.o.winborder = "rounded" -- 内置浮动窗口统一圆角边框
end

-- 缩进和制表符
vim.o.tabstop = 4 -- 按 Tab 时显示的宽度
vim.o.shiftwidth = 4 -- 自动缩进的宽度（>> 或 << 时）
vim.o.expandtab = true -- 按 Tab 输入空格而不是制表符
vim.o.smartindent = true -- 智能缩进（根据语法自动调整）

-- 搜索
vim.o.ignorecase = true -- 搜索时忽略大小写
vim.o.smartcase = true -- 搜索包含大写时自动区分大小写
vim.o.hlsearch = false -- 不高亮搜索匹配结果
vim.o.inccommand = "split" -- 替换命令实时预览

-- 性能
vim.o.updatetime = 250 -- 更新时间（毫秒），影响自动保存、LSP 等
vim.o.timeoutlen = 500 -- 快捷键超时时间（毫秒），给 leader/which-key 留出更稳的输入窗口

-- 剪贴板
vim.opt.clipboard:append("unnamedplus") -- 与系统剪贴板互通（复制粘贴）

-- 撤销记录
vim.o.undofile = true -- 保存撤销历史到文件（重启后仍可撤销）

-- Shell（用于 :! 等命令）
vim.o.shell = vim.fn.exepath("bash") ~= "" and vim.fn.exepath("bash") or vim.o.shell

-- 补全菜单行为
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- 退出或关闭含未保存修改的缓冲区时确认，避免误丢内容
vim.o.confirm = true

-- 命令行区域高度为 0（配合 noice.nvim 使用浮动窗口显示命令）
vim.o.cmdheight = 0

-- 安全
vim.o.modeline = false -- 关闭 modeline，防止恶意文件执行任意命令

-- LSP 日志只记录 ERROR，防止日志长期膨胀
vim.lsp.log.set_level(vim.log.levels.ERROR)

-- 但只记 ERROR 不等于不会长大（历史到过 27MB）⇒ 启动时做一次**容量轮转**：
-- 超过 5MB 就改名成 lsp.log.1（覆盖上一份、不删内容）；只有一次 fs_stat + rename。
do
  local log_path = vim.lsp.log.get_filename()
  local ok, stat = pcall(vim.uv.fs_stat, log_path)
  if ok and stat and stat.size > 5 * 1024 * 1024 then
    pcall(vim.uv.fs_rename, log_path, log_path .. ".1")
  end
end

-- 按「显示宽度」折行（CJK 算 2 列）。为什么需要：virtual_lines 的渲染器用
-- virt_lines_overflow='scroll'，**自己不折行** —— 消息超过窗口宽度就被右边缘直接裁掉
-- （2026-09-25 用户截图：`…for the arguments (Instant, OffsetDat` 被切掉）。
-- 但它按 \n 切分消息（runtime/lua/vim/diagnostic.lua:2138 的 gmatch('([^\n]+)')），
-- 每行都会带 └──── 前缀、续行缩进 6 格对齐 ⇒ 我们自己把 \n 插进去就能完整显示。
-- ⚠ 保留每行的**前导空白**（2026-09-28 审查 B05）：旧实现用 `vim.split(para, "%s+")`
--   把整行压成「单词+单空格」，编译器错误里靠缩进对齐的指示符全部错位：
--     `    baz.qux();` / `       ^`  →  `baz.qux(); ^`（`^` 指到行中间，完全失去指认能力）。
--   现在分三类：① 错误指示符行（含 ^ ~ 且没有别的词）整行不折；② 其余行保留前导缩进后再折；
--   ③ 只有行内空白仍会被压成单空格（跨行拼接本来就是这个语义，无害）。
local function wrap_message(text, width)
  local out = {}
  for _, para in ipairs(vim.split(text, "\n", { plain = true })) do
    local trimmed = vim.trim(para)
    -- ① 指示符行：只有 ^ 或 ~（javac/ECJ 的指着箭头），折行会让箭头指错位置 ⇒ 原样保留
    if trimmed ~= "" and trimmed:match("^[%^~]+$") then
      out[#out + 1] = para
      goto continue
    end
    local indent = para:match("^(%s*)") or ""
    local avail = math.max(10, width - vim.fn.strdisplaywidth(indent))
    local line, line_w = "", 0
    for _, word in ipairs(vim.split(para, "%s+", { trimempty = true })) do
      local word_w = vim.fn.strdisplaywidth(word)
      if line_w > 0 and line_w + 1 + word_w > avail then
        out[#out + 1] = indent .. line
        line, line_w = "", 0
      end
      if word_w > avail then -- 超长 token（长包名 / 长签名）硬断
        for _, ch in ipairs(vim.fn.split(word, "\\zs")) do
          local cw = vim.fn.strdisplaywidth(ch)
          if line_w + cw > avail and line_w > 0 then
            out[#out + 1] = indent .. line
            line, line_w = "", 0
          end
          line, line_w = line .. ch, line_w + cw
        end
      else
        if line_w > 0 then
          line, line_w = line .. " ", line_w + 1
        end
        line, line_w = line .. word, line_w + word_w
      end
    end
    if line_w > 0 then
      out[#out + 1] = indent .. line
    end
    ::continue::
  end
  if #out > 12 then -- 超长消息别把整屏占满；按 ]d 弹的浮窗里仍是完整的
    out = vim.list_slice(out, 1, 12)
    out[12] = out[12] .. " …"
  end
  return table.concat(out, "\n")
end

-- 诊断提示样式
vim.diagnostic.config({
  -- 同一行有多条诊断时，行尾 virt_text 只显示「最后一条」（runtime diagnostic.lua:2277），
  -- 不开 severity_sort 时那一条是插入序最后一条（可能只是 WARN），符号列也会画 W 而不是 E
  severity_sort = true,
  -- 光标所在行的诊断改成"整行显示在下一行"（virtual_lines），此时该行行尾的 ● 文字是重复的，
  -- 所以 virtual_text 关掉 current_line（其它行照旧）——这是 Neovim 文档推荐的搭配。
  -- 长消息（jdtls 的多行错误）在行尾挤不下，展开成整行可读性好很多。
  virtual_text = {
    spacing = 2,
    prefix = "●",
    source = "if_many",
    current_line = false, -- 当前行改由下面的 virtual_lines 整行显示，避免重复
    severity = { min = vim.diagnostic.severity.WARN }, -- INFO/HINT 只留符号列与下划线，不再占行尾
  },
  virtual_lines = {
    current_line = true, -- 光标所在行：把诊断整行展开在下一行（长消息不再被行尾截断）
    severity = { min = vim.diagnostic.severity.WARN },
    -- 默认格式是 "[code] message"，jdtls 的 code 是内部诊断号（如 [603979884]），去掉；
    -- 并按窗口宽度折行（virtual_lines 自己不折，见上面 wrap_message 的注释）。
    format = function(d)
      local wins = vim.fn.win_findbuf(d.bufnr or 0)
      local win = wins[1] or vim.api.nvim_get_current_win()
      local info = vim.fn.getwininfo(win)[1]
      local textoff = (info and info.textoff) or 0
      local ok, win_w = pcall(vim.api.nvim_win_get_width, win)
      local width = (ok and win_w or vim.o.columns) - textoff - 7 -- 7 = "└──── " 前缀 + 1 余量
      return wrap_message(d.message, math.max(20, width))
    end,
  },
  underline = true, -- 错误范围画波浪线
  signs = true, -- 左侧符号列图标
  float = {
    border = "rounded",
    source = "if_many",
    -- 默认会在消息末尾追加 " [code]"。jdtls 的 code 是内部诊断号（如 [603979884]），
    -- 纯噪音；但 eslint 规则名、rustc 的 E0308 这类文字码有用，所以只丢掉纯数字码。
    suffix = function(d)
      local code = d.code and tostring(d.code) or ""
      if code ~= "" and not code:match("^%d+$") then
        return (" [%s]"):format(code)
      end
      return ""
    end,
  },
  update_in_insert = false,
})

-- update_in_insert=false 时，runtime 收到诊断会**先 hide 再判断是否在插入模式**
-- （/usr/share/nvim/runtime/lua/vim/diagnostic.lua:2381-2398）：插入模式中只排期显示，
-- 而排期只挂在 InsertLeave / CursorHoldI 上（同文件 :854）。但 <C-c> 退出插入模式
-- **不触发 InsertLeave**（:h i_CTRL-C），<C-\><C-n>、:stopinsert 等路径也各有各的脾气
-- ⇒ 那批诊断的 signs / underline / virtual_text / virtual_lines 会一直缺失，而数据仍在
-- 缓存里（]d、vim.diagnostic.get 都正常），表现为「报错莫名其妙不见了」。
-- 实测 <Esc> / <C-c> / <C-[> / <C-@> / <C-\><C-n> / i_<F5>-><Cmd>stopinsert<CR> /
-- better-escape 的 jk 都会触发 ModeChanged 的 i*->n*，所以在这里补一次渲染覆盖所有出口。
-- 只重绘「窗口里可见的 buffer」（通常 1 个，实测 0.2-0.6ms；全量 show(nil,nil) 在
-- 多 buffer 会话里 10ms+，不适合放在每次退出插入模式时）。
vim.api.nvim_create_autocmd("ModeChanged", {
  group = vim.api.nvim_create_augroup("UserDiagnosticInsertLeaveFallback", { clear = true }),
  pattern = "i*:n*",
  callback = function()
    local done = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local bufnr = vim.api.nvim_win_get_buf(win)
      if not done[bufnr] then
        done[bufnr] = true
        vim.diagnostic.show(nil, bufnr)
      end
    end
  end,
  desc = "退出插入模式（含 <C-c>）后补渲染被 update_in_insert=false 隐藏的诊断",
})
