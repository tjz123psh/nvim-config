-- ============================================
-- Spring Boot 项目向导
-- ============================================
-- 为什么不用 springboot-nvim 自带的 :SpringBootNewProject：
--   它在 Spring Boot 4 上必然生成无法构建的工程。它把 start.spring.io 的
--   bootVersion id（形如 4.1.1.RELEASE）原样传给 spring init --boot-version，
--   pom 的 parent 就写成 4.1.1.RELEASE，而仓库里只有 4.1.1
--   （实测 4.1.1.RELEASE → 404，4.1.1 → 200，阿里云与 central 一致）。
--   且它校验输入必须落在那份 id 列表内，所以在向导里怎么选都是坏 pom。
--   本文件：展示可读版本，传给 spring init 时去掉 .RELEASE。
--
-- 放在 core/ 而非 plugins/ 下：core/lazy.lua 是 { import = "plugins" }，
-- lazy 会把 plugins/ 下每个 .lua 当 spec 递归加载，本模块返回的不是 spec。
-- ============================================

local M = {}

-- 本机 LuaJIT 编译时未启用 compat52，table.unpack 是 nil（实测），
-- 所以统一走这个回退，别再用 table.unpack。
local unpack = table.unpack or unpack
local meta_cache = nil

------------------------------------------------------------------
-- 元数据
------------------------------------------------------------------
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

local function normalize_boot(id)
  return (id:gsub("%.RELEASE$", ""))
end

local function is_prerelease(id)
  return id:match("SNAPSHOT") ~= nil or id:match("%.M%d+$") ~= nil or id:match("%.RC%d+$") ~= nil
end

local function vcmp(a, b)
  local pa, pb = {}, {}
  for x in a:gmatch("%d+") do
    pa[#pa + 1] = tonumber(x)
  end
  for x in b:gmatch("%d+") do
    pb[#pb + 1] = tonumber(x)
  end
  for i = 1, math.max(#pa, #pb) do
    local diff = (pa[i] or 0) - (pb[i] or 0)
    if diff ~= 0 then
      return diff
    end
  end
  return 0
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
        label = pre and (real .. "  · 预发布") or (real .. "  · 正式版"),
      }
    end
  end
  table.sort(out, function(a, b)
    if a.pre ~= b.pre then
      return not a.pre
    end
    return vcmp(a.real, b.real) > 0
  end)
  if #out > 0 and not out[1].pre then
    out[1].label = out[1].real .. "  · 正式版 最新"
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

-- start.spring.io 的依赖树本来就是两层：分组 → 依赖（实测 23 组 / 204 项，
-- 且 204 项全部带 description）。之前这里递归拍平，把组名和 description 丢了，
-- 列表既没法分组也没法做预览窗格。现在两样都保留。
-- 组名太长会被列宽截成 "VMware Tanzu Sp~" 这种，给几个啰嗦的起短名
local GROUP_SHORT = {
  ['VMware Tanzu Spring Enterprise Extensions'] = 'Tanzu Enterprise',
  ['VMware Tanzu Application Service'] = 'Tanzu AppService',
  ['VMware Tanzu Spring SDK'] = 'Tanzu SDK',
  ['Spring Cloud Circuit Breaker'] = 'Cloud Breaker',
  ['Spring Cloud Discovery'] = 'Cloud Discovery',
  ['Spring Cloud Config'] = 'Cloud Config',
  ['Spring Cloud Messaging'] = 'Cloud Messaging',
  ['Spring Cloud'] = 'Cloud',
  ['Developer Tools'] = 'Dev Tools',
  ['Template Engines'] = 'Templates',
}

local function short_group(name)
  return GROUP_SHORT[name] or name
end

local function dependency_options(meta)
  local out, seen = {}, {}

  local function try_add(node, group)
    if type(node) ~= "table" then
      return
    end
    -- 分组节点只有 name 没有 id，所以这个判断只会收进真正的依赖
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
    if type(node) ~= "table" then
      return
    end
    local g = group
    if type(node.name) == "string" and type(node.values) == "table" then
      g = node.name -- 这是一个分组节点，它的 name 就是组名
    end
    try_add(node, group)
    for _, v in pairs(node) do
      if type(v) == "table" then
        walk(v, g)
      end
    end
  end

  walk(meta.dependencies, nil)
  -- 先按组、组内按 id，视觉上天然聚在一起
  table.sort(out, function(a, b)
    if a.group ~= b.group then
      return a.group < b.group
    end
    return a.id < b.id
  end)
  return out
end

------------------------------------------------------------------
-- 把回调式 vim.ui.* 写成顺序代码（dressing 同步/异步回调都要接住）
------------------------------------------------------------------
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
  -- 回调可能在 yield 之前就同步触发（dressing 的 select/input 都会），
  -- 此时必须直接返回。若仍先 yield，就再没有人 resume，整个流程永久卡死。
  if arrived then
    return unpack(data)
  end
  local ret = { coroutine.yield() }
  return unpack(ret)
end

local function choose(items, prompt, format)
  return bridge(function(done)
    vim.ui.select(items, { prompt = prompt, format_item = format }, function(choice)
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

local function sanitize_package(s)
  local out = (s:gsub("[^%w%.]", "_"))
  out = out:gsub("^%d", "_")
  return out
end

------------------------------------------------------------------
-- 依赖多选：优先 telescope（可搜索 + <Tab> 多选），降级为逐个 select
------------------------------------------------------------------
-- 按显示宽度截断（这几个字段都是 ASCII，用字节长度即可）
local function cut(text, width)
  text = text or ""
  if #text <= width then
    return text .. string.rep(" ", width - #text)
  end
  if width <= 1 then
    return string.sub(text, 1, width)
  end
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
  if cur ~= "" then
    lines[#lines + 1] = cur
  end
  if #lines == 0 then
    lines[1] = ""
  end
  return lines
end

local function pick_deps(all_deps)
  local ok, pickers = pcall(require, "telescope.pickers")
  local okf, finders = pcall(require, "telescope.finders")
  local okc, conf = pcall(require, "telescope.config")
  local oka, actions = pcall(require, "telescope.actions")
  local oks, state = pcall(require, "telescope.actions.state")
  local okp, previewers = pcall(require, "telescope.previewers")
  local okd, entry_display = pcall(require, "telescope.pickers.entry_display")

  if not (ok and okf and okc and oka and oks and okp and okd) then
    local picked = {}
    while true do
      local menu = { { id = "__done__", name = "完成（已选 " .. #picked .. " 项）" } }
      for _, d in ipairs(all_deps) do
        local taken = false
        for _, id in ipairs(picked) do
          if id == d.id then
            taken = true
          end
        end
        if not taken then
          menu[#menu + 1] = d
        end
      end
      local c = choose(menu, "加入依赖（可搜索）", function(d)
        if d.id == "__done__" then
          return d.name
        end
        return string.format("%-18s %-26s %s", cut(d.group, 18), cut(d.id, 26), d.name or "")
      end)
      if not c or c.id == "__done__" then
        return picked
      end
      picked[#picked + 1] = c.id
    end
  end

  return bridge(function(done)
    local finished = false
    local function once(v)
      if finished then
        return
      end
      finished = true
      done(v)
    end
    -- 列宽自适应：原先写死 %-22s，而实测最长 id 有 42 字符
    -- （spring-ai-chat-memory-repository-in-memory），会直接把名称列顶歪
    local w_id = 0
    for _, d in ipairs(all_deps) do
      w_id = math.max(w_id, #(d.id or ""))
    end
    w_id = math.min(w_id, 44)
    local w_group = 18
    -- entry_display.create{ items = ... } 生成列生成器，调用时传「表的表」
    -- （{ 字符串, 高亮组 }），不是可变参数。
    --
    -- 三列全部用 remaining 而不是 width：带 width 的列会在 entry_maker 阶段去
    -- 查 status.layout.results.winid 来算宽度，而那时窗口布局还没建好，
    -- 实测报 entry_display.lua:76 attempt to index field layout (a nil value)。
    -- 对齐本来就由上面的 cut() 用空格补齐完成，所以这里只需要高亮。
    local disp = entry_display.create({
      separator = " ",
      items = {
        { remaining = true },
        { remaining = true },
        { remaining = true },
      },
    })

    local dep_preview = previewers.new_buffer_previewer({
      title = " 依赖说明 ",
      dynamic_preview_title = true,
      define_preview = function(self, entry)
        local d = entry.__dep or {}
        local lines = {
          "分组   " .. (d.group or "-"),
          "id     " .. (d.id or "-"),
          "名称   " .. (d.name or "-"),
          "",
        }
        for _, l in ipairs(wrap_text(d.description, 44)) do
          lines[#lines + 1] = l
        end
        vim.api.nvim_buf_set_lines(self.previewbufnr, 0, -1, false, lines)
      end,
    })

    pickers.new({}, {
      prompt_title = "⑥ 依赖　分组 │ id │ 名称　　<Tab> 加入　<CR> 完成",
      finder = finders.new_table({
        results = all_deps,
        entry_maker = function(d)
          return {
            value = d.id,
            __dep = d,
            display = disp({ { cut(d.group, w_group), "Directory" }, { d.id, "Function" }, { d.name, "Normal" } }),
            -- ordinal 里带上组名，于是打 sql / ai / messaging 就能按组过滤
            ordinal = (d.group or "") .. " " .. d.id .. " " .. (d.name or ""),
          }
        end,
      }),
      sorter = conf.values.generic_sorter({}),
      previewer = dep_preview,
      -- 预览窗格宽度：horizontal 策略下合法的键是 preview_width，
      -- 写成 layout_config.previewer 会被 telescope 直接拒绝（实测报 Unsupported key）
      layout_config = { horizontal = { preview_width = 0.42 } },
      attach_mappings = function(pb, map)
        -- 只用 map() 注册到本 picker，绝不碰 actions.xxx:replace()。
        -- 两个原因（都是这次真机踩出来的）：
        --  a) :replace 改的是 telescope 全局 actions 表，会永久泄漏给
        --     其它所有 picker（:Telescope files 等）。
        --  b) 在 close 的替换体里再调 actions.close 就是自己调自己，
        --     按两次 Esc 立刻 stack overflow；而 once 守卫被它先置位，
        --     导致之后按 Enter 静默无反应。
        map("i", "<Tab>", actions.toggle_selection)
        map("n", "<Tab>", actions.toggle_selection)
        local function finish_selected()
          local picks = state.get_multiple_selected()
          if #picks == 0 then
            local one = state.get_selected_entry()
            if one then
              picks = { one }
            end
          end
          local got = {}
          for _, e in ipairs(picks) do
            got[#got + 1] = e.value
          end
          actions.close(pb)
          once(got)
        end
        local function finish_cancel()
          actions.close(pb)
          once(nil)
        end
        map("i", "<CR>", finish_selected)
        map("n", "<CR>", finish_selected)
        map("i", "<Esc>", finish_cancel)
        map("n", "<Esc>", finish_cancel)
        map("i", "<C-c>", finish_cancel)
        return true
      end,
    }):find()
  end)
end

------------------------------------------------------------------
-- 向导主流程（字段顺序对齐 IDEA 的 New Project 对话框）
------------------------------------------------------------------
-- 本机这个 Neovim 没有 vim.fs.walk / vim.fs.glob（实测均为 nil），
-- 用 globpath 的 ** 递归即可，返回值就是排序好的绝对路径列表。
local function find_main_class(dir)
  local pats = { "src/main/java/**/*Application.java", "src/main/java/**/*.java" }
  for _, pat in ipairs(pats) do
    local found = vim.fn.globpath(dir, pat, true, true)
    if found[1] then
      return found[1]
    end
  end
  return nil
end

local function cancel()
  vim.notify("已取消，未改动任何文件", vim.log.levels.INFO)
end

local function flow()
  local meta, err = load_meta()
  if not meta then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local build = choose({ { id = "maven" }, { id = "gradle" } }, "① 构建工具", function(o)
    return o.id == "maven" and "maven  · pom.xml" or "gradle · build.gradle.kts"
  end)
  if not build then
    return cancel()
  end

  local langs = simple_options(meta.language)
  if #langs == 0 then
    langs = { { id = "java" } }
  end
  local lang = choose(langs, "② 语言", function(o)
    return o.id
  end)
  if not lang then
    return cancel()
  end

  local jvers = simple_options(meta.javaVersion)
  table.sort(jvers, function(a, b)
    return vcmp(a.id, b.id) > 0
  end)
  local jv = choose(jvers, "③ Java 版本　本机 JDK 26，jdtls 要求 17+", function(o)
    if o.id == "21" then
      return o.id .. "  · LTS 推荐"
    end
    return o.id
  end)
  if not jv then
    return cancel()
  end

  local bv = choose(boot_options(meta), "④ Spring Boot 版本", function(o)
    return o.label
  end)
  if not bv then
    return cancel()
  end

  local packs = simple_options(meta.packaging)
  if #packs == 0 then
    packs = { { id = "jar" } }
  end
  local pkg = choose(packs, "⑤ 打包方式　jar 内嵌 Tomcat 可执行；war 交外部容器", function(o)
    if o.id == "jar" then
      return "jar   · 推荐"
    end
    return "war"
  end)
  if not pkg then
    return cancel()
  end

  local deps = pick_deps(dependency_options(meta))
  if not deps then
    return cancel()
  end

  local group = ask("⑦ Group ID（组织反写域名）: ", "com.example")
  if not group or group == "" then
    return cancel()
  end
  local artifact = ask("⑧ Artifact ID（小写，建议无连字符）: ", "demo")
  if not artifact or artifact == "" then
    return cancel()
  end
  local name = ask("⑨ 项目名 / 目录名: ", artifact)
  if not name or name == "" then
    return cancel()
  end
  local pkgname = ask("⑩ 包名: ", sanitize_package(group .. "." .. artifact))
  if not pkgname or pkgname == "" then
    return cancel()
  end
  local parent = ask("⑪ 创建到哪个目录下: ", vim.fn.getcwd())
  if not parent or parent == "" then
    return cancel()
  end
  if vim.uv.fs_stat(parent) == nil then
    vim.notify("目录不存在：" .. parent, vim.log.levels.ERROR)
    return
  end

  local argv = {
    "spring", "init",
    "--build=" .. build.id,
    "--language=" .. lang.id,
    "--java-version=" .. jv.id,
    "--boot-version=" .. bv.real,
    "--packaging=" .. pkg.id,
    "--group-id=" .. group,
    "--artifact-id=" .. artifact,
    "--name=" .. name,
    "--package-name=" .. pkgname,
  }
  if #deps > 0 then
    argv[#argv + 1] = "--dependencies=" .. table.concat(deps, ",")
  end
  argv[#argv + 1] = name

  local preview = table.concat(argv, " ") .. "  [目标目录: " .. parent .. "]";
  local go = choose({ { id = "go" }, { id = "no" } }, preview, function(o)
    if o.id == "go" then
      return "确认创建"
    end
    return "取消（不改动任何文件）"
  end)
  if not go or go.id ~= "go" then
    return cancel()
  end

  local oksys, res = pcall(function()
    return vim.system(argv, { cwd = parent, text = true }):wait()
  end)
  if not oksys then
    vim.notify("执行失败：找不到 spring 命令（应位于 ~/.local/bin/spring）", vim.log.levels.ERROR)
    return
  end
  if res.code ~= 0 then
    vim.notify("创建失败：" .. tostring(res.stderr or ""), vim.log.levels.ERROR)
    return
  end

  local dir = parent .. "/" .. name
  vim.fn.chdir(dir)
  local main = find_main_class(dir)
  if main then
    vim.cmd("edit " .. vim.fn.fnameescape(main))
  end
  vim.notify("已创建 " .. dir .. "　jdtls 正在导入依赖（首次 10~60 秒），稍后用 :LspInfo 确认", vim.log.levels.INFO)
end

function M.create()
  local ok, err = coroutine.resume(coroutine.create(flow))
  if not ok then
    vim.notify("向导内部错误：" .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.setup()
  if vim.fn.exists(":SpringBootCreate") == 2 then
    return
  end
  vim.api.nvim_create_user_command("SpringBootCreate", function()
    M.create()
  end, { desc = "Spring Boot 项目向导（可搜索选择；已修正 Boot 4 版本号 bug）" })
end

return M

