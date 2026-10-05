-- ============================================
-- 自定义命令
-- 用 :命令名 回车即可执行
-- ============================================

-- 执行当前 Lua 文件 / 打开欢迎页 --------

-- :R 只执行磁盘文件，不清 require 缓存，也不重新应用 lazy 插件配置表。
-- 修改插件配置后先保存，再重启 Neovim；不要把它当作完整热重载。
vim.api.nvim_create_user_command("R", function()
  if vim.bo.filetype ~= "lua" then
    vim.notify(":R 只能在 .lua 文件中使用", vim.log.levels.WARN)
    return
  end
  vim.cmd.luafile(vim.fn.expand("%:p"))
end, { force = true, desc = "执行当前磁盘 Lua 文件（非完整配置重载）" })

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

-- 保留分屏布局，并对未保存修改显示确认；bufferline 会传入目标编号。
vim.api.nvim_create_user_command("BufDelete", function(p)
  local buf = tonumber(p.args)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.bufdelete then
    snacks.bufdelete(buf)
    return
  end
  -- snacks 还没加载（极少见）：退回原生，至少功能不断
  vim.cmd("bdelete" .. (buf and (" " .. buf) or ""))
end, { nargs = "?", desc = "关闭缓冲区（保留分屏布局）" })

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

-- 提前注册命令，让 :SpringBootCreate 和全局 <leader>sp 都能从启动页使用。
local ok_wiz, err_wiz = pcall(function()
  require("core.spring_wizard").setup()
end)
if not ok_wiz then
  vim.notify("Spring Boot 向导加载失败：" .. tostring(err_wiz), vim.log.levels.ERROR)
end

-- 项目历史与选择器独立维护，命令入口仍在这里注册。
require("core.projects").setup()

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
