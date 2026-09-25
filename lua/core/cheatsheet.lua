-- ============================================
-- 快捷键速查浮窗（<leader>hk / :CheatSheet）
-- 新增快捷键时顺手在对应分类加一行即可
-- 格式：{ "按键", "说明（模式）" }
-- ============================================

local M = {}
local ns = vim.api.nvim_create_namespace("core_cheatsheet")

local state = {
  win = nil,
}

local sections = {
  {
    "行操作",
    {
      { "J", "下移当前行" },
      { "K", "上移当前行" },
      { "数字前缀 + J/K", "移动多行距离" },
      { "J / K", "下移/上移选中行（可视/选择）" },
      { "<leader>j", "合并下一行" },
    },
  },
  {
    "基础操作",
    {
      { "jk", "退出插入模式（i）" },
      { "jk", "退出终端模式（t）" },
      { "<C-s>", "保存文件（n,i）" },
      { "<C-CR>", "下方新建空行（i）" },
      { "s", "Flash 跳转（n,x,o）" },
      { "S", "Flash Treesitter 选择（n,x,o）" },
      { "<leader>hk", "打开/关闭本速查面板" },
      { "<leader>", "Leader 键（所有 <leader>xx 的前缀）" },
    },
  },
  {
    "窗口操作",
    {
      { "<C-h/j/k/l>", "切换窗口" },
      { "<leader>vh", "水平分割" },
      { "<leader>vv", "垂直分割" },
      { "<leader>q", "关闭窗口" },
      { "<leader>wq", "保存并关闭" },
    },
  },
  {
    "缓冲区",
    {
      { "<S-h>", "上一个缓冲区" },
      { "<S-l>", "下一个缓冲区" },
      { "<leader>ba", "关闭其他缓冲区" },
      { "<leader>bd", "关闭当前缓冲区" },
    },
  },
  {
    "文件树（neo-tree）",
    {
      { "<leader>e", "打开/关闭文件树" },
      { "Enter / o", "打开文件或目录" },
      { "h / l", "上级目录 / 设为根" },
      { "a / d / r / m", "新建 / 删除 / 重命名 / 移动" },
      { "c / y / x / p", "复制 / 复制到剪贴板 / 剪切 / 粘贴" },
      { "H", "显示/隐藏隐藏文件" },
      { "Z", "递归展开光标所在节点的所有子节点" },
      { ".", "已禁用（避免在树里误触）" },
    },
  },
  {
    "搜索（snacks picker）",
    {
      { "<leader>ff", "搜索文件名" },
      { "<leader>fg", "搜索文件内容" },
      { "<leader>fb", "切换缓冲区" },
      { "<leader>fh", "搜索帮助" },
      { "<leader>fp", "搜索项目" },
      { "<leader>fc", "搜索 Neovim 配置" },
    },
  },
  {
    "选择器通用键（snacks picker）",
    {
      { "<C-j> / <C-k>", "上/下移动（等同 <C-n> / <C-p>）" },
      { "<CR>", "确认选中" },
      { "<Tab> / <S-Tab>", "多选：勾选并下移 / 上移" },
      { "<Space>", "勾选/取消（多选列表：jdtls 主类、字段/方法选择等）" },
      { "<Esc> / <C-c>", "取消（不选中任何项）" },
      { "/", "在列表内搜索" },
    },
  },
  {
    "代码导航（LSP：需 LSP 附加）",
    {
      { "gd", "跳转到定义" },
      { "gR", "跳转到类型定义" },
      { "grr / gra / grn", "内置 LSP：查找引用 / 代码操作 / 重命名" },
      { "gi", "跳转到实现" },
      { "gh", "悬停文档" },
      { "[d / ]d", "上一个/下一个诊断" },
    },
  },
  {
    "代码操作（需 LSP）",
    {
      { "<leader>rn", "重命名符号" },
      { "<leader>ca", "代码操作" },
      { "<leader>F", "格式化代码" },
      { "<C-k>", "函数签名提示（i）" },
    },
  },
  {
    "补全（blink.cmp：插入模式）",
    {
      { "Enter", "选中当前项" },
      { "Shift-Tab", "跳上一个片段占位符" },
      { "Tab", "neotab 接管：括号/引号内按 Tab 跳到外侧（不是接受补全）" },
      { "<C-n> / <C-p>", "选择下一项/上一项" },
      { "<C-e>", "关闭补全菜单" },
      { "<C-u> / <C-d>", "文档翻页" },
    },
  },
  {
    "注释",
    {
      { "gcc", "注释/取消注释当前行（n）" },
      { "gc", "注释/取消注释选中（x）" },
    },
  },
  {
    "调试（DAP）",
    {
      { "<leader>dl", "重跑上次调试" },
      { "<leader>db", "断点列表（打开 quickfix 窗口）" },
      { "<leader>dB", "条件断点" },
      { "<leader>dL", "日志断点" },
      { "<leader>dC", "清除所有断点" },
      { "<F5>", "开始调试 / 继续" },
      { "<F9>", "切换断点" },
      { "<F10>", "单步跳过" },
      { "<F11>", "单步进入" },
      { "<F12>", "单步跳出" },
    },
  },
  {
    "终端（toggleterm）",
    {
      { "<leader>tt", "切换浮动终端" },
      { "<leader>th", "水平分割终端" },
      { "<leader>tv", "垂直分割终端" },
    },
  },
  {
    "AI CLI（sidekick，用已安装的 codex / opencode / grok）",
    {
      { "<leader>aa", "开关 AI CLI 面板" },
      { "<leader>as", "选工具（只列已安装的）" },
      { "<leader>at", "把当前上下文（{this}）发过去" },
      { "<leader>ad", "断开当前会话" },
      { "<C-.>", "聚焦 / 回到 CLI 窗口" },
    },
  },
  {
    "Java / Spring Boot（需 Java 缓冲区）",
    {
      { "<F5>", "Java: 调试（自动扫描主类，多个则选择）" },
      { "<leader>Jd", "Java: 重新扫描主类列表" },
      { "<leader>Jt", "Java: 终端运行光标处测试方法" },
      { "<leader>JT", "Java: 终端运行当前测试类" },
      { "<leader>Jg / <leader>JG", "Java: 调试测试方法 / 测试类" },
      { "<leader>co / <leader>ca", "代码操作" },
      { "<leader>ot", "整理 import" },
      { "gA", "跳转到父类/接口实现" },
      {
        "<leader>Rv / Rm / Rc / RV",
        "提取变量 / 方法 / 常量 / 所有重复表达式（可视=按选区，普通=按光标处表达式）",
      },
      { "<leader>sr", "Spring Boot: 运行项目" },
      { "<leader>sp", "Spring Boot 向导（11 步可搜索选择）" },
      { "<leader>Gc / Gi / Ge / Gr", "生成 Class / Interface / Enum / Record" },
    },
  },
  {
    "Maven / Gradle（需 Java 项目）",
    {
      { "<leader>mc", "编译" },
      { "<leader>mt", "跑测试" },
      { "<leader>mp", "打包（跳过测试）" },
      { "<leader>mi", "安装到本地仓库" },
      { "<leader>mn", "清理" },
      { "<leader>ml", "依赖树" },
      { "<leader>mb", "jdtls 重新导入/构建（改 pom 后用）" },
      { ":JavaBuildProjects", "同上（命令版）" },
      { ":JavaSetRuntime", "切换 JDK（IDEA 的 Project SDK）" },
    },
  },
  {
    "Neovide（仅 GUI）",
    {
      { "<C-=>", "放大（+10%）" },
      { "<C-->", "缩小（-10%）" },
      { "<C-0>", "重置缩放" },
    },
  },
  {
    "Markdown 阅读（render-markdown）",
    {
      { "<leader>Mt", "切换渲染（开/关）" },
      { "<leader>Mp", "侧边预览（渲染后的副本）" },
      { ":RenderMarkdown", "命令版：enable / disable / toggle / get / preview / config" },
      { "打开 .md", "标题、列表、表格、代码块、复选框自动就地渲染（不需要浏览器）" },
    },
  },
  {
    "消息与报错（noice）",
    {
      { "<leader>he", "最近的报错（:Noice errors）" },
      { "<leader>hh", "全部消息历史（:Noice history）" },
    },
  },
  {
    "自定义命令",
    {
      { ":R", "重载当前 Lua 配置文件" },
      { ":A", "打开欢迎页" },
      { ":Projects", "打开项目列表" },
      { ":LspInfo", "查看 LSP 客户端状态" },
      { ":LspLog", "打开 LSP 日志" },
      { ":JavaRun", "运行当前 Java 单文件" },
      { ":JavaBuildProjects", "jdtls 重新导入/构建（需 Java 项目）" },
      { ":JavaSetRuntime", "切换 JDK（需 Java 项目）" },
      { ":PickerSkin soft|pink", "切换 picker 皮肤（默认 soft；pink 为向导洋红）" },
      { ":SpringBootCreate", "Spring Boot 项目向导（同 <leader>sp）" },
      { ":SpringBoot / :SpringBootNewProject", "spring-boot.nvim 命令 / 原版向导" },
      { ":TSInstall / :TSUpdate / :TSConfigInfo", "Treesitter 解析器安装 / 更新 / 状态" },
      { ":Alpha / :Neotree / :ToggleTerm", "欢迎页 / 文件树 / 终端" },
    },
  },
}

-- 面板配色与 picker 保持一致（soft 皮肤由 plugins/snacks.lua 的 apply_skin() 覆盖；
-- 这里只给一份 default 兜底 link，粉色皮肤时就回落到主题色）。
local function define_highlights()
  vim.api.nvim_set_hl(0, "CheatSheetTitle", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetHint", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetSection", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetSeparator", { link = "FloatBorder", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetKey", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetText", { link = "NormalFloat", default = true })
  -- ⚠ 窗标题/边框/底色必须走 winhl 映射（FloatTitle 默认带蓝底、FloatBorder 默认是主题蓝），
  --   否则这个面板永远和 picker 不是一个色系（2026-09-25 实测：边框 #89b4fa、标题栏蓝底）。
  vim.api.nvim_set_hl(0, "CheatSheetBg", { link = "NormalFloat", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetBorder", { link = "FloatBorder", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetWinTitle", { link = "FloatTitle", default = true })
  vim.api.nvim_set_hl(0, "CheatSheetBar", { link = "Comment", default = true })
end

local function pad_right(text, width)
  local padding = width - vim.fn.strdisplaywidth(text)
  if padding <= 0 then
    return text
  end
  return text .. string.rep(" ", padding)
end

local function close_existing()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
    return true
  end
  return false
end

function M.show()
  if close_existing() then
    return
  end

  define_highlights()

  local lines = {}
  local marks = {}
  local key_marks = {}

  local available_width = math.max(1, vim.o.columns - 4)
  local width = math.min(84, available_width)
  local body_width = math.max(1, width - 4)
  local key_width = math.min(24, math.max(12, math.floor(body_width * 0.4)))

  local function add(line, hl)
    table.insert(lines, line)
    if hl then
      marks[#lines - 1] = hl
    end
  end

  -- 同一行可以有多段高亮（顶栏的标题 + 灰色提示、小节的 ▍ + 蓝色名字）
  local function add_mark(row_idx, start_col, end_col, hl)
    table.insert(key_marks, { row = row_idx, start_col = start_col, end_col = end_col, hl = hl })
  end

  do
    local head = "  ▍ 常用快捷键"
    -- 内容 120+ 行、小终端一屏放不下：必须提示能滚（j/k、<C-d>/<C-u>、gg/G 都可用）
    local hint = "j/k 滚动 · q / Esc 关闭  "
    add(pad_right(head, body_width - vim.fn.strdisplaywidth(hint)) .. hint)
    add_mark(0, 0, #head, "CheatSheetTitle")
    add_mark(0, #lines[1] - #hint, #lines[1], "CheatSheetHint")
  end
  add("  " .. string.rep("─", body_width), "CheatSheetSeparator")

  for _, sec in ipairs(sections) do
    add("")
    add("  ▍ " .. sec[1])
    add_mark(#lines - 1, 2, 5, "CheatSheetBar") -- "  ▍" 的 ▍（3 字节）
    add_mark(#lines - 1, 5, #lines[#lines], "CheatSheetSection")
    for _, item in ipairs(sec[2]) do
      local key = item[1]
      local line = "    " .. pad_right(key, key_width) .. item[2]
      add(line, "CheatSheetText")
      add_mark(#lines - 1, 4, 4 + #key, "CheatSheetKey")
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local available_height = math.max(1, vim.o.lines - 4)
  local height = math.min(#lines, available_height)
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local title = width >= 32 and " 快捷键速查  <leader>hk " or " 快捷键 "
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    row = row,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })
  state.win = win

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for row_idx, hl in pairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, row_idx, 0, {
      end_col = #lines[row_idx + 1],
      hl_group = hl,
    })
  end
  for _, mark in ipairs(key_marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, mark.row, mark.start_col, {
      end_col = mark.end_col,
      hl_group = mark.hl,
    })
  end

  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "cheatsheet"
  -- 跟 picker 一套色：灰边框 + 蓝标题 + 实底卡片。
  -- ⚠ winhl 不是 nvim_open_win 的合法字段（会报 invalid key: winhl），必须开完窗再设。
  vim.wo[win].winhl = "NormalFloat:CheatSheetBg,FloatBorder:CheatSheetBorder,FloatTitle:CheatSheetWinTitle"
  vim.wo[win].cursorline = false -- 纯展示面板：开着只会在顶行糊一条底色带
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
end

return M
