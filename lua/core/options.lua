-- ============================================
-- Neovim 全局设置
-- 这里控制编辑器的基本行为
-- ============================================

-- 禁用不用的外部 provider，清 checkhealth 警告
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- 终端内的 TUI 依赖 COLORTERM 检测真彩色；尊重用户已经设置的值。
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
vim.o.updatetime = 250 -- 空闲事件和交换文件更新时间（毫秒），不控制本配置的自动保存
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
