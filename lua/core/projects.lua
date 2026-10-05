-- ============================================
-- 项目历史与项目选择器
-- 历史只追加、不截断；project.nvim 的写守卫仍在 plugins/project.lua。
-- ============================================

local M = {}

-- 三层保护：只追加副本、三个来源取并集、缺失条目追加回填。
-- 不给插件的 recent_projects 赋值，也不以写模式重建历史文件。
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

  -- 内部按旧→新排列；后来的重复项目移到末尾，展示时再翻转。
  local function put(dir)
    if seen[dir] then
      for i, d in ipairs(dirs) do
        if d == dir then
          table.remove(dirs, i)
          break
        end
      end
    end
    seen[dir] = true
    dirs[#dirs + 1] = dir
  end

  -- ① 我们自己的副本先来（它排在最"老"的一端；插件文件被清空后列表也不会变短）
  local own, own_seen = read_own_history()
  for _, dir in ipairs(own) do
    put(dir)
  end

  -- ② 插件自己的历史文件（顺序=旧→新；调用方翻转后就是"最近在前"）
  if ok_path then
    for _, line in ipairs(read_lines(path.historyfile)) do
      local dir = normalize_dir(vim.trim(line))
      if dir ~= "" and vim.uv.fs_stat(dir) then
        put(dir)
      end
    end
  end

  -- ③ 本会话访问过的项目（插件内存列表，只读）
  local ok_history, history = pcall(require, "project_nvim.utils.history")
  if ok_history and type(history.session_projects) == "table" then
    for _, dir in ipairs(history.session_projects) do
      local normalized = normalize_dir(dir)
      if normalized ~= "" then
        put(normalized)
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

-- 只有含项目标记的目录才自动记入历史，避免把普通 :cd 目录也当项目。
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

function M.setup()
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

      -- 用 Lua API 刷新文件树，不拼接 Neotree 命令，兼容含空格的路径。
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

    -- project_dir 保存路径；不能用 dir，因为 Snacks 会把它改写成布尔标记。
    -- 过滤使用 text（名字 + 完整路径），显示使用富文本行（图标、名字、父目录）。
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

    -- 按最长一行计算宽度，并为边框预留空间。
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
      -- 独立源名避免触发 Snacks 内置 projects finder，覆盖我们传入的 items。
      source = "project-history",
      title = " 项目 ",
      items = items,
      -- 文件名用亮色、父目录用灰色；当前项目另加徽标。
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
          -- 保持列表与父框同宽，避免选中行旁边留下不同底色的竖条。
        },
      },
      -- 兼容单项和选中项数组两种回调形态。
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
end

return M
