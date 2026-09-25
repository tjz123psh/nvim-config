-- ============================================
-- Java 语言支持：jdtls LSP + DAP 调试 + Maven / Spring Boot
-- 前置: :Mason 安装 jdtls + java-debug-adapter + java-test + lemminx
-- 外部依赖: mvn（Maven）/ spring（Spring Boot CLI），都在 ~/.local/bin
-- ============================================
--
-- 三件关键事（踩坑记录）:
--   1. java-debug-adapter / java-test 必须作为 bundles 由 jdtls 启动时加载，
--      不能独立 java -jar 运行；改了 bundles 要 :LspRestart 或重开才生效。
--   2. jdtls 需要独立 workspace 目录缓存每个项目的索引，
--      所以不能走 nvim-lspconfig 自动配置，必须 nvim-jdtls + 每项目 -data。
--   3. 本文件必须显式传 on_attach（见 core/lsp_on_attach.lua 注释），
--      否则 Java 缓冲区没有 gd/gr/gh 等导航键。
--
-- 调试流程:
--   F9 打断点 → F5 → jdtls 扫描带 main 的类 →（多个则 vim.ui.select 选）
--   → dap.run() → jdtls.startDebugSession 返回端口 → nvim-dap 连接
--   注意 F5 若提示"仍在导入项目"，是因为 Maven 依赖还没索引完，会自动重试。
-- ============================================

return {
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    -- :JavaBuildProjects / :JavaSetRuntime 由本插件的 config 注册；不声明 cmd 的话，
    -- 非 Java 会话里输这两个命令会 E492（文档/速查里都写了它们，2026-09-25 全面检查发现）。
    cmd = { "JavaBuildProjects", "JavaSetRuntime" },
    opts = {
      cmd = { vim.fn.stdpath("data") .. "/mason/bin/jdtls" },
      -- root_dir 不用在 opts 里设函数——vim.lsp.start 不解析函数式 root_dir
      -- 在 config 里预先求值为字符串再传
      settings = {
        java = {
          inlayHints = { parameterNames = { enabled = "all" } },
          -- 让 jdtls 拉第三方库 sources jar，才能像 IDEA 一样点进依赖看源码
          maven = { downloadSources = true, downloadJavadoc = false },
          -- main/测试方法上方显示 run|debug 标记，引用处显示引用数
          referencesCodeLens = { enabled = true },
          implementationCodeLens = { enabled = true },
          completion = {
            -- 常用静态成员不强制全限定名（System.out、Assert.* 等）
            favoriteStaticMembers = {
              "org.junit.Assert.*",
              "org.junit.jupiter.api.Assertions.*",
              "org.mockito.Mockito.*",
              "java.util.Objects.requireNonNull",
              "java.lang.Math.*",
            },
            importOrder = { "java", "javax", "jakarta", "com", "org", "" },
          },
          signatureHelp = { descriptionEnabled = true },
          -- :JavaSetRuntime（IDEA 的 Project SDK）依赖这里：jdtls.set_runtime() 在
          -- runtimes 为空时只会 warning、什么都不做。列出本机真实存在的 JDK，
          -- 第一个作为默认；路径不存在就跳过（换机器/换发行版不会报错）。
          configuration = {
            runtimes = (function()
              local found = {}
              for _, c in ipairs({
                { name = "JavaSE-21", path = "/usr/lib/jvm/java-21-openjdk" },
                { name = "JavaSE-1.8", path = "/usr/lib/jvm/java-8-openjdk" },
              }) do
                if vim.fn.isdirectory(c.path) == 1 then
                  found[#found + 1] = { name = c.name, path = c.path, default = (#found == 0) }
                end
              end
              return found
            end)(),
          },
        },
      },
      init_options = {
        bundles = {},
      },
    },

    config = function(_, opts)
      local ok, blink = pcall(require, "blink.cmp")
      if ok then
        opts.capabilities = blink.get_lsp_capabilities()
      end

      -- 将 java-debug/java-test JAR 作为 bundles 传给 jdtls（必须, 不能独立 java -jar 启动）
      -- java-test 的 server 目录里混着两个非 OSGi 的普通 jar（test runner、jacoco agent），
      -- 它们没有 Bundle-SymbolicName，会让 jdt.ls 的 bundle 列表整体加载失败，必须排除
      local non_bundles = {
        "runner%-jar%-with%-dependencies",
        "jacocoagent",
        "org%.objectweb%.asm",
      }
      local seen_bundles = {}
      local bundle_patterns = {
        vim.fn.stdpath("data")
          .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
        vim.fn.stdpath("data") .. "/mason/packages/java-test/extension/server/*.jar",
      }
      for _, pattern in ipairs(bundle_patterns) do
        local jars = vim.fn.glob(pattern, false, true)
        for _, jar in ipairs(jars) do
          local skip = false
          for _, needle in ipairs(non_bundles) do
            if jar:match(needle) then
              skip = true
              break
            end
          end
          if not skip and not seen_bundles[jar] and vim.uv.fs_stat(jar) then
            seen_bundles[jar] = true
            table.insert(opts.init_options.bundles, jar)
          end
        end
      end

      -- Spring Boot Tools：把官方 jdtls 扩展作为 bundle 注入现有 jdtls。
      -- spring-boot.nvim 会从 Mason 的 vscode-spring-boot-tools 读取这些 jar。
      local ok_spring, spring_boot = pcall(require, "spring_boot")
      if ok_spring then
        vim.list_extend(opts.init_options.bundles, spring_boot.java_extensions())
      end

      -- Lombok：Spring Boot 项目几乎必用，没有 agent 时 @Data/@Builder/@Slf4j
      -- 会报一堆"找不到 getXxx()"的假错误。通过 jdtls 的 --jvm-arg 挂 javaagent。
      local lombok_jar = vim.fn.stdpath("data") .. "/java-extras/lombok.jar"
      local jvm_args = {}
      if vim.uv.fs_stat(lombok_jar) then
        table.insert(jvm_args, "--jvm-arg=-javaagent:" .. lombok_jar)
      else
        vim.notify("未找到 lombok.jar（" .. lombok_jar .. "），Lombok 注解可能报错", vim.log.levels.WARN)
      end

      -- 保存基础 cmd（不含 --jvm-arg / -data），后续每次 start_or_attach 时重新拼装
      local cmd_base = opts.cmd or { vim.fn.stdpath("data") .. "/mason/bin/jdtls" }

      local function build_cmd(dir)
        local project_name = vim.fn.fnamemodify(dir or vim.fn.getcwd(), ":t")
        local project_hash = vim.fn.sha256(vim.fs.normalize(dir or vim.fn.getcwd())):sub(1, 10)
        local workspace_dir = vim.fn.stdpath("data") .. "/site/jdtls-workspace/" .. project_name .. "-" .. project_hash
        local cmd = vim.deepcopy(cmd_base)
        vim.list_extend(cmd, jvm_args)
        vim.list_extend(cmd, { "-data", workspace_dir })
        return cmd
      end

      local jdtls = require("jdtls")
      local on_attach = require("core.lsp_on_attach")

      ------------------------------------------------------------------
      -- DAP 按需加载（2026-09-25，台账 §28.1）
      ------------------------------------------------------------------
      -- 原来这里是 `local jdtls_dap = require("jdtls.dap")` + `local dap = require("dap")`，
      -- 加上下面无条件的 jdtls.setup_dap()，会让**打开任意 .java 文件**就把
      -- nvim-dap + nvim-dap-ui + nvim-nio + nvim-dap-virtual-text 整条链同步拉起来
      -- （实测 startuptime：require('dap') 在 69.8ms 处，整条链 31 个条目 + nio 12 个）。
      -- 现在把 Java 特有的 DAP 接线推迟到"真的要调试 Java"时：下面每个用到 dap 的
      -- handler 先调 ensure_java_dap()（幂等）——它会 require("dap")（lazy 的模块加载器
      -- 顺手把插件装上并跑它的 config）再把 Java 适配器 / 热替换监听注册好。
      local java_dap_wired = false
      local function ensure_java_dap()
        local dap = require("dap")
        if not java_dap_wired then
          java_dap_wired = true
          jdtls.setup_dap({ hotcodereplace = "auto" })
        end
        return dap
      end

      ------------------------------------------------------------------
      -- 字段/方法多选：Tab 勾选、CR 确认、Esc 取消
      ------------------------------------------------------------------
      -- 上游 jdtls.ui.pick_many 用 vim.fn.input() 收编号，有三个问题：
      --   1. Esc 与空回车在 input() 层等价（都是 ""）→ 没有取消通道；
      --   2. 越界编号（如 3 项时输 9）直接抛 Lua 错误，整个 code action 崩掉；
      --   3. 编号输入要用户自己数行，交互差。
      -- 这里换成 snacks picker。pick_many 是同步函数、调用方直接取返回值，
      -- 而 picker 只能异步回调，所以必须"协程让出 + 回调 resume"：
      -- jdtls 的 code action 都跑在 jdtls.async.run 的协程里，可以安全 yield；
      -- 万一不在协程里（或 picker 创建失败）就回退到上游 input() 版。
      local ok_ui, jdtls_ui = pcall(require, "jdtls.ui")
      local ok_snacks, Snacks = pcall(require, "snacks")
      if ok_ui and ok_snacks and not jdtls_ui._snacks_pick_many then
        local original_pick_many = jdtls_ui.pick_many
        jdtls_ui._snacks_pick_many = true
        jdtls_ui.pick_many = function(items, prompt, label_f, pick_opts)
          if type(items) ~= "table" or #items == 0 then
            return {}
          end
          local co, is_main = coroutine.running()
          if not co or is_main then
            return original_pick_many(items, prompt, label_f, pick_opts) -- 主线程兜底
          end
          label_f = label_f or tostring
          pick_opts = pick_opts or {}
          local is_selected = pick_opts.is_selected or function()
            return false
          end

          local finder_items = {}
          for idx, item in ipairs(items) do
            finder_items[idx] = { idx = idx, item = item, text = label_f(item) }
          end

          local finished = false
          local function finish(value)
            if finished then
              return
            end
            finished = true
            if coroutine.status(co) == "suspended" then
              vim.schedule(function()
                -- resume 的返回值不能丢：协程里后续抛的错否则会静默消失
                local ok_resume, err_resume = coroutine.resume(co, value)
                if not ok_resume then
                  vim.notify("jdtls 多选弹窗回调出错：" .. tostring(err_resume), vim.log.levels.ERROR)
                end
              end)
            end
          end

          local ok_pick, picker = pcall(Snacks.picker.pick, {
            source = "jdtls-pick-many", -- 独立 source：避开 snacks 同 source dedupe
            title = (tostring(prompt or "选择"):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")),
            items = finder_items,
            filter = {},
            -- 布局：default 预设会按 width 0.8 / min_width 120 / height 0.8 预留空间（预览窗又被
            -- 我们隐藏）⇒ 3 个选项也要占 80% 屏幕的大空框。改用紧凑预设，并可用变量实时切换：
            --   :let g:jdtls_pick_layout = 'select'   （可选 default/vscode/dropdown/select/ivy/vertical）
            --   :let g:jdtls_pick_backdrop = 0        （0 = 关闭背景变暗）
            -- 默认用自定义预设 picker_compact（在 snacks.lua 里注册）：居中紧凑、随内容变高，
            -- 复刻 fzf-lua 那种小框观感。想对比内置预设：
            --   :let g:jdtls_pick_layout = 'ivy'  （picker_compact/default/vscode/dropdown/select/ivy/vertical）
            layout = {
              preset = vim.g.jdtls_pick_layout or "picker_compact",
              preview = false, -- items 不是文件，预览窗只会渲染 "error: Item has no file"
              backdrop = tonumber(vim.g.jdtls_pick_backdrop) or 60, -- 背景变暗，浮窗更聚焦
            },
            formatters = { selected = { show_always = true, unselected = true } }, -- ○/● 勾选列
            format = function(item)
              return { { label_f(item.item or item) } }
            end,
            -- ⚠ snacks 对 keys 是整体替换：这里必须从 defaults 拷一份再 merge，
            --   否则会把 <CR> 确认 / <Tab> 多选 / <Esc> 取消这些默认键一起干掉
            win = (function()
              local dwin = require("snacks.picker.config.defaults").defaults.win
              return {
                input = {
                  keys = vim.tbl_extend("force", vim.deepcopy(dwin.input.keys), {
                    ["<Esc>"] = { "cancel", mode = { "n", "i" } },
                  }),
                },
                list = {
                  keys = vim.tbl_extend("force", vim.deepcopy(dwin.list.keys), {
                    ["<Space>"] = { "toggle_item", mode = { "n", "x" } },
                  }),
                },
              }
            end)(),
            actions = {
              -- ⚠ 不能用 pk.list:toggle()：本机 snacks 的 List 没有 toggle 方法
              --   （2026-09-25 审查实测 type(list.toggle)=nil）⇒ 按 <Space> 直接报错。
              --   list:select() 内部先 unselect，本身就是勾选/取消的切换语义。
              toggle_item = function(pk)
                pk.list:select()
              end,
              confirm = function(pk)
                local sel = pk.list and pk.list.selected or {}
                local ret = {}
                for _, it in ipairs(sel) do
                  if it.item then
                    ret[#ret + 1] = it.item
                  end
                end
                finish(ret)
                pcall(function()
                  pk:close()
                end)
              end,
            },
            -- is_selected 预勾选（构造器已有的字段默认勾上）
            -- 用 snacks 自己的 set_selected：逐个 list:toggle 会与首帧渲染抢状态，
            -- 表现为「预勾选之后按 Tab 不再追加勾选」（继承自归档实现的已知问题）。
            on_show = function(pk)
              local tries = 0
              local function mark()
                tries = tries + 1
                if #pk.list.items == 0 and tries < 25 then
                  return vim.defer_fn(mark, 20)
                end
                local pre = {}
                for _, it in ipairs(pk.list.items) do
                  if it.item and is_selected(it.item) then
                    pre[#pre + 1] = it
                  end
                end
                if #pre > 0 then
                  pcall(function()
                    pk.list:set_selected(pre)
                    if pk.list.render then
                      pk.list:render()
                    end
                  end)
                end
              end
              mark()
            end,
            on_close = function()
              finish(nil) -- Esc / <C-c> → nil = 取消
            end,
          })
          if not ok_pick or type(picker) ~= "table" then
            -- 回退要发声：布局写错时 snacks 会报错，静默回退会让"样式没生效"完全看不出原因
            vim.notify(
              "jdtls 多选弹窗启动失败，已回退到上游输入框：" .. tostring(picker),
              vim.log.levels.WARN
            )
            return original_pick_many(items, prompt, label_f, pick_opts)
          end
          -- ⚠ 上游 nvim-jdtls 的 pick_many 契约是"永远返回 table"（取消时是空表），
          --   返回 nil 会让调用方 #selected 直接报错（jdtls.lua:782）。Esc 取消 → 空表。
          return coroutine.yield() or {}
        end
      end

      -- 解析 root_dir 为字符串（vim.lsp.start 直接传值，不支持函数）
      local resolve_root = function(bufnr)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        if fname and #fname > 0 then
          return vim.fs.root(fname, { "pom.xml", "build.gradle", "build.gradle.kts", ".git", "src" }) or vim.fn.getcwd()
        end
        return vim.fn.getcwd()
      end
      opts.root_dir = resolve_root(0)

      -- 注册适配器（找 jdtls client → startDebugSession → port）已挪进 ensure_java_dap()，
      -- 不再在这里无条件执行——否则打开 .java 就会拖起整条 nvim-dap 链（见上方注释）。

      ------------------------------------------------------------------
      -- 构建 / 运行：自动在 mvnw / gradlew / mvn / gradle 之间选择
      ------------------------------------------------------------------
      local function project_root()
        return vim.fs.root(0, { "mvnw", "gradlew", "pom.xml", "build.gradle", "build.gradle.kts" })
      end

      -- maven_task / gradle_task 任一为 nil 表示该构建工具不支持此操作
      local function run_build(maven_task, gradle_task, extra)
        local root = project_root()
        if not root then
          vim.notify("未找到项目根目录（需要 pom.xml 或 build.gradle*）", vim.log.levels.ERROR)
          return
        end

        local is_gradle = vim.uv.fs_stat(root .. "/build.gradle") or vim.uv.fs_stat(root .. "/build.gradle.kts")
        local is_maven = vim.uv.fs_stat(root .. "/pom.xml")

        local bin, task, tool
        if is_gradle then
          bin = vim.uv.fs_stat(root .. "/gradlew") and "./gradlew" or "gradle"
          task = gradle_task
          tool = "Gradle"
        elseif is_maven then
          bin = vim.uv.fs_stat(root .. "/mvnw") and "./mvnw" or "mvn"
          task = maven_task
          tool = "Maven"
        else
          vim.notify("项目根目录下既没有 pom.xml 也没有 build.gradle*", vim.log.levels.ERROR)
          return
        end

        if not task then
          vim.notify("当前项目用 " .. tool .. "，该操作没有对应任务", vim.log.levels.WARN)
          return
        end

        -- wrapper 从 git 克隆后常常没有可执行位，先补上
        if bin:sub(1, 2) == "./" then
          vim.fn.setfperm(root .. "/" .. bin:sub(3), "rwxr-xr-x")
        end

        local cmdline = bin .. " " .. task .. (extra or "")
        -- exec(cmd, num, size, dir, direction, ...) 是位置参数，不是 table
        -- 用 2 号终端，避免和 <leader>tt 的 1 号交互终端抢位置；保留终端焦点查看结果
        require("toggleterm").exec(cmdline, 2, nil, root, "horizontal", "Java 测试", false)
      end

      ------------------------------------------------------------------
      -- 调试：优先用 jdtls 扫出来的主类，扫不到才回退手工输入
      ------------------------------------------------------------------
      local function pick_main_and_run(configs)
        local dap = ensure_java_dap() -- 按需加载 nvim-dap（见文件顶部注释）
        if #configs == 1 then
          dap.run(configs[1])
          return
        end
        -- vim.ui.select 现在由 snacks picker 接管（全机唯一的选择器）
        vim.ui.select(configs, {
          prompt = "选择要调试的主类",
          format_item = function(c)
            return c.mainClass or c.name
          end,
        }, function(choice)
          if choice then
            dap.run(choice)
          end
        end)
      end

      local function debug_java()
        local dap = ensure_java_dap()
        local jdtls_dap = require("jdtls.dap")
        local configs = dap.configurations.java or {}
        if #configs > 0 then
          pick_main_and_run(configs)
          return
        end

        -- 首次：jdtls 要先把 Maven 依赖导完、编译完，才扫得出带 main 的类。
        -- on_ready 无参数，必须自己回读 dap.configurations.java。
        local function attempt(n)
          jdtls_dap.setup_dap_main_class_configs({
            verbose = false,
            on_ready = function()
              local found = dap.configurations.java or {}
              if #found > 0 then
                vim.notify("找到 " .. #found .. " 个主类", vim.log.levels.INFO)
                pick_main_and_run(found)
                return
              end
              if n < 4 then
                vim.notify("jdtls 仍在导入项目，重试 " .. (n + 1) .. "/4…", vim.log.levels.WARN)
                vim.defer_fn(function()
                  attempt(n + 1)
                end, 2500)
              else
                vim.notify(
                  "未发现主类。确认：1) 类里有 public static void main 2) :JavaBuildProjects 已跑过 3) jdtls 导入完成",
                  vim.log.levels.ERROR
                )
                -- ⚠ 默认值不能塞进 vim.fn.input 的第二参：那样是"预填"，用户直接打字会追加成
                --   DemoApplicationcom.example.App（2026-09-25 审查实测）。默认值只写进提示，
                --   空输入才回退到它（向导 spring_wizard 早就是这么做的）。
                local default_class = vim.fn.expand("%:t:r")
                local main_class = vim.fn.input("主类名 [" .. default_class .. "]: ")
                if main_class == "" then
                  main_class = default_class
                end
                if main_class and #main_class > 0 then
                  dap.run({
                    type = "java",
                    name = "Java 调试",
                    request = "launch",
                    mainClass = main_class,
                  })
                end
              end
            end,
          })
        end
        attempt(1)
      end

      ------------------------------------------------------------------
      -- 终端测试：运行测试不进入 DAP 调试界面，结果保留在终端中
      ------------------------------------------------------------------
      local function current_test_selector(include_method)
        local bufnr = vim.api.nvim_get_current_buf()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
        local package_name
        local class_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t:r")
        local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

        for _, line in ipairs(lines) do
          package_name = line:match("^%s*package%s+([%w_%.]+)%s*;") or package_name
          if package_name then
            break
          end
        end

        local selector = package_name and (package_name .. "." .. class_name) or class_name
        if not include_method then
          return selector
        end

        for index = cursor_line, 1, -1 do
          local method_name = lines[index]:match("^%s*[%w_%s<>%[%],%.%?]+%s+([%w_]+)%s*%([^;]*%)%s*{%s*$")
          if method_name then
            return selector .. "#" .. method_name
          end
        end

        vim.notify("光标附近未找到 Java 测试方法", vim.log.levels.WARN)
        return nil
      end

      local function run_java_test(include_method)
        local selector = current_test_selector(include_method)
        if not selector then
          return
        end
        run_build("test -Dtest=" .. selector, "test --tests " .. selector:gsub("#", "."))
      end

      ------------------------------------------------------------------
      -- 缓冲区快捷键
      ------------------------------------------------------------------
      local setup_java_keys = function(bufnr)
        local function d(s)
          return { buffer = bufnr, silent = true, desc = s }
        end

        -- 保留原有的两个别名
        vim.keymap.set("n", "<leader>co", vim.lsp.buf.code_action, d("Java 代码操作"))
        vim.keymap.set("n", "<leader>ot", jdtls.organize_imports, d("整理 import"))

        -- 调试
        vim.keymap.set("n", "<F5>", debug_java, d("Java: 调试（自动识别主类）"))
        vim.keymap.set("n", "<leader>Jd", function()
          ensure_java_dap()
          require("jdtls.dap").setup_dap_main_class_configs({ verbose = true })
        end, d("Java: 重新扫描主类"))

        -- 测试默认走 Maven/Gradle 终端，结果不会随着 DAP 面板关闭而消失
        vim.keymap.set("n", "<leader>Jt", function()
          run_java_test(true)
        end, d("Java: 终端运行光标处测试方法"))
        vim.keymap.set("n", "<leader>JT", function()
          run_java_test(false)
        end, d("Java: 终端运行当前测试类"))

        -- 需要断点、变量和调用栈时，显式使用 Java 测试调试
        vim.keymap.set("n", "<leader>Jg", jdtls.test_nearest_method, d("Java: 调试光标处测试方法"))
        vim.keymap.set("n", "<leader>JG", jdtls.test_class, d("Java: 调试当前测试类"))

        -- 重构（IDEA 的 Extract…）
        -- ⚠ 必须同时给 x 模式映射：nvim-jdtls 只在 opts.visual=true 时按可视标记取范围，
        --   而 {Visual}<leader>Rv 在没有 x 模式映射时会落到 Vim 内置的 R（删行进替换模式）
        --   ⇒ 选区被删掉、后面那个 "v" 还会被当文本写进文件（2026-09-25 审查实测）。
        vim.keymap.set("x", "<leader>Rv", function()
          jdtls.extract_variable(true)
        end, d("重构: 提取变量（选区）"))
        vim.keymap.set("x", "<leader>RV", function()
          jdtls.extract_variable_all(true)
        end, d("重构: 提取所有重复表达式为变量（选区）"))
        vim.keymap.set("x", "<leader>Rc", function()
          jdtls.extract_constant(true)
        end, d("重构: 提取常量（选区）"))
        vim.keymap.set("x", "<leader>Rm", function()
          jdtls.extract_method(true)
        end, d("重构: 提取方法（选区）"))
        -- n 模式保留「光标处表达式」语义
        vim.keymap.set("n", "<leader>Rv", jdtls.extract_variable, d("重构: 提取变量（光标处）"))
        vim.keymap.set("n", "<leader>RV", jdtls.extract_variable_all, d("重构: 提取所有重复表达式为变量"))
        vim.keymap.set("n", "<leader>Rc", jdtls.extract_constant, d("重构: 提取常量"))
        vim.keymap.set("n", "<leader>Rm", jdtls.extract_method, d("重构: 提取方法"))

        -- 父类/接口实现跳转（IDEA 的 Ctrl+U）
        -- 用 gA 而不是 gU：gU 是内置的「转大写」操作符，覆盖它会让 Java 里 gU{motion} 失效
        vim.keymap.set("n", "gA", jdtls.super_implementation, d("跳转到父类/接口实现"))

        -- Spring Boot
        vim.keymap.set("n", "<leader>sr", function()
          run_build("spring-boot:run", "bootRun")
        end, d("Spring Boot: 运行"))

        -- Maven / Gradle 生命周期
        vim.keymap.set("n", "<leader>mc", function()
          run_build("compile", "classes")
        end, d("构建: 编译"))
        vim.keymap.set("n", "<leader>mt", function()
          run_build("test", "test")
        end, d("构建: 跑测试"))
        vim.keymap.set("n", "<leader>mp", function()
          run_build("package -DskipTests", "build -x test")
        end, d("构建: 打包（跳过测试）"))
        vim.keymap.set("n", "<leader>mi", function()
          run_build("install -DskipTests", "install -x test")
        end, d("构建: 安装到本地仓库"))
        vim.keymap.set("n", "<leader>mn", function()
          run_build("clean", "clean")
        end, d("构建: 清理"))
        vim.keymap.set("n", "<leader>ml", function()
          run_build("dependency:tree", "dependencies")
        end, d("构建: 依赖树"))
        vim.keymap.set("n", "<leader>mb", jdtls.build_projects, d("构建: 让 jdtls 重新导入/构建项目"))
      end

      ------------------------------------------------------------------
      -- 全局命令（不依赖当前 buffer 是否已触发 FileType）
      ------------------------------------------------------------------
      local function jdtls_ready()
        if #vim.lsp.get_clients({ name = "jdtls" }) == 0 then
          vim.notify("需要先打开一个 Java 项目（jdtls 尚未附加到任何缓冲区）", vim.log.levels.WARN)
          return false
        end
        return true
      end

      vim.api.nvim_create_user_command("JavaBuildProjects", function()
        if jdtls_ready() then
          jdtls.build_projects()
        end
      end, { desc = "jdtls: 重新导入并构建项目（改了 pom.xml 依赖后用）" })

      vim.api.nvim_create_user_command("JavaSetRuntime", function(p)
        if jdtls_ready() then
          -- 上游 jdtls.set_runtime(runtime) 用 `if runtime then` 分流：nargs="?" 不带参数时
          -- p.args 是空字符串（Lua 里为真！），会被当成"运行时名"，结果只报
          -- "Provided runtime `` not found in ..."、不弹选择列表。无参数必须传 nil 才会走
          -- ui.pick_one_async 列出 runtimes（真机实测：修复前只见警告，修复后列出
          -- JavaSE-21 / JavaSE-1.8）。
          jdtls.set_runtime(p.args ~= "" and p.args or nil)
        end
      end, {
        desc = "切换 JDK（IDEA 的 Project SDK）",
        nargs = "?",
        complete = function(arg_lead)
          if #vim.lsp.get_clients({ name = "jdtls" }) == 0 then
            return {}
          end
          return jdtls._complete_set_runtime(arg_lead)
        end,
      })

      ------------------------------------------------------------------
      -- 启动 / 附加
      ------------------------------------------------------------------
      -- 每次启动/附加时重新解析 root_dir 和 cmd（-data workspace_dir 按项目切换）
      -- 首个 Java buffer 的 FileType 会被触发两次（lazy 的 ft handler + runtime filetype.lua），
      -- 没有守卫时 jdtls / spring-boot 会各 start 两次（实测 LSP_START_CALLS=4），这里按 buffer 去重
      local started_bufs = {}
      local function start_jdtls(bufnr)
        bufnr = (bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
        local root_dir = resolve_root(bufnr)
        local config = vim.deepcopy(opts)
        config.root_dir = root_dir
        config.cmd = build_cmd(root_dir)
        config.on_attach = on_attach
        -- workspace/executeClientCommand 是**服务端→客户端**的请求（VS Code 里由 Java / Spring 扩展实现）。
        -- 本机收到的两类：
        --   · `_java.reloadBundles.command`（jdtls 要求客户端重载 bundles；bundles 已在启动时经
        --     init_options.bundles 传入，nvim 侧无需再做）
        --   · `vscode-spring-boot.ls.start`（spring-boot LS 的客户端命令；本配置由 spring-boot.nvim
        --     独立拉起 LS，同样无需客户端动作）
        -- handler 必须写在 config 里（而不是启动后再补）：第一条请求发生在初始化阶段。
        --
        -- ⚠ 这里踩过两个坑（2026-09-25 用户截图定位，nvim runtime 源码 rpc.lua:389-406）：
        --   1. `return`（返回 nil）**不是"什么都不做"**：nvim 的 rpc.lua:398-406 在
        --      "status=true 且 result==nil 且 err==nil" 时会主动抛
        --      `method "…": either a result or an error must be sent to the server in response`
        --      ⇒ 红色 `vim.schedule callback … rpc.lua:400` traceback，而且这条请求**永远不回**、
        --      服务端一直挂着（第 11 轮"消 ERROR"其实只是把它换成了另一种报错）。
        --   2. `error({code=-32601, …})` 会让服务端记 `SERVER_REQUEST_HANDLER_ERROR … Method not found`
        --      ⇒ 又是一条红色通知。
        -- 正解有两层：
        --   ① **必须先查有没有实现**：spring-boot.nvim 把 `vscode-spring-boot.ls.start`（classpath 握手，
        --      最终调用 `sts.vscode-spring-boot.enableClasspathListening`）注册在**全局** `vim.lsp.commands`；
        --      而 nvim-jdtls 本来也在**全局** `vim.lsp.handlers` 装了等价转发（jdtls.lua:854-874）。
        --      ⚠ **client 级 handler 会盖掉全局那个**（client.lua:657）⇒ 必须把"先 client.commands、
        --      再全局 vim.lsp.commands"这套查找自己复刻一遍，否则那条握手永远不执行：
        --      后果是**没有 beans / endpoints / application.yml 的 spring.* 补全**（2026-09-25 审查线①发现，
        --      这是第 11 轮引入的隐性功能回归）。
        --   ② 查不到实现的命令（如 jdtls 的 `_java.reloadBundles.command`，nvim 侧本就无可做之事）
        --      **回空结果 `vim.NIL`**（协议里的 JSON null）而不是上游的 MethodNotFound —— 这样 jdtls
        --      不再记 ERROR；并且**绝不能 `return nil`**（见上面的坑 1）。
        config.handlers = {
          ["workspace/executeClientCommand"] = function(_, params, ctx)
            params = params or {}
            local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
            local commands = client.commands or {}
            local global_commands = vim.lsp.commands or {}
            local fn = commands[params.command] or global_commands[params.command]
            if fn then
              local ok, res = pcall(fn, params.arguments, ctx)
              if ok then
                return res == nil and vim.NIL or res
              end
              return vim.lsp.rpc_response_error(vim.lsp.protocol.ErrorCodes.InternalError, tostring(res))
            end
            return vim.NIL
          end,
        }
        if started_bufs[bufnr] then
          -- ⚠ 重载缓冲区（:e / :e! / 任何触发 FileType 的重载）会让 Neovim 把该 buffer
          --   从**所有** client 上 detach；随后只有走 vim.lsp.enable 按 filetype 管理的
          --   spring-boot 会自己回来。原来的"直接 return"去重守卫让 jdtls 永远不回来 ⇒
          --   之后 gh/gd/grn/gra 全部静默失效（实测通知：Empty hover response /
          --   No locations found / No code actions available /
          --   no matching language servers with rename capability）。
          --   所以：已经启动过也要保证 jdtls 仍挂在这个 buffer 上（2026-09-25 真机定位）。
          local existing = vim.lsp.get_clients({ name = "jdtls" })[1]
          if existing and not (existing.attached_buffers or {})[bufnr] then
            vim.lsp.buf_attach_client(bufnr, existing.id)
          end
          setup_java_keys(bufnr)
          return
        end
        started_bufs[bufnr] = true
        jdtls.start_or_attach(config)
        setup_java_keys(bufnr)
      end

      -- 后续打开的 Java 文件
      local group = vim.api.nvim_create_augroup("java_jdtls", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "java",
        callback = function(args)
          start_jdtls(args.buf)
        end,
      })

      -- 当前已有 Java 文件
      if vim.bo.filetype == "java" then
        vim.schedule(function()
          start_jdtls(0)
        end)
      end
    end,
  },
}
