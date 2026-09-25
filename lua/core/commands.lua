-- ============================================
-- 自定义命令
-- 用 :命令名 回车即可执行
-- ============================================

-- 重新加载配置 / 打开欢迎页 --------

vim.api.nvim_create_user_command("R", function()
  if vim.bo.filetype ~= "lua" then
    vim.notify(":R 只能在 .lua 文件中使用", vim.log.levels.WARN)
    return
  end
  vim.cmd.luafile(vim.fn.expand("%:p"))
end, { force = true, desc = "重新加载当前 Lua 文件" })

vim.api.nvim_create_user_command("A", function()
  -- 确保 alpha-nvim 已加载，再打开欢迎页
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    pcall(lazy.load, { plugins = { "alpha-nvim" } })
  end

  local ok, err = pcall(vim.cmd, "Alpha")
  if not ok then
    vim.notify("打开欢迎页失败: " .. tostring(err), vim.log.levels.ERROR)
  end
end, { force = true, desc = "打开欢迎页" })

-- LSP 客户端信息查看（0.12 移除了内置版，手动恢复）-----

vim.api.nvim_create_user_command("LspInfo", function()
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    vim.notify("没有活跃的 LSP 客户端", vim.log.levels.INFO)
    return
  end
  local lines = {}
  for _, c in ipairs(clients) do
    table.insert(lines, string.format("%s (%s)", c.name, c.id))
    local root = type(c.config.root_dir) == "string" and c.config.root_dir or "N/A"
    table.insert(lines, "  root: " .. root)
    table.insert(lines, "  filetypes: " .. table.concat(c.config.filetypes or {}, ", "))
    table.insert(lines, "")
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LSP 客户端" })
end, { force = true, desc = "查看 LSP 客户端状态" })

vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd.edit(vim.fn.fnameescape(vim.lsp.log.get_filename()))
end, { force = true, desc = "打开 LSP 日志文件" })

-- Spring Boot 项目向导 --------

-- 命令必须在启动时就存在：springboot-nvim 的 spec 是 ft/keys 懒加载，
-- 只有它的 config 跑过才会有 :SpringBootCreate，导致刚打开 nvim 时
-- 直接输 :SpringBootCreate 报 Not an editor command（而 <leader>sp 一直可用）。
-- 在 core 里主动注册一次，让两种入口都即时可用。
local ok_wiz, err_wiz = pcall(function()
  require("core.spring_wizard").setup()
end)
if not ok_wiz then
  -- 静默吞错的后果是 dressing/向导全部回退主题默认观感且毫无线索
  vim.notify("Spring Boot 向导加载失败：" .. tostring(err_wiz), vim.log.levels.ERROR)
end

-- 项目列表 --------

-- ⚠ 项目历史是**易失数据**，这里做成"只追加 + 并集 + 回填"三层保护。
--
-- 事故记录（2026-09-24 两次，第二次是当天夜里）：
--   project.nvim 的 write_projects_to_history() 在 `recent_projects ~= nil` 时用
--   **mode="w" 截断重写**整个历史文件；而它读文件是**异步**的。只要某个实例在
--   "文件刚被别的实例截断成空、内容还没写回"的窗口里读到空文件，它的 recent_projects
--   就变成**空表**（非 nil）⇒ 退出时按空表截断写回 ⇒ 整份历史被清空。
--   并发跑多个 nvim（我当晚的探针 + 后台任务）就会踩到；单实例日常使用风险低但存在。
--
-- 现在：① 自己维护一份只追加的副本（stdpath("state")/project-history.list）；
--       ② 列表 = 插件文件 ∪ 副本 ∪ 会话项目（并集，永不缩小）；
--       ③ 每次打开列表时把副本里"插件文件缺的条目"**追加**回插件文件（append 不会截断，
--          而且插件的 fs_event 监视器会因此重读文件，把它自己的内存一起修好）。
local function own_history_file()
  return vim.fn.stdpath("state") .. "/project-history.list"
end

local function normalize_dir(dir)
  return (dir:gsub("\\", "/"):gsub("//", "/"))
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or {}
end

local function read_own_history()
  local dirs, seen = {}, {}
  for _, line in ipairs(read_lines(own_history_file())) do
    local dir = normalize_dir(vim.trim(line))
    if dir ~= "" and not seen[dir] and vim.uv.fs_stat(dir) then
      seen[dir] = true
      dirs[#dirs + 1] = dir
    end
  end
  return dirs, seen
end

local function append_history_file(path, dirs, existing)
  existing = existing or {}
  local fresh = {}
  for _, dir in ipairs(dirs) do
    local normalized = normalize_dir(dir)
    if normalized ~= "" and not existing[normalized] and vim.uv.fs_stat(normalized) then
      existing[normalized] = true
      fresh[#fresh + 1] = normalized
    end
  end
  if #fresh == 0 then
    return 0
  end

  local f = io.open(path, "a")
  if not f then
    return 0
  end
  f:write(table.concat(fresh, "\n") .. "\n")
  f:close()
  return #fresh
end

local function read_project_history()
  local ok_path, path = pcall(require, "project_nvim.utils.path")
  local dirs, seen = {}, {}

  -- ① 我们自己的副本先来（它排在最"老"的一端；插件文件被清空后列表也不会变短）
  local own, own_seen = read_own_history()
  for _, dir in ipairs(own) do
    seen[dir] = true
    dirs[#dirs + 1] = dir
  end

  -- ② 插件自己的历史文件（顺序=旧→新；调用方翻转后就是"最近在前"）
  if ok_path then
    for _, line in ipairs(read_lines(path.historyfile)) do
      local dir = normalize_dir(vim.trim(line))
      if dir ~= "" and not seen[dir] and vim.uv.fs_stat(dir) then
        seen[dir] = true
        dirs[#dirs + 1] = dir
      end
    end
  end

  -- ③ 本会话访问过的项目（插件内存列表，只读）
  local ok_history, history = pcall(require, "project_nvim.utils.history")
  if ok_history and type(history.session_projects) == "table" then
    for _, dir in ipairs(history.session_projects) do
      local normalized = normalize_dir(dir)
      if not seen[normalized] then
        seen[normalized] = true
        dirs[#dirs + 1] = normalized
      end
    end
  end

  -- 回填：副本 ← 本轮看到的全部；插件文件 ← 副本里它缺的（append，不截断）
  append_history_file(own_history_file(), dirs, own_seen)
  if ok_path then
    local in_plugin = {}
    for _, line in ipairs(read_lines(path.historyfile)) do
      in_plugin[normalize_dir(vim.trim(line))] = true
    end
    append_history_file(path.historyfile, dirs, in_plugin)
  end

  return dirs
end

-- 项目标志文件：只有"看起来是项目根"的目录才记进历史，
-- 否则 `:cd /tmp`、`:cd ~` 之类也会被塞进 :Projects（2026-09-25 审查指出）。
local PROJECT_MARKERS = {
  ".git",
  ".hg",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "package.json",
  "go.mod",
  "Cargo.toml",
  "pyproject.toml",
  "CMakeLists.txt",
}

local function looks_like_project(dir)
  for _, marker in ipairs(PROJECT_MARKERS) do
    if vim.uv.fs_stat(dir .. "/" .. marker) then
      return true
    end
  end
  return false
end

-- 换到项目根就记一笔（下一次 :Projects 即便插件历史又丢了也还在）
vim.api.nvim_create_autocmd("DirChanged", {
  group = vim.api.nvim_create_augroup("ProjectHistoryMirror", { clear = true }),
  desc = "把当前项目根追加到自有项目历史副本",
  callback = function()
    local cwd = vim.fn.getcwd()
    if not looks_like_project(cwd) then
      return
    end
    local _, seen = read_own_history()
    append_history_file(own_history_file(), { cwd }, seen)
  end,
})

vim.api.nvim_create_user_command("Projects", function()
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    pcall(lazy.load, { plugins = { "project.nvim", "neo-tree.nvim", "snacks.nvim" } })
  end

  local ok_snacks, Snacks = pcall(require, "snacks")
  if not ok_snacks then
    vim.notify("项目列表加载失败（snacks 不可用）", vim.log.levels.ERROR)
    return
  end

  local projects = read_project_history()
  for i = 1, math.floor(#projects / 2) do
    projects[i], projects[#projects - i + 1] = projects[#projects - i + 1], projects[i]
  end

  -- 当前所在项目排到最前（其余保持"最近打开在前"）。cwd 可能是项目子目录 ⇒ 取最长匹配。
  do
    local cwd = vim.fn.getcwd()
    local best, best_len = nil, 0
    for i, dir in ipairs(projects) do
      if (cwd == dir or cwd:sub(1, #dir + 1) == dir .. "/") and #dir > best_len then
        best, best_len = i, #dir
      end
    end
    if best and best > 1 then
      local dir = table.remove(projects, best)
      table.insert(projects, 1, dir)
    end
  end

  if #projects == 0 then
    vim.notify("暂无项目历史", vim.log.levels.INFO)
    return
  end

  local function switch_project(dir)
    if type(dir) ~= "string" or dir == "" then
      vim.notify("项目切换失败：目录参数异常（" .. vim.inspect(dir) .. "）", vim.log.levels.ERROR)
      return
    end

    local ok_project, project = pcall(require, "project_nvim.project")
    if ok_project then
      project.set_pwd(dir, "projects")
    else
      vim.api.nvim_set_current_dir(dir)
    end

    -- neo-tree 的联动由 lua/plugins/project.lua 里对 set_pwd 的补丁负责（走 Lua API
    -- manager.navigate，路径里有空格也稳）。
    -- ⚠ 这里原来还会发 `Neotree filesystem reveal dir=<path>`，但 neo-tree 的命令解析器
    --   是**按空格切分**参数（neo-tree/command/parser.lua 的 utils.split(args, " ")），
    --   所以路径含空格的项目（如 "Feed stream"）必然解析失败报错 ⇒ 已删除该命令。
    if not package.loaded["neo-tree.sources.manager"] then
      return
    end
    vim.schedule(function()
      local ok_manager, manager = pcall(require, "neo-tree.sources.manager")
      if not ok_manager then
        return
      end
      manager._for_each_state("filesystem", function(state)
        if state.path and state.path ~= dir then
          pcall(manager.navigate, state, dir)
        end
      end)
    end)
  end

  -- 原来是自定义 Telescope picker；换成 snacks（fzf 风格紧凑列表），行为保持一致：
  -- 选中后切 cwd + 让 neo-tree 跟随（靠 project.lua 里的 set_pwd 补丁）
  -- ⚠ 不要用 `dir` 作为自定义字段名：snacks 会把 item 当文件项补全自己的元数据，
  --   其中 `dir` 是布尔标志（"是目录"），会**覆盖**我们的字符串（实测拿到 dir=true）。
  --   换一个不会撞名的 key（project_dir），并保留 text→dir 的反查兜底。
  -- 行样式：图标 + 项目名（亮）+ 父目录（暗），名字列对齐；home 缩成 ~。
  -- text 仍是「名字 + 完整路径」——过滤靠它（能按路径片段搜），显示靠下面的 format。
  local home = vim.fn.expand("~")
  local function pretty_path(path)
    if path == home then
      return "~"
    end
    return (path:gsub("^" .. vim.pesc(home) .. "/", "~/"))
  end

  local items = {}
  local by_text = {}
  local name_width = 0
  for _, dir in ipairs(projects) do
    local name = vim.fn.fnamemodify(dir, ":t")
    local parent = pretty_path(vim.fn.fnamemodify(dir, ":h"))
    name_width = math.max(name_width, vim.fn.strdisplaywidth(name))
    local text = name .. "  " .. dir
    items[#items + 1] = {
      text = text,
      project_dir = dir,
      project_name = name,
      project_parent = parent,
    }
    by_text[text] = dir
  end
  name_width = math.min(name_width, 24) -- 名字列上限：够放下常见长名（列对齐），又不至于把路径挤没

  -- 标出「你当前就在这个项目里」的那一条（cwd 可能是项目子目录 ⇒ 取最长匹配）
  do
    local cwd = vim.fn.getcwd()
    local current
    for _, item in ipairs(items) do
      local dir = item.project_dir
      if (cwd == dir or cwd:sub(1, #dir + 1) == dir .. "/") and (not current or #dir > #current) then
        current = dir
      end
    end
    for _, item in ipairs(items) do
      item.project_current = item.project_dir == current
    end
  end

  -- 宽度贴合内容（原先固定 0.5 屏宽 → 宽终端上一半是空白）：按最长一行算，
  -- 夹在 [40, min(96, columns-8)]。内联 layout 能盖过预设（实测 53 → 61）。
  local window_width = (function()
    local widest = 0
    for _, item in ipairs(items) do
      local name = vim.fn.strdisplaywidth(item.project_name or "")
      local parent = vim.fn.strdisplaywidth(item.project_parent or "")
      local badge = item.project_current and 6 or 0 -- "  当前" = 2 空格 + 4 列
      widest = math.max(widest, 2 + math.max(name, name_width) + 2 + parent + badge)
    end
    return math.max(40, math.min(96, widest + 4, vim.o.columns - 8))
  end)()

  Snacks.picker.pick({
    -- ⚠ 不要叫 "projects"：snacks 有**同名的内置源**（sources.lua:888，finder=recent_projects），
    --   传它会走内置 finder、把我们自己的 items 顶掉（实测 confirm 收到的是别的项目条目）
    source = "project-history",
    title = " 项目 ",
    items = items,
    -- 富文本行：图标（主题蓝）+ 名字（亮色，按最长名字对齐）+ 父目录（灰）。
    -- 匹配高亮由 snacks 自己按渲染后的行重算（list.lua 的 M:format），不受影响。
    format = function(item)
      local name = item.project_name or vim.fn.fnamemodify(item.project_dir or "", ":t")
      local icon, icon_hl = Snacks.util.icon(name, "directory", { fallback = { dir = "󰉋 " } })
      local pad = string.rep(" ", math.max(0, name_width - vim.fn.strdisplaywidth(name)))
      local line = {
        { icon, icon_hl },
        { name, item.project_current and "SnacksPickerCurrentProject" or "SnacksPickerFile" },
        { pad .. "  ", "SnacksPickerDelim" },
        { item.project_parent or "", "SnacksPickerDir" },
      }
      if item.project_current then
        line[#line + 1] = { "  当前", "SnacksPickerCurrentBadge" }
      end
      return line
    end,
    layout = {
      preset = "picker_compact",
      backdrop = 60,
      layout = {
        width = window_width,
        -- 注：snacks 的子窗默认与父框**同宽**（实测 list w == box w，内置布局也一样），
        -- 所以选中行底色会正好铺满一行（含边框那一格）。曾试过把 list 收窄 2 列，
        -- 结果右侧多出一条 2 列宽、颜色不一致的竖条 —— 更难看，已回退。
      },
    },
    -- ⚠ snacks 的 confirm 第二个参数在不同形态下是「选中项数组」（前面就是踩了这个：
    --   按单项取 .dir 拿到 nil，最终 nvim_set_current_dir(nil) 报 Invalid 'dir'）
    confirm = function(picker, item)
      picker:close()
      local sel = item
      if type(sel) == "table" and type(sel[1]) == "table" then
        sel = sel[1]
      end
      local dir = type(sel) == "table" and sel.project_dir or nil
      if type(dir) ~= "string" and type(sel) == "table" then
        dir = sel.file or sel._path -- 兜底：snacks 文件项形态
      end
      if type(dir) ~= "string" and type(sel) == "table" and type(sel.text) == "string" then
        dir = by_text[sel.text] -- 兜底：按显示文本反查
      end
      switch_project(dir)
    end,
  })
end, { force = true, desc = "打开项目列表" })

-- Java 项目初始化 / 单文件运行 --------

-- 从当前缓冲区提取 Java package 声明
local function java_package_name()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for _, line in ipairs(lines) do
    local package_name = line:match("^%s*package%s+([%w_.]+)%s*;")
    if package_name then
      return package_name
    end
  end
  return nil
end

-- 根据文件目录和包名推导项目根目录
-- 例如：文件在 src/main/java/com/example/Foo.java，包名 com.example
--   → 文件目录尾部匹配 /com/example → 去掉后缀 → 根目录 = src/main/java
local function java_package_root(file_dir, package_name)
  if not package_name then
    return vim.fs.normalize(file_dir)
  end

  local package_path = package_name:gsub("%.", "/")
  local normalized_dir = vim.fs.normalize(file_dir)
  local suffix = "/" .. package_path

  if normalized_dir:sub(-#suffix) ~= suffix then
    return nil -- 目录结构与包声明不匹配
  end

  local root = normalized_dir:sub(1, #normalized_dir - #suffix)
  return root ~= "" and root or "/"
end

vim.api.nvim_create_user_command("JavaRun", function()
  -- 验证：仅 Java 文件可用，且需要的工具存在
  if vim.bo.filetype ~= "java" then
    vim.notify(":JavaRun 只能在 Java 文件中使用", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("java") ~= 1 then
    vim.notify("找不到 java 命令", vim.log.levels.ERROR)
    return
  end
  if vim.fn.executable("javac") ~= 1 then
    vim.notify("找不到 javac 命令", vim.log.levels.ERROR)
    return
  end
  if vim.fn.executable("bash") ~= 1 then
    vim.notify("找不到 bash 命令", vim.log.levels.ERROR)
    return
  end

  local file = vim.fn.expand("%:p")
  local package_name = java_package_name()

  -- 无 package：直接用 JDK 11+ 的单文件模式运行
  if not package_name then
    vim.cmd("term java " .. vim.fn.shellescape(file))
    return
  end

  -- 有 package：推导根目录，用 javac + java 两步编译运行
  local root = java_package_root(vim.fn.expand("%:p:h"), package_name)
  if not root then
    vim.notify(
      "无法从当前文件路径推导 package 根目录，请确认目录结构与 package 声明一致",
      vim.log.levels.ERROR
    )
    return
  end

  local class_name = vim.fn.expand("%:t:r")
  local main_class = package_name .. "." .. class_name
  local relative_file = vim.fs.relpath(root, file)
  if not relative_file then
    vim.notify("无法计算当前 Java 文件相对 package 根目录的路径", vim.log.levels.ERROR)
    return
  end

  -- 编译到临时目录再运行（支持任何 JDK 版本，不依赖 JDK 11+ 单文件模式）
  local out_dir = vim.fn.tempname()
  local command = table.concat({
    "cd " .. vim.fn.shellescape(root),
    "mkdir -p " .. vim.fn.shellescape(out_dir),
    "javac -d " .. vim.fn.shellescape(out_dir) .. " -sourcepath . " .. vim.fn.shellescape(relative_file),
    "java -cp " .. vim.fn.shellescape(out_dir) .. " " .. main_class,
  }, " && ")

  -- bash -lc 确保 shell 配置（如 PATH）被加载
  vim.cmd("term bash -lc " .. vim.fn.shellescape(command))
end, { force = true, desc = "运行当前 Java 文件（自动处理有/无 package）" })
