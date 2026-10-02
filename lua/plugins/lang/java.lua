-- ============================================
-- Java 语言支持：jdtls LSP + DAP 调试 + Maven / Spring Boot
-- 前置: :Mason 安装 jdtls + java-debug-adapter + java-test + lemminx
-- 外部依赖: mvn / spring（都在 ~/.local/bin）
-- ============================================
-- 三条硬约束：
--   1. java-debug-adapter / java-test 只能作为 jdtls bundle 加载（改完要 :LspRestart）。
--   2. 每个项目独立 -data workspace ⇒ 不走 nvim-lspconfig，用 nvim-jdtls 手动 start_or_attach。
--   3. 必须显式传 on_attach（见 core/lsp_on_attach.lua），否则 Java 缓冲区没有 gd/gh 等导航键。
-- 调试流程：F9 断点 → F5（jdtls 扫 main 类，多个则选）→ dap.run()；导入未完成会自动重试。

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
      local shared_on_attach = require("core.lsp_on_attach")

      -- ── 关闭 Java 缓冲区的 LSP 语义高亮（2026-09-26，B 线排障：写 Java 时代码颜色来回变）──
      -- Neovim 0.12 在 client attach 后会**自动启用**服务器支持的全部 capability
      -- （runtime/lua/vim/lsp/client.lua:1187-1198 遍历 vim.lsp._capability.all），
      -- 而 semantic_tokens 的全局默认是 true（runtime/lua/vim/lsp/semantic_tokens.lua:1011
      -- 的 M.enable(true)）⇒ jdtls 的语义 token 一直是开着的，并以 @lsp.type.* 覆盖
      -- treesitter（优先级 semantic_tokens=125 > treesitter=100，见 vim/hl.lua:12-18）。
      -- catppuccin 把大多数 @lsp.type.* 链回同名 treesitter 组、颜色恰好一致，但
      -- @lsp.type.property → @property（lavender #b4befe）会盖掉 Java 全大写常量的
      -- @constant.java（teal #94e2d5）⇒ 新写的常量会「treesitter 色 → LSP 色」跳一次。
      -- 实测时间序列（打字时同一标识符）：teal → lavender → 灰，见
      -- /tmp/nvim-probe-B/findings-B.md。
      -- 按 buffer 关闭而不是只把 jdtls 的 semanticTokensProvider 置 nil：spring-boot LS
      -- 也声明了 semanticTokensProvider，buffer 级标记（vim.b[bufnr]）能让**之后**才
      -- attach 的 client 同样不再启用（_capability.is_enabled 会读它）。
      -- Java 仍有完整的 treesitter 高亮，不会整片失去颜色。
      local function java_on_attach(client, bufnr)
        vim.lsp.semantic_tokens.enable(false, { bufnr = bufnr })
        shared_on_attach(client, bufnr)
      end

      -- ── DAP 按需加载（2026-09-25，台账 §28.1） ──
      -- 原来这里是 `local jdtls_dap = require("jdtls.dap")` + `local dap = require("dap")`，
      -- 加上下面无条件的 jdtls.setup_dap()，会让**打开任意 .java 文件**就把
      -- nvim-dap + nvim-dap-ui + nvim-nio + nvim-dap-virtual-text 整条链同步拉起来
      -- （实测 startuptime：require('dap') 在 69.8ms 处，整条链 31 个条目 + nio 12 个）。
      -- 现在把 Java 特有的 DAP 接线推迟到"真的要调试 Java"时：下面每个用到 dap 的
      -- handler 先调 ensure_java_dap()（幂等）——它会 require("dap")（lazy 的模块加载器
      -- 顺手把插件装上并跑它的 config）再把 Java 适配器 / 热替换监听注册好。
      -- ⚠ 更正（2026-09-25 审查 F07 实测）：这条"按需"只对 jdtls **没有 attach** 的场合成立。
      --   上游 plugin/jdtls.lua 的 LspAttach 钩子会在 attach 时 require('dap') 并用默认参数
      --   注册 Java 适配器 ⇒ 真机上打开 .java 就会加载 nvim-dap/dap-ui（startuptime 也能看到）。
      local java_dap_wired = false
      local function ensure_java_dap()
        local dap = require("dap")
        if not java_dap_wired then
          java_dap_wired = true
          -- ⚠ 上游 nvim-jdtls 的 plugin/jdtls.lua 有 LspAttach 钩子，attach 时会调
          --   setup._on_attach → add_commands → pcall(require,'dap') + setup_dap({})：
          --   也就是说**打开 .java 时 nvim-dap 就已经被拉起来了**（实测 package.loaded['dap']=true），
          --   本文件顶部"按需加载"的注释只对"没有 attach"的场景成立。
          --   而且那次注册不带 hotcodereplace ⇒ 这里再调 setup_dap 会被上游的
          --   "if dap.adapters.java then return end" 早退，热替换监听永远停在默认值
          --   （实测 BUILD_COMPLETE 触发 0 次 redefineClasses）。要拿到 auto 必须先摘掉旧适配器
          --   （2026-09-25 审查 F07）。
          if dap.adapters and dap.adapters.java then
            dap.adapters.java = nil
          end
          jdtls.setup_dap({ hotcodereplace = "auto" })
        end
        return dap
      end

      -- ── 字段/方法多选：Tab 勾选、CR 确认、Esc 取消 ──
      -- 上游用 vim.fn.input() 收编号：Esc 与空回车等价（无取消通道）、越界编号抛错、交互差。
      -- 换成 snacks picker；pick_many 是同步函数而 picker 只能异步 ⇒「协程让出 + 回调 resume」，
      -- 不在协程里或 picker 创建失败时回退上游实现。
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

      -- ── 构建 / 运行：自动在 mvnw / gradlew / mvn / gradle 之间选择 ──
      local function project_root()
        return vim.fs.root(0, { "mvnw", "gradlew", "pom.xml", "build.gradle", "build.gradle.kts" })
      end

      --- 项目用的构建工具：返回 bin（命令行）+ 显示名 + kind；都没有则 nil
      local function detect_tool(root)
        if vim.uv.fs_stat(root .. "/build.gradle") or vim.uv.fs_stat(root .. "/build.gradle.kts") then
          return vim.uv.fs_stat(root .. "/gradlew") and "./gradlew" or "gradle", "Gradle", "gradle"
        end
        if vim.uv.fs_stat(root .. "/pom.xml") then
          return vim.uv.fs_stat(root .. "/mvnw") and "./mvnw" or "mvn", "Maven", "maven"
        end
        return nil
      end

      --- wrapper 从 git 克隆后常常没有可执行位，先补上
      local function ensure_exec(root, bin)
        if bin:sub(1, 2) == "./" then
          vim.fn.setfperm(root .. "/" .. bin:sub(3), "rwxr-xr-x")
        end
      end

      -- maven_task / gradle_task 任一为 nil 表示该构建工具不支持此操作
      local function run_build(maven_task, gradle_task, extra)
        local root = project_root()
        if not root then
          vim.notify("未找到项目根目录（需要 pom.xml 或 build.gradle*）", vim.log.levels.ERROR)
          return
        end
        local bin, tool, kind = detect_tool(root)
        if not bin then
          vim.notify("项目根目录下既没有 pom.xml 也没有 build.gradle*", vim.log.levels.ERROR)
          return
        end
        local task = kind == "gradle" and gradle_task or maven_task
        if not task then
          vim.notify("当前项目用 " .. tool .. "，该操作没有对应任务", vim.log.levels.WARN)
          return
        end
        ensure_exec(root, bin)

        local cmdline = bin .. " " .. task .. (extra or "")
        -- exec(cmd, num, size, dir, direction, name, go_back) 是位置参数，不是 table
        -- 用 2 号终端，避免和 <leader>tt 的 1 号交互终端抢位置；保留终端焦点查看结果
        require("toggleterm").exec(cmdline, 2, nil, root, "horizontal", "Java 测试", false)
      end

      -- ── Spring Boot 运行：先认主类，再决定跑哪个 ──────
      -- 一个项目多个 main（双进程 Api + Worker）时不能盲跑 spring-boot:run：构建工具会直接报
      -- "Unable to find a single main class from the following candidates [...]"（2026-10-02 实测）。
      -- 所以先扫 src/main/java 下所有带 main 的类：只有一个就直接启动，多个弹选择框。
      -- 扫描与参数解析在 core/java_main.lua（纯逻辑，可 headless 断言）。
      local java_main = require("core.java_main")

      -- 每个主类固定一个终端槽：2 号是 <leader>th 的水平终端，3 号留给 <leader>tv 的垂直终端。
      -- 同一个类永远落同一个槽 ⇒ 换个类启动会开新终端，双进程能同时跑。
      -- ⚠ 不能都挤 2 号：toggleterm 的 exec 同 id 是复用同一个 shell，第二次会把命令行当输入
      --   敲进正在运行的进程里（看着像跑了，其实什么都没发生）。
      local RUN_SLOTS = { 2, 4, 5, 6, 7, 8, 9 }
      local function run_slot(idx)
        return RUN_SLOTS[(idx - 1) % #RUN_SLOTS + 1]
      end

      --- 启动一个主类；idx（1 起）决定终端槽，multi = 这是多入口项目
      local function spring_boot_run(root, main, idx, multi)
        local bin, _, kind = detect_tool(root)
        if not bin then
          vim.notify("项目根目录下既没有 pom.xml 也没有 build.gradle*", vim.log.levels.ERROR)
          return
        end
        local plan = java_main.run_args(root, kind, main.fqcn, multi)
        if plan.note then
          vim.notify(plan.note, vim.log.levels.WARN)
        end
        ensure_exec(root, bin)

        local slot = run_slot(idx)
        local cmdline = bin .. " " .. (kind == "gradle" and "bootRun" or "spring-boot:run") .. plan.args
        -- 该槽里可能还挂着上一次启动的应用：先送一个 Ctrl-C（应用在跑 = 优雅停机，停在提示符
        -- 下只是多一行 ^C），再发命令行 —— 否则第二条命令会被写进旧进程的 stdin。
        -- 于是「同一个类连按两次 <leader>sr」= 重启。
        local ctrl_c = string.char(3)
        -- ⚠ 必须 include_hidden=true：终端被 <leader>th 关掉后只是 hidden，进程还在跑，
        --   而 toggleterm 的 exec 复用同一个 Terminal（terminal.lua:203），漏掉这个 Ctrl-C
        --   就又会把命令行敲进旧进程的 stdin。
        local term = require("toggleterm.terminal").get(slot, true)
        if term and term.job_id then
          pcall(vim.fn.chansend, term.job_id, ctrl_c)
        end
        require("toggleterm").exec(cmdline, slot, nil, root, "horizontal", "Spring: " .. main.simple, false)
        vim.notify("启动 " .. main.fqcn .. "（终端 " .. slot .. "）：" .. cmdline, vim.log.levels.INFO)
      end

      --- <leader>sr 入口：扫主类 → 只有一个直接跑，多个弹选择框
      local function spring_boot_run_pick()
        local root = project_root()
        if not root then
          vim.notify("未找到项目根目录（需要 pom.xml 或 build.gradle*）", vim.log.levels.ERROR)
          return
        end
        local mains = java_main.scan(root)
        if #mains == 0 then
          vim.notify(
            "在 " .. root .. "/src/main/java 下没扫到带 main 的类（只扫 main 源集）",
            vim.log.levels.ERROR
          )
          return
        end
        if #mains == 1 then
          -- 只有一个入口：不打扰，直接启动
          spring_boot_run(root, mains[1], 1, false)
          return
        end
        local info = java_main.main_flag(root)
        local default = info.flag and java_main.default_main(root, info.flag) or nil
        local items = {}
        for i, m in ipairs(mains) do
          items[i] = {
            fqcn = m.fqcn,
            simple = m.simple,
            pkg = m.pkg,
            idx = i,
            slot = run_slot(i),
            is_default = m.fqcn == default,
          }
        end
        vim.ui.select(items, {
          prompt = "选择要启动的主类（共 " .. #items .. " 个入口）",
          format_item = function(m)
            return string.format(
              "%s  %s  [终端 %d]%s",
              m.simple,
              m.pkg ~= "" and m.pkg or "(默认包)",
              m.slot,
              m.is_default and "  ← pom 默认" or ""
            )
          end,
        }, function(choice)
          if choice then
            spring_boot_run(root, choice, choice.idx, true)
          end
        end)
      end

      -- ── 调试：优先用 jdtls 扫出来的主类，扫不到才回退手工输入 ──
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
        -- ⚠ 已有调试会话时 <F5> 必须是"继续"，不能重新选主类再 dap.run()
        --   （同名活动配置在 nvim-dap 里是 restart ⇒ 断点处按 F5 会重启并丢失现场；
        --   全局 <F5> 的语义就是 dap.continue，Java 缓冲区不该不一致。2026-09-25 审查 F06）
        if dap.session() then
          dap.continue()
          return
        end
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

      -- ── 终端测试：运行测试不进入 DAP 调试界面，结果保留在终端中 ──
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

        -- 方法声明最多跨两行：`void foo() throws Exception` + 下一行的 `{`。
        -- 旧实现用单行正则要求 `)` 之后紧跟 `{`，带 throws 的测试方法一律匹配不到，
        -- 循环继续向上搜，命中上方某个旧方法 —— 用户以为在测 A，终端里跑的是 B。
        -- 2026-09-28 实测复现：光标在 testOrderCreation（带 throws）内，跑的是 testAlpha。
        -- 现在改成按「语句」判定：收集到 `)` 括号配平、再容忍一层 throws/泛型里的括号。
        --- 括号是否配平（忽略字符串字面量里的括号）
        local function parens_balanced(s)
          local depth = 0
          local in_str = false
          local escaped = false
          for i = 1, #s do
            local ch = s:sub(i, i)
            if in_str then
              if escaped then
                escaped = false
              elseif ch == "\\" then
                escaped = true
              elseif ch == '"' then
                in_str = false
              end
            elseif ch == '"' then
              in_str = true
            elseif ch == "(" then
              depth = depth + 1
            elseif ch == ")" then
              depth = depth - 1
            end
          end
          return depth == 0
        end

        --- 出现在「返回值」位置说明这不是方法声明（控制流关键字是 %w，会混进 token 列表）
        local JAVA_NON_TYPE = {
          ["if"] = true,
          ["for"] = true,
          ["while"] = true,
          ["switch"] = true,
          ["catch"] = true,
          ["return"] = true,
          ["new"] = true,
          ["else"] = true,
          ["do"] = true,
          ["try"] = true,
          ["assert"] = true,
          ["throw"] = true,
          ["case"] = true,
          ["super"] = true,
          ["this"] = true,
          ["synchronized"] = true,
          ["default"] = true,
          ["instanceof"] = true,
        }

        --- 从「声明 + 可选 body 行」里取方法名；拿不准就返回 nil（宁可报「未找到」，也不要命中错方法）
        local function method_name_from(signature)
          -- 注解与声明同行时放弃（本机风格注解独占一行）
          if signature:match("%s@[%w_%.]+%s") then
            return nil
          end
          local sig = signature:gsub("%s*{%s*$", "")
          -- ① 只认「紧跟在标识符后的整套括号」：head 里不许有 ( ` = ; ，这样
          --    assertTrue(foo(bar)) / x = foo() 这类语句在第一关就被挡掉
          local head = sig:match("^([%w_%s<>%[%],%.%?]+)")
          if not head then
            return nil
          end
          local rest = sig:sub(#head + 1)
          -- ② head 必须以标识符结尾（方法名），且方法名后面直接就是 (
          if not head:match("[%w_]$") or rest:sub(1, 1) ~= "(" then
            return nil
          end
          if not parens_balanced(rest) then
            return nil
          end
          -- ③ 必须像「类型 + 方法名」：至少两个 token，返回值位置不是控制流关键字、也不是泛型
          local tokens = {}
          for tok in head:gmatch("[%w_<>%[%],%.%?]+") do
            tokens[#tokens + 1] = tok
          end
          if #tokens < 2 then
            return nil
          end
          -- 返回值只取泛型前的裸类型名：Map<String, 与 List<Integer>> 都要还原成 Map / List
          local ret = (tokens[#tokens - 1]:match("^([%w_%.]+)") or ""):lower()
          if ret == "" or JAVA_NON_TYPE[ret] then
            return nil
          end
          local name = tokens[#tokens]
          if name:match("^%d") then
            return nil
          end
          return name
        end

        for index = cursor_line, 1, -1 do
          local joined = lines[index]:gsub("/%*.*%*/", " "):gsub("//.*$", "")
          -- 声明被拆成两行时，把下一条非空行（通常就是 `{`）接上来
          if index < #lines then
            local nxt = lines[index + 1]:gsub("/%*.*%*/", " "):gsub("//.*$", "")
            if vim.trim(nxt) ~= "" then
              joined = joined .. " " .. vim.trim(nxt)
            end
          end
          local name = method_name_from(joined)
          if name then
            return selector .. "#" .. name
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

      -- ── 缓冲区快捷键 ───────────────────
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

        -- Spring Boot（2026-10-02 起改成「自动认主类」：多入口项目盲跑 spring-boot:run 会直接报
        -- Unable to find a single main class，逻辑与终端槽见上方 spring_boot_run_pick）
        vim.keymap.set(
          "n",
          "<leader>sr",
          spring_boot_run_pick,
          d("Spring Boot: 运行（自动识别主类，多个则选择）")
        )

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

      -- ── 全局命令（不依赖当前 buffer 是否已触发 FileType） ──
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

      -- ── 启动 / 附加 ────────────────────
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
        config.on_attach = java_on_attach
        -- workspace/executeClientCommand（服务端→客户端请求）：nvim 侧必须自己转发，否则
        -- spring-boot 的 classpath 握手（beans / endpoints / application.yml 补全）永远不执行。
        -- 三条硬规则（完整踩坑记录见技能 nvim-troubleshooting §19）：
        --   ① client 级 handler 会**盖掉** nvim-jdtls 装在全局的转发 ⇒ 自己复刻「client.commands
        --      → 全局 vim.lsp.commands」查找；② 绝不能 `return nil`（runtime 会抛错且请求永不回）；
        --   ③ 查不到实现时：reloadBundles 回**空表**（jdtls 按 `instanceof List` 分流），其余回 `vim.NIL`。
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
              -- ⚠ 必须是「nil, error」两个返回值：runtime 把 handler 的返回值当 (result, err)
              --   （client.lua:1339 → rpc.lua:391 的 status/result/err 三元），只回一个 error 表
              --   会被当成**成功的 result**，服务端永远等不到错误响应（2026-09-25 审查 F08）。
              return nil, vim.lsp.rpc_response_error(vim.lsp.protocol.ErrorCodes.InternalError, tostring(res))
            end
            -- 没实现的命令要给 jdtls 一个「它认得的空结果」：JDTLanguageServer.synchronizeBundles()
            -- 对 _java.reloadBundles.command 的返回值做 instanceof List → loadBundles /
            -- instanceof Map → logError / **其它（含 null）→ logError("Unexpected result …")**，
            -- 所以回 vim.NIL 仍会让它记一条 !MESSAGE 错误（2026-09-25 审查线①用 javap 反编译核实）。
            -- 回**空表**在协议里编码成 JSON `[]` ⇒ 命中 List 且 size=0 ⇒ 什么都不做、也不报错。
            if params.command == "_java.reloadBundles.command" then
              return {}
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
          -- ⚠ 但必须挑**同一个 root** 的客户端（2026-09-25 审查 F05）：原来直接取
          --   get_clients({name="jdtls"})[1]，同时开 A/B 两个 Java 项目时会把 B 的 buffer
          --   挂到 A 的 client 上（跨项目补全/诊断），与"每项目独立 workspace"的承诺冲突。
          local existing
          for _, c in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
            if c.config and c.config.root_dir == root_dir then
              existing = c
              break
            end
          end
          if existing then
            if not (existing.attached_buffers or {})[bufnr] then
              vim.lsp.buf_attach_client(bufnr, existing.id)
            end
            setup_java_keys(bufnr)
            return
          end
          -- ⚠ 一个存活的同 root 客户端都没有（首次启动失败 / 客户端被停 / jdtls 崩了）：
          --   不能继续"已启动过"就 return，否则这个 buffer 永远没有 LSP（F05 触发二）。
          started_bufs[bufnr] = nil
        end
        local client_id = jdtls.start_or_attach(config)
        -- 只有真的拿到 client 才算启动成功，否则下次 FileType 还会重试
        started_bufs[bufnr] = client_id ~= nil
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
