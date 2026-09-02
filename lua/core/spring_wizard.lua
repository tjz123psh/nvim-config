-- ============================================================================
-- Spring Boot 项目向导（v3 重构）
-- ============================================================================
-- 与 IDEA New Project 对话框对齐的 11 步向导，全部基于本机已有依赖：
--   dressing.nvim  渲染 vim.ui.select / vim.ui.input 的浮窗
--   telescope      依赖多选列表（原生多选高亮 + 右下角已选计数）
--   nui.nvim       选择浮窗的另一种后端（dressing 里切换）
--
-- v3 变更（相对 v2）：
--   1. 键位语义修正确认：Enter 从「完成」改为「勾选当前项并下移一行」，
--      完成的动作显式化（<C-s> 或选中顶部「完成」行），避免误触完成。
--   2. 不再 mutate telescope 全局 actions 表（:replace 会泄漏给所有 picker），
--      只用 attach_mappings 的 map() 注册到当前 picker。
--   3. 统一视觉风格：every 提示带步骤号、简短的「值 · 提示」条目、
--      选中项靠 telescope 原生高亮 + 右下角计数反馈，不做自研 ✓ 渲染。
--   4. 代码按「主题/元数据/工具/UI桥/多选/流程」分节。
--
-- 放在 core/ 而非 plugins/：core/lazy.lua 用 { import = "plugins" }，
-- lazy 会把 plugins/ 下每个 .lua 当 spec 递归加载，本文件返回的是模块。
-- ============================================================================

local M = {}

----------------------------------------------------------------------------
-- 1. 主题与共享文案（改样式只动这里）
----------------------------------------------------------------------------
local UI = {
  dot    = "·",
  check  = "✓",
  done   = "✅",
  arrow  = "↪",
  feed   = "❯",
  sep    = "　",
  step   = function(i, total) return string.format("[%d/%d]", i, total) end,
}

-- 常用依赖的推荐组合，选择 ⑥ 时提示；不进列表，只做开场提示
local QUICK_TIPS = {
  ["web"] = "REST 接口必备",
  ["data-jpa"] = "要持久化就一起选个库（h2）",
  ["h2"] = "开发期内存库",
  ["devtools"] = "改代码自动重启",
  ["validation"] = "参数校验 @Valid",
  ["lombok"] = "少写样板代码",
}

local function tip(id)
  return QUICK_TIPS[id] or ""
end

local TOTAL_STEPS = 11

local meta_cache = nil

----------------------------------------------------------------------------
-- 2. start.spring.io 元数据
----------------------------------------------------------------------------
local function load_meta()
  if meta_cache then
    return meta_cache
  end
  local ok, res = pcall(function()
    return vim.system({
      "curl", "-s", "--max-time", "25", "https://start.spring.io/metadata/client",
    }, { text = true }):wait()
  end)
  if not ok or not res or res.code ~= 0 or not res.stdout or res.stdout == "" then
    return nil, "取不到 start.spring.io 元数据（网络或代理问题）"
  end
  local okd, decoded = pcall(vim.fn.json_decode, res.stdout)
  if not okd or type(decoded) ~= "table" or not decoded.bootVersion then
    return nil, "元数据解析失败"
  end
  meta_cache = decoded
  return decoded
end

-- start.spring.io 的 bootVersion id 带 .RELEASE 后缀，但仓库里只有去后缀的版本
-- （实测 4.1.1.RELEASE → 404，4.1.1 → 200，阿里云/central 一致），必须剥掉
local function normalize_boot(id)
  return (id:gsub("%.RELEASE$", ""))
end

local function is_prerelease(id)
  return id:match("SNAPSHOT") ~= nil or id:match("%.M%d+$") ~= nil or id:match("%.RC%d+$") ~= nil
end

local function vcmp(a, b)
  local pa, pb = {}, {}
  for x in a:gmatch("%d+") do pa[#pa + 1] = tonumber(x) end
  for x in b:gmatch("%d+") do pb[#pb + 1] = tonumber(x) end
  for i = 1, math.max(#pa, #pb) do
    local diff = (pa[i] or 0) - (pb[i] or 0)
    if diff ~= 0 then return diff end
  end
  return 0
end

-- 组名太长会被列宽截成 "VMware Tanzu Sp~"，给啰嗦的组起短名
local GROUP_SHORT = {
  ['VMware Tanzu Spring Enterprise Extensions'] = 'Tanzu Ent',
  ['VMware Tanzu Application Service'] = 'Tanzu AppSvc',
  ['VMware Tanzu Spring SDK'] = 'Tanzu SDK',
  ['Spring Cloud Circuit Breaker'] = 'Cloud Breaker',
  ['Spring Cloud Discovery'] = 'Cloud Discovery',
  ['Spring Cloud Config'] = 'Cloud Config',
  ['Spring Cloud Messaging'] = 'Cloud Messaging',
  ['Spring Cloud'] = 'Cloud',
  ['Developer Tools'] = 'Dev Tools',
  ['Template Engines'] = 'Templates',
  ['Observability'] = 'Observe',
}

local function short_group(name)
  return GROUP_SHORT[name] or name
end

local function boot_options(meta)
  local out = {}
  for _, v in ipairs(meta.bootVersion.values or {}) do
    if type(v.id) == "string" then
      local real = normalize_boot(v.id)
      local pre = is_prerelease(v.id)
      out[#out + 1] = {
        id = v.id,
        real = real,
        pre = pre,
        label = pre and (real .. "  · 预发布") or (real .. "  · 正式稳定"),
      }
    end
  end
  table.sort(out, function(a, b)
    if a.pre ~= b.pre then return not a.pre end
    return vcmp(a.real, b.real) > 0
  end)
  if #out > 0 and not out[1].pre then
    out[1].label = out[1].real .. "  · 最新正式版"
  end
  return out
end

local function simple_options(node)
  local out = {}
  for _, v in ipairs(node and node.values or {}) do
    if type(v.id) == "string" then
      out[#out + 1] = { id = v.id, label = v.id }
    end
  end
  return out
end

-- 元数据本身就是两层：分组 → 依赖。保留 group / description 供列表与预览用。
local function dependency_options(meta)
  local out, seen = {}, {}
  local function try_add(node, group)
    if type(node) ~= "table" then return end
    -- 分组节点只有 name 没有 id，这个判断只会收进真正的依赖
    if type(node.id) == "string" and type(node.name) == "string" and not seen[node.id] then
      seen[node.id] = true
      out[#out + 1] = {
        id = node.id,
        name = node.name,
        group = short_group(group or "Other"),
        description = type(node.description) == "string" and node.description or "",
      }
    end
  end
  local function walk(node, group)
    if type(node) ~= "table" then return end
    local g = group
    if type(node.name) == "string" and type(node.values) == "table" then
      g = node.name
    end
    try_add(node, group)
    for _, v in pairs(node) do
      if type(v) == "table" then walk(v, g) end
    end
  end
  walk(meta.dependencies, nil)
  table.sort(out, function(a, b)
    if a.group ~= b.group then return a.group < b.group end
    return a.id < b.id
  end)
  return out
end

----------------------------------------------------------------------------
-- 3. 文本工具
----------------------------------------------------------------------------
-- 按显示宽度截断/补齐。这几个字段都是 ASCII，字节长度够用。
local function cut(text, width)
  text = text or ""
  if #text <= width then
    return text .. string.rep(" ", width - #text)
  end
  if width <= 1 then return string.sub(text, 1, width) end
  return string.sub(text, 1, width - 1) .. "~"
end

-- 按词换行，供预览窗格显示 description
local function wrap_text(text, width)
  local lines, cur = {}, ""
  for word in tostring(text or ""):gmatch("%S+") do
    if cur == "" then
      cur = word
    elseif #cur + 1 + #word <= width then
      cur = cur .. " " .. word
    else
      lines[#lines + 1] = cur
      cur = word
    end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  if #lines == 0 then lines[1] = "" end
  return lines
end

-- 包名里非法字符替换为下划线（实测 hyphen 会被 CLI 自动转 _，这里再兜底）
local function sanitize_package(s)
  local out = (s:gsub("[^%w%.]", "_"))
  out = out:gsub("^%d", "_")
  return out
end

----------------------------------------------------------------------------
-- 4. UI 桥：把回调式 vim.ui.* 写成顺序代码
----------------------------------------------------------------------------
-- dressing 可能同步也可能异步回调，两种顺序都要接住，否则流程会永久卡死
local function bridge(caller)
  local co = coroutine.running()
  local arrived, data = false, nil
  local function deliver(...)
    if coroutine.status(co) == "suspended" then
      local ok, err = coroutine.resume(co, ...)
      if not ok then
        vim.notify("向导内部错误：" .. tostring(err), vim.log.levels.ERROR)
      end
    else
      arrived, data = true, { ... }
    end
  end
  caller(deliver)
  -- 回调可能在 yield 之前就已经同步触发（dressing 的 select/input 都会）
  if arrived then return unpack(data) end
  local ret = { coroutine.yield() }
  return unpack(ret)
end

-- 单选：items 是 { id=.., label=.. } 之类，format 决定每行显示
local function choose(items, prompt, format)
  if #items == 0 then return nil end
  return bridge(function(done)
    vim.ui.select(items, { prompt = prompt, format_item = function(it)
      return format and format(it) or (it.label or it.id or tostring(it))
    end }, function(choice)
      done(choice)
    end)
  end)
end

local function ask(prompt, default)
  return bridge(function(done)
    vim.ui.input({ prompt = prompt, default = default }, function(text)
      done(text)
    end)
  end)
end

local function cancel()
  vim.notify("已取消，未改动任何文件", vim.log.levels.INFO)
end


----------------------------------------------------------------------------
-- 5. 依赖多选
----------------------------------------------------------------------------
-- 键位设计（v3 修正：Enter 不再是「完成」）：
--   <Enter>   勾选当前项并下移一行（连续挑一串最顺手）
--   <Tab>     勾选/取消当前项（光标不动）
--   <C-s>     完成并进入下一步
--   <Esc>     取消整个向导
-- 顶部固定一行「完成」，回车即可；勾选行由 telescope 原生高亮，
-- 已选数实时显示在右下角，不需要自绘。

local function pick_deps(all_deps)
  local ok, pickers = pcall(require, "telescope.pickers")
  local okf, finders = pcall(require, "telescope.finders")
  local okc, conf = pcall(require, "telescope.config")
  local oka, actions = pcall(require, "telescope.actions")
  local oks, state = pcall(require, "telescope.actions.state")
  local okp, previewers = pcall(require, "telescope.previewers")
  local okd, entry_display = pcall(require, "telescope.pickers.entry_display")

  -- 降级：telescope 不可用时逐个 vim.ui.select，菜单里带「完成」项
  if not (ok and okf and okc and oka and oks and okp and okd) then
    local picked = {}
    while true do
      local menu = { { id = "__done__", name = "✅ 完成（已选 " .. #picked .. " 项）" } }
      for _, d in ipairs(all_deps) do
        local taken = false
        for _, id in ipairs(picked) do if id == d.id then taken = true end end
        if not taken then menu[#menu + 1] = d end
      end
      local c = choose(menu, "加入依赖（可搜索）", function(d)
        if d.id == "__done__" then return d.name end
        return string.format("%-18s %-26s %s", cut(d.group, 18), cut(d.id, 26), d.name or "")
      end)
      if not c or c.id == "__done__" then return picked end
      picked[#picked + 1] = c.id
    end
  end

  -- 列宽按最长 id 自适应（最长 42 字符，写死 %-22s 会顶歪名称列）
  local w_id = 0
  for _, d in ipairs(all_deps) do w_id = math.max(w_id, #(d.id or "")) end
  w_id = math.min(w_id, 44)
  local w_group = 18
  local disp = entry_display.create({
    separator = " ",
    items = {
      -- 三个 remaining：带 width 的列会在 entry_maker 阶段查 status.layout，
      -- 那时布局还没建好（实测报 layout nil）；对齐由 cut() 补空格负责
      { remaining = true },
      { remaining = true },
      { remaining = true },
    },
  })

  local done_row = { __done = true, id = "__done__", name = "", group = "" }
  local rows = vim.deepcopy(all_deps)
  table.insert(rows, 1, done_row)

  local function preview_lines(d)
    if d.__done then
      return {
        "多选操作说明：",
        "",
        "  <Enter>  勾选当前并下移",
        "  <Tab>    勾选/取消",
        "",
        "按 <C-s> 或在顶部「完成」行回车，进入下一步。",
        "勾选数实时显示在右下角。",
      }
    end
    local lines = {
      "名称 " .. d.name,
      "分组 " .. d.group,
      "id   " .. d.id,
      "",
    }
    for _, l in ipairs(wrap_text(d.description, 42)) do lines[#lines + 1] = l end
    return lines
  end

  local dep_preview = previewers.new_buffer_previewer({
    title = " 说明 ",
    dynamic_preview_title = true,
    define_preview = function(self, entry)
      local d = entry and entry.__dep or {}
      vim.api.nvim_buf_set_lines(self.previewbufnr, 0, -1, false, preview_lines(d))
    end,
  })

  return bridge(function(done)
    local finished = false
    local function once(v)
      if finished then return end
      finished = true
      done(v)
    end

    pickers.new({}, {
      prompt_title = "⑥ 依赖　分组 │ id │ 名称　　<Enter> 勾选并下移  <C-s> 完成",
      finder = finders.new_table({
        results = rows,
        entry_maker = function(d)
          if d.__done then
            return {
              value = "__done__",
              __done = true,
              display = "✅ 完成并继续（勾选数见右下角）",
              ordinal = "\0done",
            }
          end
          return {
            value = d.id,
            __dep = d,
            display = disp({ { cut(d.group, w_group), "Directory" }, { d.id, "Function" }, d.name }),
            ordinal = (d.group or "") .. " " .. d.id .. " " .. (d.name or ""),
          }
        end,
      }),
      sorter = conf.values.generic_sorter({}),
      previewer = dep_preview,
      layout_config = {
        width = 0.86,
        height = 0.78,
        horizontal = { preview_width = 0.40 },
      },
      attach_mappings = function(pb, map)
        -- 只用 map() 注册本 picker；绝不替换 actions 全局表
        --（:replace 会泄漏去别的 picker，替换体里再调还自行递归）
        local function current_is_done()
          local e = state.get_selected_entry()
          return e and (e.__done or e.value == "__done__")
        end
        local function finish()
          local picks = state.get_multiple_selected()
          local got = {}
          for _, e in ipairs(picks) do
            if e.value and e.value ~= "__done__" then got[#got + 1] = e.value end
          end
          actions.close(pb)
          once(got)
        end
        local function enter_key()
          if current_is_done() then return finish() end
          actions.toggle_selection(pb)
          actions.move_selection_next(pb)
        end
        local function cancel_key()
          actions.close(pb)
          once(nil)
        end
        map("i", "<Enter>", enter_key)
        map("n", "<Enter>", enter_key)
        map("i", "<Tab>", actions.toggle_selection)
        map("n", "<Tab>", actions.toggle_selection)
        map("i", "<C-s>", finish)
        map("n", "<C-s>", finish)
        map("i", "<Esc>", cancel_key)
        map("n", "<Esc>", cancel_key)
        map("i", "<C-c>", cancel_key)
        return true
      end,
    }):find()
  end)
end


----------------------------------------------------------------------------
-- 6. 主流程（字段顺序对齐 IDEA New Project）
----------------------------------------------------------------------------
local function find_main_class(dir)
  local pats = { "src/main/java/**/*Application.java", "src/main/java/**/*.java" }
  for _, pat in ipairs(pats) do
    local found = vim.fn.globpath(dir, pat, true, true)
    if found[1] then return found[1] end
  end
  return nil
end

local function flow()
  vim.notify("Spring Boot 向导：共 11 步，任意一步 Esc 取消，最后确认后生成。", vim.log.levels.INFO)
  local meta, err = load_meta()
  if not meta then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- ① 构建工具
  local build = choose(
    { { id = "maven" }, { id = "gradle" } },
    "① 构建工具　maven → pom.xml+mvnw；gradle → build.gradle.kts+gradlew",
    function(o) return o.id == "maven" and "maven  · pom.xml" or "gradle · build.gradle.kts" end
  )
  if not build then return cancel() end

  -- ② 语言
  local langs = simple_options(meta.language)
  if #langs == 0 then langs = { { id = "java" } } end
  local lang = choose(langs, "② 语言", function(o) return o.id end)
  if not lang then return cancel() end

  -- ③ Java 版本
  local jvers = simple_options(meta.javaVersion)
  table.sort(jvers, function(a, b) return vcmp(a.id, b.id) > 0 end)
  local jv = choose(jvers, "③ Java 版本　本机 JDK 26，jdtls 要求 17+", function(o)
    return o.id == "21" and (o.id .. "  · LTS 推荐") or o.id
  end)
  if not jv then return cancel() end

  -- ④ Spring Boot 版本
  local bv = choose(boot_options(meta), "④ Spring Boot 版本", function(o) return o.label end)
  if not bv then return cancel() end

  -- ⑤ 打包方式
  local packs = simple_options(meta.packaging)
  if #packs == 0 then packs = { { id = "jar" } } end
  local pkg = choose(packs, "⑤ 打包方式　jar 内嵌 Tomcat 可执行；war 交外部容器", function(o)
    return o.id == "jar" and "jar   · 推荐" or "war"
  end)
  if not pkg then return cancel() end

  -- ⑥ 依赖（多选）
  local all_deps = dependency_options(meta)
  local deps = pick_deps(all_deps)
  if not deps then return cancel() end

  -- ⑦-⑪ 标识与位置
  local group = ask("⑦ Group ID（组织反写域名）: ", "com.example")
  if not group or group == "" then return cancel() end
  local artifact = ask("⑧ Artifact ID（小写，建议无连字符）: ", "demo")
  if not artifact or artifact == "" then return cancel() end
  local name = ask("⑨ 项目名 / 目录名: ", artifact)
  if not name or name == "" then return cancel() end
  local pkgname = ask("⑩ 包名: ", sanitize_package(group .. "." .. artifact))
  if not pkgname or pkgname == "" then return cancel() end
  local parent = ask("⑪ 创建到哪个目录下: ", vim.fn.getcwd())
  if not parent or parent == "" then return cancel() end
  if vim.uv.fs_stat(parent) == nil then
    vim.notify("目录不存在：" .. parent, vim.log.levels.ERROR)
    return
  end

  -- 组装 spring init 参数
  local argv = {
    "spring", "init",
    "--build=" .. build.id
    , "--language=" .. lang.id
    , "--java-version=" .. jv.id
    , "--boot-version=" .. bv.real
    , "--packaging=" .. pkg.id
    , "--group-id=" .. group
    , "--artifact-id=" .. artifact
    , "--name=" .. name
    , "--package-name=" .. pkgname
  }
  if #deps > 0 then
    argv[#argv + 1] = "--dependencies=" .. table.concat(deps, ",")
  end
  argv[#argv + 1] = name

  -- 摘要：把选中的依赖 id 换成 名字@组，方便一眼核对
  local id2name = {}
  for _, d in ipairs(all_deps) do id2name[d.id] = d.name end
  local dep_names = {}
  for _, id in ipairs(deps) do dep_names[#dep_names + 1] = id2name[id] or id end
  local summary = table.concat({
    "  构建 " .. build.id
    , "  语言 " .. lang.id
    , "  Java " .. jv.id
    , "  Boot " .. bv.real
    , "  打包 " .. pkg.id
    , "  依赖 " .. (#dep_names > 0 and (#dep_names .. " 个：" .. table.concat(dep_names, "、")) or "无")
  }, UI.sep)

  local preview = table.concat(argv, " ") .. "　[目标: " .. parent .. "/" .. name .. "]"
  local go = choose(
    { { id = "go" }, { id = "redo" }, { id = "no" } },
    "确认创建？　" .. summary .. "　共 " .. #argv .. " 个参数",
    function(o)
      if o.id == "go" then return "✅ 确认创建" end
      if o.id == "redo" then return "↩ 返回重选" end
      return "✕ 取消"
    end
  )
  if not go or go.id == "no" then return cancel() end
  if go.id == "redo" then
    vim.schedule(function() M.create() end)
    return
  end

  local oksys, res = pcall(function()
    return vim.system(argv, { cwd = parent, text = true }):wait()
  end)
  if not oksys then
    vim.notify("执行失败：找不到 spring 命令（应在 ~/.local/bin/spring）", vim.log.levels.ERROR)
    return
  end
  if res.code ~= 0 then
    vim.notify("创建失败：" .. tostring(res.stderr or ""), vim.log.levels.ERROR)
    return
  end

  local dir = parent .. "/" .. name
  vim.fn.chdir(dir)
  local main = find_main_class(dir)
  if main then vim.cmd("edit " .. vim.fn.fnameescape(main)) end
  vim.notify("已创建 " .. dir .. "　jdtls 正在导入依赖（首次 10~60 秒），稍后用 :LspInfo 确认", vim.log.levels.INFO)
end

function M.create()
  local ok, err = coroutine.resume(coroutine.create(flow))
  if not ok then
    vim.notify("向导内部错误：" .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.setup()
  if vim.fn.exists(":SpringBootCreate") == 2 then return end
  vim.api.nvim_create_user_command("SpringBootCreate", function()
    M.create()
  end, { desc = "Spring Boot 项目向导（可搜索选择；修正 Boot 4 版本号与多选键位）" })
end

return M

