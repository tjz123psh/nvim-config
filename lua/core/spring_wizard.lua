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

-- 仅用于最后一列的截断：… 占 3 字节 1 列，telescope 算列位置用的是字节长度，
-- 放在中间列会让后面的分隔线错位，所以只在末列用它。
local function cut_last(text, width)
  text = text or ""
  if #text <= width then return text end
  if width <= 1 then return string.sub(text, 1, width) end
  return string.sub(text, 1, width - 1) .. "\226\128\166"
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
-- 4. UI 桥与视觉主题
-- ----------------------------------------------------------------------------

-- ===== noice 同款粉系主题（catppuccin-mocha v5）=====
-- 设计基准：底 #1E1E2E、边框 #F38BA8、选中 #F5C2E7、徽章 #FAB387。
-- 终端物理限制（没有透明/发光渲染），用深色面板、下划线、字重近似 noice。
-- 边框通过 timer 在粉色阶之间缓慢呼吸；圆角用 ╭╮╰╯ 字符。
-- v5：改用 noice 通知弹框那一套（catppuccin-mocha 粉系），和编辑器主题同族
local NEON = {
  bg      = "#1E1E2E",  -- catppuccin base：noice 弹框同款底
  border  = "#F38BA8",  -- noice 粉
  borderB = "#F5A0B8",
  borderC = "#E893AC",
  sun     = "#F5C2E7",  -- 选中行文字（mauve）
  white   = "#CDD6F4",  -- 主文字（text）
  grey    = "#A6ADC8",  -- 次文字（subtext1）
  dim     = "#585B70",  -- 未选中 □ / 空态（overlay0）
  magenta = "#CBA6F7",  -- 过滤匹配词（lavender）
  amber   = "#FAB387",  -- 分组徽章（peach）
  rowbg   = "#313244",  -- 选中行底（surface0）
}

local HL_DEFS = {
  { "WizBg",        { bg = NEON.bg } },
  { "WizBorder",    { fg = NEON.border } },
  { "WizTitle",     { fg = NEON.border, bold = true } },
  { "WizCursorLine",{ bg = NEON.rowbg, fg = NEON.sun, bold = true, underline = true, sp = NEON.border } },
  { "WizKey",       { fg = NEON.white } },
  { "WizSel",       { fg = NEON.sun, bold = true } },
  { "WizBadge",     { fg = NEON.amber, bold = true } },
  { "WizHint",      { fg = NEON.grey } },
  { "WizDim",       { fg = NEON.dim } },
  { "WizMagenta",   { fg = NEON.magenta, bold = true } },
}

-- snacks 用 default=true 注册的组，这里后注册（无 default）覆盖成霓虹色
local SNACKS_HL = {
  { "SnacksPickerTotals",     { fg = NEON.amber, bold = true } },   -- 204/204 计数器
  { "SnacksPickerPrompt",     { fg = NEON.border, bold = true } },  -- >> 提示符
  { "SnacksPickerMatch",      { fg = NEON.magenta, bold = true } }, -- 过滤匹配词
  { "SnacksPickerSelected",   { fg = NEON.border, bold = true } },  -- ▣ 已选
  { "SnacksPickerUnselected", { fg = NEON.dim } },                  -- □ 未选
  { "SnacksPickerInput",      { fg = NEON.white } },
}

local function define_highlights()
  for _, d in ipairs(HL_DEFS) do
    vim.api.nvim_set_hl(0, d[1], d[2])
  end
  for _, s in ipairs(SNACKS_HL) do
    vim.api.nvim_set_hl(0, s[1], s[2])
  end
end

-- 边框呼吸：WizBorder 在三个粉色之间缓慢过渡（1.2s 一步）
local border_timer = nil
local border_step = 0
local function stop_pulse()
  if border_timer then
    pcall(vim.uv.timer_stop, border_timer)
    pcall(vim.uv.timer_close, border_timer)
    border_timer = nil
  end
  pcall(vim.api.nvim_set_hl, 0, "WizBorder", { fg = NEON.border })
end
local function start_pulse()
  stop_pulse()
  border_step = 0
  border_timer = vim.uv.new_timer()
  border_timer:start(0, 1200, function()
    border_step = border_step + 1
    local c = ({ NEON.border, NEON.borderB, NEON.borderC })[(border_step % 3) + 1]
    vim.schedule(function()
      pcall(vim.api.nvim_set_hl, 0, "WizBorder", { fg = c })
    end)
  end)
end

-- 注意：snacks.picker.win.Config 只接受 input / list / preview 三个键。
-- 塞 backdrop 进去会炸：config/init.lua 的 fix_keys 对 opts.win 做 pairs 遍历
-- 并取 win.keys，backdrop 是数字 → "attempt to index local 'win' (a number value)"。
-- 遮罩效果改由每个窗口自己的 snacks.win.Config.backdrop 提供（那里才合法）。
local function win_config()
  local borderchars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  return {
    input = {
      border = borderchars,
      winhighlight = "Normal:WizBg,FloatBorder:WizBorder,FloatTitle:WizTitle,WinSeparator:WizBorder",
    },
    list = {
      border = borderchars,
      backdrop = 60,  -- 压暗编辑器背景，霓虹卡片浮出来（合法位置：单个窗口内）
      winhighlight = "Normal:WizBg,FloatBorder:WizBorder,FloatTitle:WizTitle,CursorLine:WizCursorLine,Search:None",
    },
    preview = {
      border = borderchars,
      wo = { number = false, relativenumber = false, signcolumn = "no" },
      winhighlight = "Normal:WizBg,FloatBorder:WizBorder,FloatTitle:WizTitle",
    },
  }
end

-- dressing 的回调可能同步也可能异步触发，两种顺序都要接住，否则流程卡死
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
  if arrived then return unpack(data) end
  local ret = { coroutine.yield() }
  return unpack(ret)
end

-- 文本输入仍走 dressing（snacks.input 已关闭，避免抢 noice/dressing 的活）
local function ask(prompt, default)
  return bridge(function(done)
    vim.ui.input({ prompt = prompt, default = default }, function(text) done(text) end)
  end)
end

local function cancel()
  vim.notify("已取消，未改动任何文件", vim.log.levels.INFO)
end

-- 主键亮 + 说明暗：id 亮白、hint 灰，窄列表里像终端命令
local function fmt_hint(item)
  local d = item.item or item
  return {
    { d.id or "", "WizKey" },
    { "   " },
    { d.hint or "", "WizHint" },
  }
end

-- 递归遍历 layout 的所有 box（default 预设里 list 嵌在 vertical box 内部，
-- 只在 layout.layout 一层迭代会漏掉它，高度贴合就白写了）
local function each_box(root, fn)
  local function walk(box)
    if type(box) ~= "table" then return end
    fn(box)
    for _, child in ipairs(box) do walk(child) end
  end
  walk(root)
end

----------------------------------------------------------------------------
-- 5. 单选与多选（snacks.picker）
----------------------------------------------------------------------------
-- 为什么从 dressing+nui / telescope 换成 snacks：
--   1. dressing+nui 只能整行一个颜色，做不出「主键亮 + 说明暗 + 勾选列」
--   2. 你装的这个 nui 版本没有 preview、没有模糊搜索（menu/init.lua 仅 377 行）
--   3. telescope 有原生多选但风格与 nui 割裂，且要手写 borderchars 才勉强像卡片
--   snacks.picker 的 format 返回 Highlight 数组（逐段着色），勾选列与预览都是内置
--   而且 <Tab> 默认就绑了 select_and_next（勾选并下移），正是你要的交互

local function pick_one(items, title, fmt)
  return bridge(function(done)
    local completed = false
    local function finish(choice)
      if completed then return end
      completed = true
      done(choice)
    end
    start_pulse()
    Snacks.picker.pick({
      source = "select",
      title = title,
      layout = {
        preset = "select",
        config = function(layout)
          -- 高度贴合条目数：列表占满条目高度，不再留大片空底
          -- （config 收到的是合并后的完整配置，box 树在 layout.layout 里）
          each_box(layout.layout or layout, function(box)
            if box.win == "list" and not box.height then
              box.height = math.max(math.min(#items + 1, vim.o.lines * 0.8 - 10), 2)
            end
          end)
        end,
      },
      win = win_config(),
      finder = function()
        local ret = {}
        for idx, it in ipairs(items) do
          ret[#ret + 1] = {
            idx = idx,
            item = it,
            text = (it.id or "") .. " " .. (it.hint or ""),
          }
        end
        return ret
      end,
      format = fmt or fmt_hint,
      filter = {},
      actions = {
        confirm = function(picker, pitem)
          -- 必须先置守卫再 close：否则 close 触发的 on_close 会抢先
          -- deliver(nil)，协程带着 nil 恢复，流程误判成「用户取消」
          if completed then return end
          completed = true
          stop_pulse()
          local chosen = pitem and pitem.item
          picker:close()
          vim.schedule(function() done(chosen) end)
        end,
      },
      on_close = function()
        if completed then return end
        completed = true
        stop_pulse()
        vim.schedule(function() done(nil) end)
      end,
    })
  end)
end

-- 依赖多选：Tab 勾选（snacks 默认键位）、Enter 确认
local function pick_deps(all_deps)
  return bridge(function(done)
    local completed = false
    local function finish(v)
      if completed then return end
      completed = true
      done(v)
    end
    start_pulse()

    -- 列宽策略：id 是主键列（亮白），名称列给足空间不截断。
    -- 窗口宽 = 编辑器列数的 62%（上限 112），右下角预览再挤点宽度。
    local list_w = math.min(math.floor(vim.o.columns * 0.62), 112)
    local w_id = 0
    for _, d in ipairs(all_deps) do
      w_id = math.max(w_id, #(d.id or ""))
    end
    w_id = math.max(math.min(w_id, 22), 8)          -- id 列：实际最长 id，封顶 22
    local w_group = math.min(12, 12)                 -- 分组徽章列固定 12
    local w_name = math.max(list_w - w_id - w_group - 16, 16) -- 名称列：剩余全部

    Snacks.picker.pick({
      source = "select",
      title = "6. 选择依赖　Tab 勾选　Enter 完成",
      layout = {
        preset = "default",  -- 列表 + 右侧预览
        config = function(layout)
          -- default 是 horizontal 根布局：只缩 list 不会缩左侧 vertical 外框，
          -- 多余高度就会变成列表下方大片空白。根高度也要一起收紧。
          local list_height = math.max(math.min(#all_deps + 2, 14), 3)
          local root = layout.layout or layout
          root.height = list_height + 1
          each_box(root, function(box)
            if box.win == "list" and not box.height then
              box.height = list_height
            end
            if box.win == "preview" then
              box.width = 0.3
            end
          end)
        end,
      },
      -- win_config 里 backdrop 是压暗编辑器：卡片浮出来
      win = win_config(),
      -- 每行都显示勾选框：沿用 snacks 稳定可见的 ○/● 图标
      formatters = { selected = { show_always = true, unselected = true } },
      finder = function()
        local ret = {}
        for idx, d in ipairs(all_deps) do
          ret[#ret + 1] = {
            idx = idx,
            item = d,
            text = (d.group or "") .. " " .. (d.id or "") .. " " .. (d.name or ""),
          }
        end
        return ret
      end,
      format = function(item, picker)
        local d = item.item or item
        local current = picker and picker.list and picker.list:current()
        local is_cur = current == item
        return {
          { cut(d.id, w_id), is_cur and "WizSel" or "WizKey" },
          { "  " },
          { cut("[" .. (d.group or "") .. "]", w_group), "WizBadge" },
          { "  " },
          { cut_last(d.name, w_name), is_cur and "WizSel" or "WizHint" },
        }
      end,
      preview = function(ctx)
        local d = ctx.item and ctx.item.item
        if not d then return false end
        local lines = {
          "名称   " .. d.name,
          "分组   " .. d.group,
          "id     " .. d.id,
          string.rep("─", 44),
          "",
        }
        for _, l in ipairs(wrap_text(d.description, 44)) do lines[#lines + 1] = l end
        lines[#lines + 1] = ""

        pcall(function() vim.bo[ctx.buf].modifiable = true end)
        pcall(vim.api.nvim_buf_clear_namespace, ctx.buf, -1, 0, -1) -- 旧高亮先清，防止行号错位
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
        -- 霓虹层次：标签琥珀 / 值亮白 / id 青 / 分隔线青
        local function hl(ln, c0, c1, grp)
          pcall(vim.api.nvim_buf_add_highlight, ctx.buf, -1, grp, ln, c0, c1)
        end
        hl(0, 0, 8, "WizBadge"); hl(0, 8, -1, "WizKey")
        hl(1, 0, 8, "WizBadge"); hl(1, 8, -1, "WizBadge")
        hl(2, 0, 8, "WizBadge"); hl(2, 8, -1, "WizTitle")
        hl(3, 0, -1, "WizBorder")
        for i = 5, #lines - 2 do hl(i, 0, -1, "WizHint") end
        return true
      end,
      filter = {},
      actions = {
        confirm = function(picker)
          if completed then return end
          completed = true
          stop_pulse()
          local ids = {}
          for _, it in ipairs(picker.list.selected or {}) do
            if it.item and it.item.id then ids[#ids + 1] = it.item.id end
          end
          picker:close()
          vim.schedule(function() done(ids) end)
        end,
      },
      on_close = function()
        if completed then return end
        completed = true
        stop_pulse()
        vim.schedule(function() done(nil) end)
      end,
    })
  end)
end

----------------------------------------------------------------------------
-- 6. 主流程（字段顺序对齐 IDEA New Project）
----------------------------------------------------------------------------
local function find_main_class(dir)
  for _, pat in ipairs({ "src/main/java/**/*Application.java", "src/main/java/**/*.java" }) do
    local found = vim.fn.globpath(dir, pat, true, true)
    if found[1] then return found[1] end
  end
  return nil
end

local function flow()
  define_highlights()
  local meta, err = load_meta()
  if not meta then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local build = pick_one({
    { id = "maven",  hint = "pom.xml + mvnw" },
    { id = "gradle", hint = "build.gradle.kts + gradlew" },
  }, "1. 构建工具")
  if not build then return cancel() end

  local langs = simple_options(meta.language)
  if #langs == 0 then langs = { { id = "java" } } end
  local lang_items = {}
  for i, l in ipairs(langs) do
    lang_items[i] = { id = l.id, hint = l.id == "java" and "推荐" or "" }
  end
  local lang = pick_one(lang_items, "2. 语言")
  if not lang then return cancel() end

  local jvers = simple_options(meta.javaVersion)
  table.sort(jvers, function(a, b) return vcmp(a.id, b.id) > 0 end)
  local jv_items = {}
  for i, v in ipairs(jvers) do
    local hint = ""
    if v.id == "21" then hint = "LTS，推荐" elseif v.id == "17" then hint = "最低可用" end
    jv_items[i] = { id = v.id, hint = hint }
  end
  local jv = pick_one(jv_items, "3. Java 版本　本机 JDK 26，jdtls 要求 17+")
  if not jv then return cancel() end

  local boots = boot_options(meta)
  local boot_items = {}
  for i, b in ipairs(boots) do
    local hint = "正式版"
    if b.pre then hint = "预发布，可能拉不到" elseif i == 1 then hint = "最新正式版" end
    boot_items[i] = { id = b.real, hint = hint }
  end
  local bv = pick_one(boot_items, "4. Spring Boot 版本")
  if not bv then return cancel() end

  local packs = simple_options(meta.packaging)
  if #packs == 0 then packs = { { id = "jar" } } end
  local pack_items = {}
  for i, v in ipairs(packs) do
    pack_items[i] = {
      id = v.id,
      hint = v.id == "jar" and "可执行 jar，内嵌 Tomcat" or "部署到外部容器",
    }
  end
  local pkg = pick_one(pack_items, "5. 打包方式")
  if not pkg then return cancel() end

  local all_deps = dependency_options(meta)
  local deps = pick_deps(all_deps)
  if not deps then return cancel() end

  local group = ask("7. Group ID（组织反写域名）: ", "com.example")
  if not group or group == "" then return cancel() end
  local artifact = ask("8. Artifact ID（小写，建议无连字符）: ", "demo")
  if not artifact or artifact == "" then return cancel() end
  local name = ask("9. 项目名 / 目录名: ", artifact)
  if not name or name == "" then return cancel() end
  local pkgname = ask("10. 包名: ", sanitize_package(group .. "." .. artifact))
  if not pkgname or pkgname == "" then return cancel() end
  local parent = ask("11. 创建到哪个目录下: ", vim.fn.getcwd())
  if not parent or parent == "" then return cancel() end
  if vim.uv.fs_stat(parent) == nil then
    vim.notify("目录不存在：" .. parent, vim.log.levels.ERROR)
    return
  end

  local argv = {
    "spring", "init",
    "--build=" .. build.id,
    "--language=" .. lang.id,
    "--java-version=" .. jv.id,
    "--boot-version=" .. bv.id,
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

  local id2name = {}
  for _, d in ipairs(all_deps) do id2name[d.id] = d.name end
  local dep_names = {}
  for _, id in ipairs(deps) do dep_names[#dep_names + 1] = id2name[id] or id end

  local summary = table.concat({
    "构建 " .. build.id,
    "Java " .. jv.id,
    "Boot " .. bv.id,
    "打包 " .. pkg.id,
    "依赖 " .. #dep_names .. " 个",
  }, "   ")

  local go = pick_one({
    { id = "go",   hint = parent .. "/" .. name },
    { id = "redo", hint = "重新走一遍向导" },
    { id = "no",   hint = "不留任何文件" },
  }, "确认创建　" .. summary)
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
  vim.notify("已创建 " .. dir .. "　jdtls 正在导入依赖（首次 10~60 秒），稍后 :LspInfo 确认", vim.log.levels.INFO)
end

function M.create()
  define_highlights()
  local ok, rerr = coroutine.resume(coroutine.create(flow))
  if not ok then
    vim.notify("向导内部错误：" .. tostring(rerr), vim.log.levels.ERROR)
  end
end

function M.setup()
  define_highlights()
  -- 我们的组是 link 到语义组的，换主题后 link 关系仍在，但 default=true 的
  -- 定义会被新主题的清空逻辑覆盖，所以换主题时补一次
  vim.api.nvim_create_autocmd("ColorScheme", {
    desc = "重建 Spring Boot 向导的派生高亮组",
    callback = define_highlights,
  })
  if vim.fn.exists(":SpringBootCreate") == 2 then return end
  vim.api.nvim_create_user_command("SpringBootCreate", function()
    M.create()
  end, { desc = "Spring Boot 项目向导（snacks.picker 版：逐段着色 + 勾选列 + 预览）" })
end

return M
