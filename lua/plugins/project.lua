-- ============================================
-- 项目管理：project.nvim
-- ============================================
-- 自动检测当前文件所属的项目（通过 .git、LSP 等），
-- 并给 `:Projects` / <leader>fp 提供项目历史（选择器已换成 snacks picker）。
-- ============================================

return {
  "ahmedkhalf/project.nvim",
  lazy = false,
  config = function()
    require("project_nvim").setup({
      -- 检测策略：通过目录特征（pattern）和 LSP 推断项目根目录
      detection_methods = { "pattern", "lsp" },
      -- 识别项目的标记文件/目录
      patterns = {
        ".git",
        "_darcs",
        ".hg",
        ".bzr",
        ".svn",
        "Makefile",
        "CMakeLists.txt",
        "package.json",
        "go.mod",
        "Cargo.toml",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
      },
      -- 切换缓冲区时自动切换 CWD 到项目根（不弹确认框）
      sync_root_with_cwd = true,
      manual_mode = false,
    })
    -- 运行时修补：用 vim.lsp.get_clients() 替换已废弃的 vim.lsp.buf_get_clients()
    -- 避免直接修改插件文件，否则 lazy.nvim 检测到 dirty 状态会显示红色 failed
    local ok_project, Project = pcall(require, "project_nvim.project")
    if not ok_project then
      vim.notify("project.nvim 内部模块加载失败，已跳过兼容性修补", vim.log.levels.WARN)
      return
    end

    Project.find_lsp_root = function()
      local buf_ft = vim.bo[0].filetype -- 当前缓冲区的文件类型
      local clients = vim.lsp.get_clients({ bufnr = 0 }) -- 获取当前缓冲区关联的 LSP 客户端（新 API）
      if next(clients) == nil then -- 没有 LSP 客户端则跳过
        return nil
      end
      local config = require("project_nvim.config")
      for _, client in pairs(clients) do
        local filetypes = client.config.filetypes
        if filetypes and vim.tbl_contains(filetypes, buf_ft) then -- 匹配文件类型
          if not vim.tbl_contains(config.options.ignore_lsp, client.name) then -- 不在忽略列表里
            local root_dir = client.config.root_dir
            if type(root_dir) == "string" and root_dir ~= "" then
              return root_dir, client.name -- 返回项目根目录和客户端名称
            end
          end
        end
      end
      return nil
    end

    local original_set_pwd = Project.set_pwd
    if type(original_set_pwd) ~= "function" then
      return
    end

    Project.set_pwd = function(dir, method)
      local ok_changed, changed = pcall(original_set_pwd, dir, method)
      if not ok_changed then
        vim.notify("项目目录切换失败: " .. tostring(changed), vim.log.levels.ERROR)
        return false
      end
      if changed and type(dir) == "string" and package.loaded["neo-tree.sources.manager"] then
        vim.schedule(function()
          local ok, manager = pcall(require, "neo-tree.sources.manager")
          if not ok then
            return
          end
          manager._for_each_state("filesystem", function(state)
            if state.path and state.path ~= dir then
              pcall(manager.navigate, state, dir)
            end
          end)
        end)
      end
      return changed
    end

    -- 历史文件写守卫（2026-09-25 并发压测复现，详见技能 §27.3）：
    -- 上游只在 recent_projects == nil 时用追加模式；异步读撞上"被别人截断成 0 字节"的窗口时
    -- 内存会变成**空表（非 nil）** ⇒ 退出时 mode="w" 把磁盘历史抹掉（未镜像过的条目永久丢失）。
    -- 修法：**完全不用上游的截断写**，只把"磁盘上没有的条目"追加进去（见下面 write 守卫的注释）。
    local ok_hist, history = pcall(require, "project_nvim.utils.history")
    local ok_path_utils, path_utils = pcall(require, "project_nvim.utils.path")
    if ok_hist and ok_path_utils and type(history.write_projects_to_history) == "function" then
      local function disk_entries()
        local set = {}
        local fh = io.open(path_utils.historyfile, "r")
        if not fh then
          return set
        end
        local data = fh:read("*a")
        fh:close()
        for line in data:gmatch("[^\r\n]+") do
          local dir = vim.trim(line)
          if dir ~= "" then
            set[dir] = true
          end
        end
        return set
      end

      -- ⚠ 只追加、**永不截断**（2026-09-25 审查 F04）：
      --   上一版守卫是"先读盘判断会不会丢 → 不会丢就调 original_write() 的 w 模式截断重写"，
      --   但读盘与写入之间没有跨实例锁：另一个 nvim 在这个间隙 append 的条目会被这次截断抹掉
      --   （检查后截断的竞态窗口）。镜像副本只能救"已经被镜像过"的记录，救不了刚写进去的那条。
      --   追加写不会破坏别人的数据，所以这里把截断路径整个去掉；代价是插件历史文件可能变长，
      --   读取侧（core/projects.lua 的 read_project_history）本来就会去重与并集。
      history.write_projects_to_history = function()
        local ok, err = pcall(function()
          local disk = disk_entries()
          local list, seen = {}, {}
          for _, dir in ipairs(history.get_recent_projects()) do
            if not seen[dir] then
              seen[dir] = true
              list[#list + 1] = dir
            end
          end

          local missing = {}
          for _, dir in ipairs(list) do
            if not disk[dir] then
              missing[#missing + 1] = dir
            end
          end
          if #missing == 0 then
            return -- 磁盘已包含本次全部条目：什么都不用写
          end

          pcall(path_utils.create_scaffolding)
          local fh = io.open(path_utils.historyfile, "a")
          if not fh then
            return
          end
          fh:write(table.concat(missing, "\n") .. "\n")
          fh:close()
        end)
        if not ok then
          -- 守卫自身出错时也不回退到截断写：宁可这次不写，也不能破坏已有历史
          vim.notify(
            "项目历史写回守卫异常（本次跳过写入，绝不截断）: " .. tostring(err),
            vim.log.levels.WARN
          )
        end
      end
    end
  end,
}
