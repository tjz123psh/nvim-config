-- =============================================================================
-- 项目管理：project.nvim
-- =============================================================================
-- 自动检测当前文件所属的项目（通过 .git、LSP 等），
-- 并给 `:Projects` / <leader>fp 提供项目历史（选择器已换成 snacks picker）。
-- =============================================================================

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

    -- 历史文件守卫（2026-09-25 并发压测复现，见 ~/tmp/nvim-audit/hist/report.md）：
    -- project.nvim 的 write_projects_to_history() 只在 recent_projects == nil 时用追加模式；
    -- 而 utils/history.lua 的**异步**读只要在"文件被别的实例截断成 0 字节"的窗口里返回，
    -- recent_projects 就会变成**空表（非 nil）**⇒ 退出时按 mode="w" 截断写回，把磁盘上
    -- 完整的历史覆盖成本进程内存里的那一份（压测实测：磁盘 352B/8 条 → 退出后 0 字节；
    -- 若自有副本也没记录过这些条目，就是不可恢复的永久丢失）。
    -- 修法：写之前比对"磁盘现有条目"与"本次准备写出的条目"；只要这次写会丢掉磁盘上
    -- 已有条目，就降级为"只追加缺的那些"，**绝不截断**。正常情况（计划 ⊇ 磁盘）仍走原
    -- 实现，插件自身的去重 / 裁剪 100 条语义完全不变。
    local ok_hist, history = pcall(require, "project_nvim.utils.history")
    local ok_path_utils, path_utils = pcall(require, "project_nvim.utils.path")
    if ok_hist and ok_path_utils and type(history.write_projects_to_history) == "function" then
      local original_write = history.write_projects_to_history

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

      history.write_projects_to_history = function()
        local ok, err = pcall(function()
          local disk = disk_entries()
          local planned, list = {}, {}
          for _, dir in ipairs(history.get_recent_projects()) do
            if not planned[dir] then
              planned[dir] = true
              list[#list + 1] = dir
            end
          end

          -- 本次计划里没有、但磁盘上还留着的条目 —— 截断就会永久丢掉它们
          local would_lose = false
          for dir in pairs(disk) do
            if not planned[dir] then
              would_lose = true
              break
            end
          end
          if not would_lose then
            original_write() -- 计划 ⊇ 磁盘：原行为（含去重与裁剪 100 条）
            return
          end

          local missing = {}
          for _, dir in ipairs(list) do
            if not disk[dir] then
              missing[#missing + 1] = dir
            end
          end
          if #missing == 0 then
            return -- 磁盘是本次计划的超集：什么都不写，更不许截断
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
          -- 守卫自身出错时也要保证历史文件不被半截覆盖
          vim.notify("项目历史写回守卫异常，已回退原实现: " .. tostring(err), vim.log.levels.WARN)
          pcall(original_write)
        end
      end
    end
  end,
}
