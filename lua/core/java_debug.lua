-- 捕获当前 jdtls 客户端逐步查询主类，不使用跨项目的 dap.configurations.java。
-- 上游 fetch_main_configs 在缓冲区 detach 后可回退到其它客户端，且部分错误不回调；
-- 这里直连捕获的 client，并给每次查询统一的失败/超时出口。
local M = {}

function M.fetch(bufnr, client, valid, callback)
  local finished = false
  local function finish(err, configs)
    if finished then
      return
    end
    finished = true
    callback(err, configs)
  end
  local function request(command, arguments, next_step)
    if finished then
      return
    end
    if not valid() then
      finish("Java 调试上下文已变化")
      return
    end
    local params = { command = command }
    if arguments ~= nil then
      params.arguments = arguments
    end
    local ok, sent = pcall(client.request, client, "workspace/executeCommand", params, function(err, result)
      if finished then
        return
      end
      if not valid() then
        finish("Java 调试上下文已变化")
      elseif err then
        finish(command .. ": " .. (err.message or vim.inspect(err)))
      else
        local handled, failure = pcall(next_step, result)
        if not handled then
          finish("Java 调试响应无法解析：" .. tostring(failure))
        end
      end
    end, bufnr)
    if not ok or not sent then
      finish("无法发送 Java 调试请求：" .. command)
    end
  end
  vim.defer_fn(function()
    finish("查询 Java 主类超时，请等待 jdtls 导入完成后重试")
  end, 15000)

  request("vscode.java.resolveMainClass", nil, function(mains)
    if type(mains) ~= "table" then
      finish("jdtls 未返回有效的主类列表")
      return
    end
    if #mains == 0 then
      finish(nil, {})
      return
    end
    local configs, remaining = {}, #mains
    for index, main in ipairs(mains) do
      if type(main) ~= "table" or type(main.mainClass) ~= "string" then
        finish("jdtls 返回的主类缺少名称")
        return
      end
      local class, project = main.mainClass, main.projectName or ""
      request("vscode.java.resolveJavaExecutable", { class, project }, function(java_exec)
        if type(java_exec) ~= "string" or java_exec == "" then
          finish("无法确定主类 " .. class .. " 的 Java 可执行文件")
          return
        end
        local settings = vim.json.encode({
          className = class,
          projectName = project,
          inheritedOptions = true,
          expectedOptions = { ["org.eclipse.jdt.core.compiler.problem.enablePreviewFeatures"] = "enabled" },
        })
        request("vscode.java.checkProjectSettings", settings, function(preview)
          request("vscode.java.resolveClasspath", { class, project }, function(paths)
            if type(paths) ~= "table" or type(paths[1]) ~= "table" or type(paths[2]) ~= "table" then
              finish("无法确定主类 " .. class .. " 的 classpath")
              return
            end
            configs[index] = {
              type = "java",
              request = "launch",
              name = "Launch " .. project .. ": " .. class,
              mainClass = class,
              projectName = project,
              cwd = client.config.root_dir, -- 保留精确 LSP 根，适配器据此选择客户端。
              modulePaths = paths[1],
              classPaths = paths[2],
              javaExec = java_exec,
              console = "integratedTerminal",
              vmArgs = preview == true and "--enable-preview" or nil,
            }
            remaining = remaining - 1
            if remaining == 0 then
              finish(nil, configs)
            end
          end)
        end)
      end)
    end
  end)
end

return M
