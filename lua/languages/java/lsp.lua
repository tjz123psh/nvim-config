local M = {}
local project = require("languages.java.project")

-- 客户端级 handler 会盖掉上游转发：nil/异常/重新加载 bundles 必须按 RPC 契约返回。
function M.execute_client_command(_, params, ctx)
  params = params or {}
  local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
  local fn = (client.commands or {})[params.command] or vim.lsp.commands[params.command]
  if fn then
    local ok, result = pcall(fn, params.arguments, ctx)
    if not ok then
      return nil, vim.lsp.rpc_response_error(vim.lsp.protocol.ErrorCodes.InternalError, tostring(result))
    end
    return result == nil and vim.NIL or result
  end
  return params.command == "_java.reloadBundles.command" and {} or vim.NIL
end

local function bundles(data)
  local result = {}
  for _, pattern in ipairs({
    "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
    "/mason/packages/java-test/extension/server/*.jar",
  }) do
    for _, jar in ipairs(vim.fn.glob(data .. pattern, false, true)) do
      -- runner/agent/ASM 不是要装入 jdtls 的 OSGi bundle。
      if
        not jar:match("runner%-jar%-with%-dependencies")
        and not jar:match("jacocoagent")
        and not jar:match("org%.objectweb%.asm")
      then
        result[#result + 1] = jar
      end
    end
  end
  return vim.list_extend(result, require("spring_boot").java_extensions())
end

local JVM_ROOT = "/usr/lib/jvm"
local MIN_LAUNCHER = 25 -- 2026-10 起的 JDT LS 需要 Java 25 才能启动

local function jdk_version(dir)
  local ok, lines = pcall(vim.fn.readfile, dir .. "/release")
  if not ok then
    return nil, 0
  end
  for _, line in ipairs(lines) do
    local version = line:match('^JAVA_VERSION="([^"]+)"')
    if version then
      local major = tonumber(version:match("^(%d+)")) or 0
      if major == 1 then
        major = tonumber(version:match("^1%.(%d+)")) or 0
      end
      return version, major
    end
  end
  return nil, 0
end

-- 只认带 bin/java 的目录；路径可以来自环境变量，不必在 /usr/lib/jvm 下。
local function jdk_at(dir)
  if not dir or dir == "" then
    return nil
  end
  -- 解开软链：/usr/lib/jvm/default 这类别名会和真实目录重复。
  dir = vim.uv.fs_realpath(vim.fs.normalize(dir)) or vim.fs.normalize(dir)
  if vim.fn.executable(dir .. "/bin/java") ~= 1 then
    return nil
  end
  local version, major = jdk_version(dir)
  return { path = dir, version = version or "未知", major = major }
end

-- 本机已安装的 JDK，按主版本从高到低。
local function installed_jdks()
  local found, seen = {}, {}
  for _, dir in ipairs(vim.fn.glob(JVM_ROOT .. "/*", false, true)) do
    local jdk = jdk_at(dir)
    if jdk and jdk.major > 0 and not seen[jdk.path] and vim.fn.executable(jdk.path .. "/bin/javac") == 1 then
      seen[jdk.path] = true
      jdk.name = jdk.major >= 9 and ("JavaSE-" .. jdk.major) or ("JavaSE-1." .. jdk.major)
      found[#found + 1] = jdk
    end
  end
  table.sort(found, function(a, b)
    return a.major > b.major
  end)
  return found
end

-- 跑 jdtls 自己的 JVM：专用开关 > JAVA_HOME（够新才用）> 本机最高 > 交给 PATH。
local function launcher_jdk(installed)
  local override = jdk_at(vim.env.NVIM_JDTLS_JAVA_HOME)
  if override then
    if override.major < MIN_LAUNCHER then
      vim.notify(
        string.format(
          "NVIM_JDTLS_JAVA_HOME 指向 Java %s，低于 jdtls 要求的 %d；仍按你的设置启动",
          override.version,
          MIN_LAUNCHER
        ),
        vim.log.levels.WARN
      )
    end
    return override
  end
  local home = jdk_at(vim.env.JAVA_HOME)
  if home and home.major >= MIN_LAUNCHER then
    return home
  end
  for _, jdk in ipairs(installed) do
    if jdk.major >= MIN_LAUNCHER then
      return jdk
    end
  end
  if home then
    vim.notify(
      string.format("JAVA_HOME 指向 Java %s，低于 jdtls 要求的 %d；已忽略", home.version, MIN_LAUNCHER),
      vim.log.levels.WARN
    )
  end
  if installed[1] then
    vim.notify(
      string.format(
        "没有 Java %d+，jdtls 将尝试用 Java %s 启动（可能失败）",
        MIN_LAUNCHER,
        installed[1].version
      ),
      vim.log.levels.WARN
    )
  end
  return installed[1]
end

function M.setup(opts)
  local jdtls = require("jdtls")
  local data = vim.fn.stdpath("data")
  opts = vim.deepcopy(opts or {})
  opts.cmd = opts.cmd or { data .. "/mason/bin/jdtls" }
  opts.init_options = { bundles = bundles(data) }
  opts.capabilities = require("blink.cmp").get_lsp_capabilities(opts.capabilities)
  local installed = installed_jdks()
  -- 默认项目 JDK：JAVA_HOME 指的那个 > 本机最高版本。
  local home = jdk_at(vim.env.JAVA_HOME)
  local default
  if home then
    for _, jdk in ipairs(installed) do
      if jdk.path == home.path then
        default = jdk
      end
    end
  end
  default = default or installed[1]
  local runtimes = {}
  for _, jdk in ipairs(installed) do
    runtimes[#runtimes + 1] = { name = jdk.name, path = jdk.path, default = jdk == default or nil }
  end
  opts.settings =
    vim.tbl_deep_extend("force", opts.settings or {}, { java = { configuration = { runtimes = runtimes } } })
  -- 这里只决定服务端自己的 JVM；项目编译目标仍由上面的 runtimes 决定。
  local launcher = launcher_jdk(installed)
  if launcher then
    opts.cmd[#opts.cmd + 1] = "--java-executable=" .. launcher.path .. "/bin/java"
  end
  for _, path in ipairs({ data .. "/java-extras/lombok.jar", data .. "/mason/packages/jdtls/lombok.jar" }) do
    if vim.uv.fs_stat(path) then
      opts.cmd[#opts.cmd + 1] = "--jvm-arg=-javaagent:" .. path
      break
    end
  end
  opts.handlers = { ["workspace/executeClientCommand"] = M.execute_client_command }
  opts.on_attach = function(client, buf)
    vim.lsp.semantic_tokens.enable(false, { bufnr = buf }) -- 保持 Treesitter 颜色，不被 Java/Spring token 来回覆盖。
    require("languages.shared.lsp")(client, buf)
  end
  require("languages.java.ui").setup()

  local function start(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "java" or vim.api.nvim_buf_get_name(buf) == "" then
      return
    end
    require("languages.java.keymaps").setup(buf)
    local config = vim.deepcopy(opts)
    config.root_dir = project.lsp_root(buf)
    local workspace = vim.fn.fnamemodify(config.root_dir, ":t") .. "-" .. vim.fn.sha256(config.root_dir):sub(1, 10)
    vim.list_extend(config.cmd, { "-data", data .. "/site/jdtls-workspace/" .. workspace })
    -- start_or_attach 本身会复用、重新附加或重启；无需另存一套 started_bufs 状态。
    vim.api.nvim_buf_call(buf, function()
      jdtls.start_or_attach(config, nil, {
        bufnr = buf,
        reuse_client = function(client, new)
          return client.name == "jdtls" and client.config.root_dir == new.root_dir
        end,
      })
    end)
  end
  local function ready()
    if #vim.lsp.get_clients({ name = "jdtls", bufnr = 0 }) == 0 then
      vim.notify("请先打开 Java 文件并等待 jdtls 导入完成", vim.log.levels.WARN)
      return false
    end
    return true
  end
  vim.api.nvim_create_user_command("JavaBuildProjects", function()
    if ready() then
      jdtls.build_projects()
    end
  end, { desc = "jdtls: 重新导入并构建项目" })
  vim.api.nvim_create_user_command("JavaSetRuntime", function(args)
    if ready() then
      jdtls.set_runtime(args.args ~= "" and args.args or nil)
    end
  end, {
    nargs = "?",
    desc = "切换 Java 项目 JDK",
    complete = function(lead)
      local names = {}
      for _, runtime in ipairs(runtimes) do
        if vim.startswith(runtime.name, lead) then
          names[#names + 1] = runtime.name
        end
      end
      return names
    end,
  })
  local group = vim.api.nvim_create_augroup("java_jdtls", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "java",
    callback = function(event)
      start(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.java",
    callback = function(event)
      if project.root(event.buf) and #vim.lsp.get_clients({ bufnr = event.buf, name = "jdtls" }) > 0 then
        vim.api.nvim_buf_call(event.buf, function()
          jdtls.compile("incremental")
        end)
      end
    end,
  })
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype == "java" then
    vim.schedule(function()
      start(buf)
    end)
  end
end

return M
