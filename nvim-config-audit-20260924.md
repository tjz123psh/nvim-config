# Neovim 配置审查报告

> **审查对象**：`~/.config/nvim`（Neovim **v0.12.5**，lazy.nvim 38 个插件，46 个文件 4240 行 Lua）
> **审查日期**：2026-09-24　**方式**：4 条并行审查线（结构/正确性 · 跨配置协同 · 使用体验 · UI 视觉）+ 1 条上游兼容性调研 + Lead 逐条交叉复核
> **边界**：全程**只读**，未修改任何配置。审查前后 `git status --porcelain` 一致（仍是开工时那 6 个未提交改动 + 本目录）。
> **注意**：工作树有 **6 个未提交改动**（`lazy-lock.json`、`core/autocmds.lua`、`core/cheatsheet.lua`、`plugins/filetree.lua`、`plugins/lang/java.lua`、`plugins/terminal.lua`），本报告按**当前工作区内容**审查，其中自动保存、Java 增强是"改到一半"的状态。
> **第二轮（同日稍后）**：用户追问「代码操作弹窗的 Enter/Esc 语义、错误显示、leader 提示」，第二轮专门从**插件设置**深挖 → 见文末 **§7–§10**（含可直接粘的 `pick_many` override、诊断配置块、which-key 修正）。
> **实施（同日晚）**：报告里的修复项已按 `nvim-config-preflight-20260924.md` 的分批计划执行完毕，逐条验收证据 + 3 处订正见 **§11 实施记录**。
> **📌 最终状态（2026-09-24 收尾，第一轮）**：**结论汇总 / 已解决 / 未解决 / 事故 / 验收命令 / 回滚点 / 方法论坑** 见 **§19「最终状态与交接」**。
> **📌 换会话/压缩后**：直接粘 **§25「新会话启动提示词」** 那段（自带目标、必读顺序、环境前提、不要重做的事、待办与验收命令）。
>
> **📌 最新（2026-09-25 第十一轮收尾，Agent Teams 并行）**：**工作台账 §23 已 100% 结清** —— ✅ 已解决 50+ / ⏳ 未解决 **0** / 🟡 待决定 **0**（6 项均已拍板落地）/ ❓ 尚未排查 **11/11 已结**。第十一轮把台账最后 6 项 + 历史快照全部做完：**§27.1** bufferline/alpha 并入统一 soft 调色（并加 `padding = 1` 修掉标签栏 1 列偏差）、**§27.2** 历史快照节全部标注结清、**§27.3** 项目历史多实例并发压测**复现出真实截断 bug 并落地修复**（`project.lua` 写守卫：会丢就只追加、绝不截断）、**§27.4** DAP 深挖（空 logMessage 上游语义 + `session:request` 空数组根因）、**§27.5** Neovide 死配置订正、**§27.6** neo-tree 80 列定性（窗口没错位，标签栏 offset 差 1）、**§27.7** 性能压测（无 >500ms 交互停顿）。§26 是第九/十轮记录；**压缩后从 §23 台账 + §27 继续**。
>
> **📌📌📌📌📌📌 第六轮（2026-09-25，用户："再次全面检查并修复"）**：三条只读审查线（视觉一致性 / 正确性与兼容性 / 交互体验与性能）+ Lead 自查；已修：`:JavaBuildProjects`/`:JavaSetRuntime` 在非 Java 会话消失（改 lazy `cmd` 桩 + 友好守卫）、速查面板给 LSP/Java 小节补作用域提示、我上一轮的 `winhl` 单行化。还核对了 checkhealth 的良性噪音、文档↔配置双向一致（键位 116 个、命令 10 个）、blink/neotab 的 Tab 行为。见 **§22**。
>
> **📌📌📌📌📌 第五轮（2026-09-25，用户截图："还是有些地方没有做到位的"）**：把最后两个"没跟上"的面板并入同一套色 —— `<leader>hk` **速查面板**（自绘浮窗：边框/标题/底色/顶行色块/按键色全改）与**向导卡片**（soft 下整套 `Wiz*` 走皮肤、呼吸边框改灰蓝）；顺手把 picker 输入行与列表面板统一成同一种底色。见 **§21.6**。
>
> **📌📌📌📌 第四轮（2026-09-25 早，用户："基本上所有的都换成这种风格"）**：紧凑风格**全局化**（所有 picker 走 `picker_compact` 预设）、补齐边框/标题高亮组（`SnacksTitle` 等，此前标题吃默认红）、修好 `:PickerSkin pink`（原来切了没反应）、并**切断向导对共享高亮组的永久污染**（跑过向导后所有 picker 变粉的根源）。见 **§21.5**。
>
> **📌📌📌 第三轮（2026-09-24 深夜，用户截图："不是很好看，好难看"）**：`:Projects` 列表**观感重做**（图标 + 名字/父目录分色 + 宽度贴合内容 + 当前项目置顶徽标），过程中**第二次遇到项目历史被清空**——这次定位到 project.nvim 的截断+异步竞态根因，并落地"只追加副本 ∪ 并集 ∪ 回填"三层保护（截断成 0 字节也能自愈）。详见 **§21**。
>
> **📌📌 第二轮（同日深夜，用户："根据文档继续处理问题"）**：§19.3 的遗留项又结掉 10 项（springboot 懒加载、lang 加载失败提示、状态栏死配置、lemminx filetypes、前端解析器、autosave 全缓冲区、诊断内部码、Comment.nvim → 内置 gc、卫生项），并新增停维护插件调研；**最新状态与验收清单见 §20**（与 §19.3 冲突时以 §20 为准）。

---

## 0. 速览

**总评：健康。0 个 P0**——启动零报错、38 个插件与 lock 完全一致、11 个 LSP server 全部可连、无任何 0.12 弃用 API、启动 57–67 ms（无单项超 100 ms）。

问题集中在三类：

| 类别 | 代表 |
|---|---|
| **静默退化**（不报错但功能没生效） | 状态栏主题加载失败退化成黑带；lualine 的 neo-tree 扩展是死配置 |
| **一处在错误路径上冻结** | Spring 向导创建项目用同步 `:wait()`，事件循环整段冻结 |
| **文档与配置互相打架** | `:JavaInit` 幽灵命令；Java 键位作用域；Lua 缩进 2 vs 4 格；插件表缺 4 个文件 |

### 修复清单（按性价比排序）

| 严重度 | 问题 | 位置 | 一句话修法 |
|---|---|---|---|
| **P1** | 状态栏主题静默退化成黑带 | `plugins/theme.lua:25` | `lualine = true` → `lualine = { enabled = true }` |
| **P1** | 向导创建项目冻结事件循环 | `core/spring_wizard.lua:876-878` | 用文件内已有 `bridge` 改异步 |
| **P1** | `:JavaInit` 幽灵命令（6 处文档介绍，实际不存在） | 文档 5 份文件 | 文档删掉，或补命令 |
| **P1** | Java 构建键只在 .java 缓冲区存在，文档当全局承诺 | `plugins/lang/java.lua:304-365` | 构建类键改全局注册 |
| **P1** | `stylua --check` 5 个文件不过（违反本机"完成标准"） | 见 §1.5 | `stylua .` 后重跑 `--check` |
| **P1** | which-key 缺 `<leader>J/m/R/G` 四个分组（20+ 条键无入口） | `plugins/whichkey.lua:14-24` | 补 4 行 group |
| **P1** | Lua 缩进实际 2 格，文档写"统一 4 格" | `stylua.toml` + 文档 | 二选一并同步（改配置或改文档） |
| **P1** | `<Tab>` 进入插入模式后被 neotab 接管，cheatsheet 的片段跳转承诺失效 | `neotab.lua:10-12` + `cheatsheet.lua:91` | 明确取舍后改文档或改键 |
| P2 | `lsp.log` 27 MB 且永不轮转（"防膨胀"注释与事实相反） | `core/options.lua:65` | `truncate -s 0` + 定期清理 |
| P2 | 浮窗底色三套并存（#181825 / #000000 / 透明） | `theme.lua:15`、`noice.lua:17` | 统一 `float.transparent` 或对齐 `background_colour` |
| P2 | noice 命令行弹窗固定 82 列宽，80 列终端左边框出屏 | `plugins/noice.lua:30-39` | 删掉写死的 `width = 78` |
| P2 | 首个 Java 缓冲区 jdtls / spring-boot 各 start 两次 | `lang/java.lua:398-412` | FileType 回调加 buffer 守卫 + 传 `args.buf` |
| P2 | 另外约 10 条一致性与卫生问题 | 见 §2 | — |

**动手顺序建议**：① 上面 5 条"一行改"（10 分钟）→ ② `stylua` 全树格式化 + 文档同步（半小时）→ ③ 需要设计的：向导异步化、Java 键位作用域、自动保存语义（见 §2/§3）。

---

## 1. P1：必修（8 条）

### 1.1 状态栏主题静默退化：catppuccin 的 lualine 主题加载失败，退化成 `"auto"`
- **位置**：`lua/plugins/theme.lua:25`（`lualine = true`）
- **证据**（Lead 独立探针复现）：`require("lualine").get_config().options.theme` → `"auto"`；`pcall(require, "lualine.themes.catppuccin-mocha")` → **false**，错误 `catppuccin/utils/lualine.lua:55: attempt to index local 'overrides' (a boolean value)`；实际高亮 `lualine_c_normal = { bg = 0 }`（**纯黑 #000000**）、`lualine_a_normal = { bg=#313244, fg=#878787 }`，而主题本意是 `a = { bg=#89b4fa, fg=#181825 }`、`c bg = NONE`。
- **影响**：每次启动状态栏中段都是一条**不透明纯黑色带**（编辑器本身是透明的），模式块是灰字灰底而非 catppuccin 蓝；`statusline.lua:12` 的 `pcall` 把错误吞了，所以从不报错。
- **修法**：`lualine = { enabled = true },`（catppuccin 的 `integrations.lualine` 是 override 表；预验证：改后 `normal.a = { bg="#89b4fa", fg="#181825", gui="bold" }`，不再抛错）。
- **置信度**：高（Lead 复现）。

### 1.2 Spring 向导创建项目用同步 `:wait()`，事件循环整段冻结
- **位置**：`lua/core/spring_wizard.lua:876-878`
- **证据**（Lead 独立复现）：`vim.system({'sleep','0.6'}):wait()` 期间，150 ms 的 timer **不触发**、无重绘无输入 → `elapsed_ms 602  timer_fired false`。同文件 38-39 行注释却写着"旧实现同步等待、弱网时冻结 25 秒，已改异步"——只有元数据请求改了，**创建这一步漏了**。
- **影响**：点"确认创建"后到 `spring init` 返回前 Neovim 完全无响应（弱网数十秒），且没有进度提示。
- **修法**：复用文件内已有的 `bridge(fn)` 包装成回调式 `vim.system(argv, {...}, function(r) vim.schedule(...) end)`，按 `res.code` 分支（原 883-886 行逻辑不变）。

### 1.3 `:JavaInit` 是幽灵命令：6 处文档介绍，配置里不存在
- **位置**：文档 `~/md/nvim/{nvim命令.md:96, nvim快捷键.md:172, nvim自定义命令.md:12,22, nvim配置架构.md:40, 从零搭建依赖清单.md:39}`
- **证据**：`grep -rn 'JavaInit' ~/.config/nvim --include='*.lua'` → 0 命中；运行时 `vim.fn.exists(':JavaInit')` → **0**（同批 `:R`/`:A`/`:JavaRun` 全为 2）。
- **影响**：照文档敲 `:JavaInit` 直接 `E492`。
- **修法**：推荐**删文档**（功能已被 `:JavaBuildProjects` + jdtls 自动 root 取代）；若确实需要，在 `core/commands.lua` 补一个写最小 `pom.xml` 的命令。

### 1.4 Java 构建/运行键是 buffer-local，非 Java 缓冲区全部消失
- **位置**：`lua/plugins/lang/java.lua:304-365`（`{ buffer = bufnr }`）；文档 `nvim快捷键.md:144-151` 把它们列在全局表里
- **证据**（Lead 复核）：普通文件 `<leader>mc / sr / mb = NIL`；打开 `A.java` 等 jdtls attach 后 = **YES**。注意范围修正：`<leader>ca`/`<leader>rn` 是 **LSP 通用键**（任何 attach 了 LSP 的 buffer 都有，W3 已单独记录），真正只在 Java 里的是一组构建/Maven/测试键。
- **影响**：在 pom.xml/yml/非 Java 文件里按 `<leader>mc` 编译、`<leader>mb` 重导项目 → 静默无反应，which-key 的 `<leader>m` 前缀也不出现。
- **修法**：构建类（`mc/mt/mp/mi/mn/ml/mb/sr`）改用全局 `vim.keymap.set`（内部已有 `project_root()` 兜底报错），只把运行/调试类留在 buffer-local。

### 1.5 `stylua --check .` 有 5 个文件不通过
- **位置**：`lua/core/cheatsheet.lua`、`lua/core/lazy.lua`、`lua/core/spring_wizard.lua`、`lua/plugins/lang/java.lua`、`lua/plugins/lang/springboot.lua`
- **证据**（Lead 复核）：`cd ~/.config/nvim && stylua --check .` → 退出码 1，5 条 `Diff in ...`（例：`spring_wizard.lua` 注释前空格、`if ... then return end` 需折行）。
- **影响**：本机 `nvim-config` 技能的"完成标准"明确要求全树通过；另外这些文件一旦被 conform 在保存时格式化，会产生与本次修改无关的大段 diff。
- **修法**：`stylua .` 后重跑 `--check`（本次审计只读，未执行）。

### 1.6 which-key 缺 `<leader>J` / `m` / `R` / `G` 四个分组
- **位置**：`lua/plugins/whichkey.lua:14-24`（只有 b/c/d/f/h/r/s/t/w 九个组）
- **证据**：这几个前缀是真实键位——全局实测已注册 `sp/sP/Gc/Ge/Gi/Gr`，jdtls attach 后 `Jd/Jt/JT/Jg/JG/mc…ml/mb/Rv/RV/Rc/Rm/ot/co/sr` 全部存在；但 which-key spec 里没有它们的 group。
- **影响**：按 `<leader>` 后 `J`/`m`/`R` 只看到无标题的裸键列表，找不到"Maven 生命周期""Java 测试""重构"在哪。
- **修法**：补 4 行 group（`<leader>J` = Java 主类/测试，`<leader>m` = Maven/Gradle，`<leader>R` = 重构/提取，`<leader>G` = 生成 Java 类型）。

### 1.7 Lua 缩进实际 2 格，与架构文档"统一 4 格"相反
- **位置**：`stylua.toml:1-4`（`indent_width = 2`）、`lua/core/autocmds.lua:14-15`；文档 `nvim-config/references/architecture.md:167`（原写 130，2026-09-24 复核订正）
- **证据**：`vim.bo.shiftwidth, tabstop` = `2, 2`；C++/Java/Rust 是 4 格，Lua 是 2 格。
- **影响**：按文档预期写 4 格 → 一存盘被 stylua 改回 2 格，反复 diff。
- **修法**：要 4 格就改 `stylua.toml` + `autocmds.lua` 并全树格式化；要 2 格就修文档第 130 行。

### 1.8 `<Tab>` 进入插入模式后被 neotab 接管，cheatsheet 的片段跳转承诺失效
- **位置**：`lua/plugins/neotab.lua:10-12`（`event = "InsertEnter"`）、`lua/plugins/completion.lua:19-20`（blink `["<Tab>"] = { "accept", "snippet_forward", "fallback" }`）、`lua/core/cheatsheet.lua:90-91`
- **证据**（Lead 复核 + W3）：启动态 `<Tab>` 的 desc = `vim.snippet.jump if active, otherwise <Tab>`（Neovim 默认）；触发 `InsertEnter` 后 desc 变成 **nil**（映射易主为 neotab 的 `<Plug>(neotab-out)`，无 desc）；`<S-Tab>` 仍是 snippet_jump。
- **影响**：在 `()`/`{}`/`""` 内按 Tab 是"跳到大括号外侧"而不是补全接受/占位符前进；cheatsheet"Tab / Shift-Tab 前后跳转片段占位符"只剩一半成立。
- **修法**：二选一——保留 neotab 就把 cheatsheet 改成"Shift-Tab 跳上一占位符；Tab 由 neotab 接管"；要让 blink 优先就把 neotab 的 tabkey 换掉。**补一句实机确认**：打开补全菜单后按 Tab 到底谁赢，headless 测不到（见 §6.1）。

---

## 2. P2：应修（一致性与卫生）

| # | 问题 | 位置 | 证据要点 | 修法 |
|---|---|---|---|---|
| 2.1 | **`lsp.log` 27 MB 且永不轮转**，"防止日志膨胀"注释与实际相反 | `core/options.lua:65` | 27,296,521 B / 92,225 行 / 91,468 条 ERROR；Neovim 运行时只在 **>1 GB** 时警告、**从不轮转**（`runtime/lua/vim/lsp/log.lua:116`）；ERROR 级别下正文仍在涨，因为**服务器 stderr 一律按 ERROR 记录**（clangd 的 `I[...]`、java 的 WARN 都被当 ERROR 写进来） | `truncate -s 0 ~/.local/state/nvim/lsp.log`；想长期抑制用 `set_level(OFF)` 或定期清理（**不要**改回 WARN——那会记得更多） |
| 2.2 | **浮窗底色三套并存** | `theme.lua:15`、`noice.lua:17`、`spring_wizard.lua:236` | 实测 `NormalFloat bg=#181825`（不透明）、`NotifyBackground bg=#000000`、`WizBg`/`SnacksPicker` 透明；catppuccin 默认 `float.transparent=false` 而配置没设 | 统一透明：`theme.lua` 加 `float = { transparent = true }`；或保留不透明则把 `noice.lua:17` 的 `background_colour` 改成 `#181825` |
| 2.3 | **noice 命令行弹窗在 80 列终端溢出** | `plugins/noice.lua:30-39` | 深合并后实际 `size={height=auto,min_width=60,width=78}` + `border.padding={0,1}`（Lead 复核）→ 总占 82 列；实测 columns=80 时边框窗 `col=-1`（左边框出屏），72/60 列时内容窗 `col=-3/-9`。noice 只在 `width=="auto"` 时才用 `max_width=columns-4` 夹 | 删掉 `width = 78`（保留默认 auto + min_width），或写 `max_width = 76` |
| 2.4 | **`extensions = {"neo-tree"}` 是死配置 + 文件树里整条状态栏变空** | `plugins/statusline.lua:19,53` | lualine 先查 `disabled_filetypes` 直接 return；实测 filetype=neo-tree 时 `statusline()` → **nil**，且 `globalstatus=true`（`laststatus=3`）⇒ 整条状态栏空白（Lead 复核） | 从 `disabled_filetypes` 删掉 `"neo-tree"`，或从 `extensions` 删掉 |
| 2.5 | **首个 Java 缓冲区 jdtls / spring-boot 各 start 两次**（历史 §5.4 同类复发） | `lang/java.lua:398-412` | Lead 复核：`LSP_START_CALLS=4`（jdtls×2 + spring-boot×2），靠 `vim.lsp.start` 的 name+root_dir 去重才没起双进程（`CLIENTS=2`）；FileType 回调没有 buffer 级守卫、用的 `0` 而非 `args.buf` | callback 加 `started[args.buf]` 守卫并传 `args.buf` |
| 2.6 | **`spring-boot.nvim` 的 `lazy = false` 让 `ft` 成死配置，并把 jdtls/DAP 栈拖进启动期** | `lang/springboot.lua:13-14`、`lang/cpp.lua:36`、`lang/rust.lua:22` | 启动即加载 **20/38**（含 nvim-jdtls、nvim-dap、dap-ui、virtual-text、nio）；`ft` 声明失效；裸 `opts` 的 nvim-dap 没有触发器 | 删 `lazy = false` 只留 `ft`；DAP 那几个 spec 加 `ft` 或改 `opts = function`。**注意**：这不是性能事故（总启动 57–67 ms），是语义错乱 |
| 2.7 | **`lang/init.lua` 用 pcall 静默吞掉整门语言的加载错误** | `lua/plugins/lang/init.lua:9-28` | 该文件是 `lang/*.lua` 的**唯一入口**，任一模块加载失败 ⇒ 对应语言 spec 整体消失、零提示 | `if not ok then vim.notify("plugins.lang.X 加载失败: "..err, ERROR) end` |
| 2.8 | **自动保存只写当前 buffer**；退出时后台被改的 buffer 仍弹确认 | `core/autocmds.lua:47-65`（未提交改动） | 两个都改过的 buffer 执行 `:qa` → 仍出"将改变保存到 … 吗？"；另外每个 `BufLeave` 都会走一遍 conform 格式化链（含 Java 的 JVM 开销） | `QuitPre/VimLeavePre` 分支遍历 `nvim_list_bufs()` 逐个保存；把该功能与 `vim.g.core_autosave` 开关写进 cheatsheet |
| 2.9 | **`checkhealth vim.lsp` 常驻 `Unknown filetype 'xsl'`** | `plugins/lsp/init.lua:70` | lemminx 默认 `filetypes = { 'xml','xsd','xsl','xslt','svg' }`，而 `xsl` 未在 `core/filetypes.lua` 注册 | `lemminx = { filetypes = { "xml","xsd","xslt","svg","dtd" } }`，或在 filetypes.lua 注册 `xsl` |
| 2.10 | **文档同步链三处滞后** | `~/md/nvim/*` | ① 插件表缺 `snacks.lua`/`lang/springboot.lua`/`mason-tool-installer.lua`/`lang/init.lua`，总数写 34（实际 38）；② "Java 保存不自动格式化"（`format.lua:14-23` 有意为之）未写进任何文档；③ `<leader>sp/sP` 是**全局**键却只写在 cheatsheet 的 Java 区 | 三处各补一句（这是本机"必须同步"的硬约定） |
| 2.11 | ~~空目录 `site/pack/core/opt` 触发 vim.pack 警告~~ **【2026-09-24 实施时订正：不是缺陷】** | 系统目录（非配置） | 我删掉后用 `find` 复核发现：**该目录由 nvim 0.12 内置的 `vim.pack` 每次启动自动重建**（删完再启一次 nvim 就回来了）⇒ 那条 "Lockfile is absent" 警告对**任何不使用 vim.pack 的配置都是常态**，不是残留、也清不掉 | **不要处理**。想彻底消掉只能给 vim.pack 建 lockfile 或改用 vim.pack，都不值得；在文档里说明这是 noise 即可 |
| 2.12 | **treesitter 缺前端相关解析器** | `plugins/treesitter.lua:17-37` | `:checkhealth vim.treesitter` 报 `Missing Treesitter languages: latex, norg, scss, svelte, tsx, typst, vue`；配置的 `ensure_installed` 与自身 `highlight_filetypes` 是对齐的（19/19），但**不含 tsx/vue/svelte** | 若确实写前端：把 `tsx/vue/svelte/scss` 加进 `ensure_installed`；latex/norg/typst 可忽略 |
| 2.13 | **上游已停维护的依赖**（详见 §4.3） | `project.nvim`、`dressing.nvim`、`Comment.nvim`、`bufferline.nvim`、`toggleterm.nvim` | project.nvim 默认分支最后提交 **2023-04-03**（42 个月；API `pushed_at` 是 2024-08-12）；dressing.nvim **仓库已归档**（Lead 复核 API `archived=true`） | 中期替换：project → `vim.fs.root()` + 自维护历史；dressing → snacks/原生；Comment → mini.comment |

---

## 3. 建议（可选优化）

1. **`core/lazy.lua:34-37` 的 `defaults = { lazy = false, version = false }` 是冗余且误导**——lazy.nvim 默认值就是这两个（Lead 已核源码：`plugin.lua:235-242` 的 `or` 链里 `defaults.lazy=false` 会被 `event/keys/ft/cmd` 覆盖，所以它**不会**破坏懒加载）。删掉或把注释改成"与默认值相同，仅显式声明"。
2. **向导第 10 步"包名"缺校验**（`spring_wizard.lua:805`，对比 789/795/801 三步都有 `valid_segment`）：非法包名会交给 `spring init`。
3. **启动页 logo 阈值偏大**：`dashboard.lua:25` 用 `columns >= 68`，实测 logo 宽 52 → 改成 58 可救 58–67 列的窗口。
4. **`application.properties` / `*.gotmpl` 没有 devicon 图标**（`get_icon` 返回 nil，而同表 790 条里 build.gradle/docker-compose.yml/mdx 都有）——这份配置主打 Java/Spring，恰是高频文件；加一次 `nvim-web-devicons.setup({ override = {...} })`。
5. **浮窗边框三种颜色**（蓝 `#89b4fa` / 淡紫 `#b4befe` / 粉 `#f38ba8`）：保留向导的粉作特色，其余统一即可（属取舍，不改也不算缺陷）。
6. **catppuccin integrations 可补 `flash`/`snacks`/`notify`**：实测当前取值已正确（差异极小），等真开了 snacks 的 indent/dashboard 再补。
7. **两个 Spring 插件功能重叠**：`spring-boot.nvim`（JavaHello，活跃、要求 0.12+）与 `springboot-nvim`（elmcgill，最后提交 2025-10-07）；建议只留其一。
8. **`:A` 命令的 desc 有编码残留**（`nvim_get_commands()` 里含替换字符，功能不受影响）；**`~/.config/kitty/kitty.conf:14`** 残留对话式注释 `# 加上你之前需要的行为设置`——建议清理。
9. **DAP 面板固定 45 列**（`plugins/dap/init.lua:47-65`）在 80 列终端下是否够用，值得在真实调试会话里看一眼（本报告无法验证）。

---

## 4. 兼容性与上游事实（外部调研，2026-09-24 抓取）

### 4.1 三个"别动"的锁（动了会炸）

| 项 | 事实 | 来源 |
|---|---|---|
| `nvim-treesitter` **必须留在 `main`** | `master` 已冻结且 README 明写 **"Neovim 0.12 is not supported"**；`main` 是面向 0.12 的重写（模块 `nvim-treesitter.configs` → `config`，用 `require("nvim-treesitter").setup{}`）。本机在 main（f603a2f4）且配置写法正确 | [master README](https://github.com/nvim-treesitter/nvim-treesitter/blob/master/README.md) · [main README](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md) · [#8424](https://github.com/nvim-treesitter/nvim-treesitter/issues/8424) |
| `blink.cmp` **保持 `version = "v1.*"`** | main 分支已是 V2 且含破坏性变更（需另装 blink.lib）；本机锁 v1 是安全侧 | [main README](https://github.com/Saghen/blink.cmp/blob/main/README.md) · [#2394](https://github.com/saghen/blink.cmp/pull/2394) |
| `lang/java.lua:128-136` **root 预解析成字符串不要改回函数** | 0.12 里函数式 `root_dir` **只在 `vim.lsp.enable()` 路径被求值**，而 nvim-jdtls 走 `vim.lsp.start()` | [lsp.lua L559](https://github.com/neovim/neovim/blob/v0.12.0/runtime/lua/vim/lsp.lua) · [jdtls setup.lua#L424](https://github.com/mfussenegger/nvim-jdtls/blob/master/lua/jdtls/setup.lua) |

### 4.2 Neovim 0.12 实务

- **0.12 没有移除任何本机插件依赖的 API**（`vim.tbl_islist`/`tbl_flatten`/`vim.lsp.start_client`/`buf_get_clients`/`vim.diff` 都还在，仅 deprecated 警告）；真移除的是 `vim.diagnostic.disable()/is_disabled()`、`Query:iter_matches()` 的 `"all"`，以及 `get_parser()` 不再抛错。
- 被广泛误传的"`vim.opt`/`vim.o` 展开 `~`"只在 **0.13-dev（未发布）**；`vim.lsp.config/enable` 是 **0.11** 新增——本机早已迁移（`lsp/init.lua:114-115`）。
- 本机 providers 全禁用（`loaded_*_provider = 0`），0.12 的 provider 变化无影响。
- 本机 `:checkhealth vim.deprecated` → **No deprecated functions detected**。

### 4.3 停维护清单（判据：默认分支最后提交）

| 插件 | 最后提交 | 月数 | 依据 |
|---|---|---|---|
| project.nvim | 默认分支 2023-04-03（GitHub API `pushed_at` 2024-08-12，指任意分支最后一次推送） | ~42 | [repo](https://github.com/ahmedkhalf/project.nvim) · Lead 复核 API：`archived=false`、`open_issues=96`（另有 issue [#188](https://github.com/ahmedkhalf/project.nvim/issues/188) 报 0.12 弃用警告） |
| Comment.nvim | 2024-06-09 | ~27.5 | [repo](https://github.com/numToStr/Comment.nvim) |
| bufferline.nvim | 2025-01-14 | ~20 | [repo](https://github.com/akinsho/bufferline.nvim) |
| dressing.nvim | 2025-02-12（**已 archived**） | ~19 | [repo](https://github.com/stevearc/dressing.nvim) |
| toggleterm.nvim | 2025-03-09 | ~18.5 | [repo](https://github.com/akinsho/toggleterm.nvim) |

临界（12–18 个月）：nvim-dap-virtual-text、neotab.nvim、nvim-notify、springboot-nvim、which-key.nvim、noice.nvim。
**未确证**：noice/snacks/which-key/nui 是否"官方支持 0.12"（README 只给最低版本）；nvim-jdtls 无 0.12 支持声明。

---

## 5. 已核实没问题的（避免下一轮重复劳动）

| 领域 | 结论 | 验证方式 |
|---|---|---|
| 启动 | 零 stdout/stderr 报错、`:messages` 空；**启动 57.4 / 59.1 / 67.3 ms**（Lead 复测，W3 六次中位 61.5），最贵单项 `require('core.lazy')` self 21–22 ms，**无单项超 100 ms** | `nvim --startuptime` ×9、`nvim --headless +qa` |
| 插件完整性 | lazy-lock 38 ↔ 已装 38，双向差集为空，无多余/缺失 | python 对比 lock 与 `~/.local/share/nvim/lazy` |
| 弃用 API | `goto_prev/next`、`start_client`、`nvim_*_set_option`、`formatting_sync` 命中 0；`vim.diagnostic.jump` 已用 | grep + `checkhealth vim.deprecated` |
| LSP | 11 个 server 全部 enable；clangd 用新签名；mason-lspconfig 先 setup mason（历史 §1.3.1/§1.4 未复发）；**7/7 语言在真实临时项目里真连上**（go/java/cpp/rust/yaml/json/html） | 造 /tmp 项目 + `vim.lsp.get_clients()` |
| Mason | `ensure_installed` 11/11、tool-installer 10/10 全部 INSTALLED；3 个"无二进制"的包本就只提供 jar | `ls mason/packages`、`realpath mason/bin/*` |
| 环境协同 | `wl-copy` 实测往返成功、`clipboard=unnamedplus` 生效；JetBrainsMono Nerd Font 命中；kitty 真彩/透明三方方向一致；toggleterm/`:JavaRun` 走 bash 是历史 §6.1 的**有意**修复（非回归） | `wl-copy`/`wl-paste`、`fc-match`、`checkhealth vim.provider` |
| 键位 | 29 条全局 leader 键与 cheatsheet/which-key 声明一一对应，**没有"写了却没注册"的全局键**；`J/K/3J`、可视 `Vj2J/VjK` 行为与 desc 一致且**一次 `u` 可完整撤销**；`<C-s>` 插入模式保存可用；历史坑 §2（jk 冲突）、§3（双空格延迟）未复发 | 8 模式 `nvim_get_keymap` 导出 + `nvim_feedkeys` 实跑 + `undotree()` |
| 格式化 | stylua/clang-format/google-java-format/rustfmt 全部 `available`；lua/rust/cpp/go 保存即格式化；Java 按设计跳过；`/tmp` 下 C++ 显示 2 格是 clang-format 向上查找的假象 | 真跑 5 种文件保存 + `conform.get_formatter_info` |
| UI | `winborder=rounded` 且 11 处 border 全圆角；bufferline 在 30–200 列均不溢出；lualine 靠 `%<` 优雅截断；bufferline 用 catppuccin **special** 主题；ibl v3 不需要 `listchars`；alpha 中文按钮按显示宽对齐；向导自定义高亮组真实存在且随 ColorScheme 重建 | 运行时取值 + `nvim_bufferline()`/`nvim_eval_statusline` 测宽 |
| 结构 | 启动即加载的 20 个插件**全部**是 `lazy = false` 或其必要依赖，无意外项；snacks 冲突模块（notifier/dashboard/terminal/input/…）已显式关闭；autocmd 全部带 group；`:R` 带空格路径可用；`nvim_create_user_command` 重复注册安全 | 运行时枚举 + 源码核对 |
| 历史坑回归检查 | §6.3（lualine UIEnter）、§10.2/§10.3/§10.7（conform 事件/超时/优先级）、§10.8（alpha cond）、§10.9（treesitter 的 mason 时序）、§10.10（cheatsheet 宽高钳制）**均未复发** | 逐条对照历史文档 + 实测 |

---

## 6. 需要实机/人工确认的（headless 测不到）

1. **补全菜单展开时 `<Tab>` 到底谁赢**：打开 lua 文件输入 `pri`，等菜单出现按 Tab，看是"接受补全"还是"跳出括号"。
2. **向导的交互死锁风险**：`M._running` 只在 `pcall(flow)` 正常返回时复位——若 dressing 的输入框被异常关闭导致回调不触发，向导会永久卡住（需 TUI 下用 `Ctrl-C`/`:q` 关输入框验证）。
3. **向导卡片在终端 resize 后的布局**：`card_w()` 只在打开时求值，改窗口大小不会重算。
4. **`:Projects` 切换项目后 neo-tree 是否真的跟随**（历史 §10.1.1 的旧伤，静态逻辑自洽但无法 headless 复现）。
5. **DAP 全链路**：C++/Java 各跑一次调试；确认"必须先 F9 设断点"、dap-ui 45 列布局在 80 列下是否够用。
6. **kitty 实际渲染的透明观感**：确认 `term_colors`/`background_opacity 0.8` 下浮窗（2.2）与状态栏（1.1 修好后）的实际观感。
7. **toggleterm 浮动终端底色**：`border=rounded, winblend=0, shading_factor=2` 在透明 Normal 下是否如注释所愿。
8. **按键到响应的延迟**：headless 无法测量"体感卡顿"；启动耗时不代表交互延迟。

---

## 附录 A：审查方法与证据来源

- **4 条并行审查线**（Agent Teams，各自独立发现文件、互不重叠）：结构/正确性 → `w1-structure.md`；跨配置协同/兼容 → `w2-integration.md`；体验/键位/性能 → `w3-ux.md`；UI/视觉 → `w4-visual.md`。
- **1 条上游调研**：`x-web-research.md`（38 个插件的活跃度/0.12 兼容性、0.12 破坏性变更、catppuccin integration 覆盖，全部带来源 URL）。
- **Lead 交叉复核**（本报告中标"Lead 复核"的条目均为复现）：`stylua --check`、`checkhealth` 全文、`lsp.log` 体量与运行时轮转源码、`lualine` 主题加载失败与高亮取值、neo-tree 下 `statusline()==nil`、noice 深合并几何、`vim.system():wait()` 冻结计时、`vim.lsp.start` 计数（LSP_START_CALLS=4）、Java/非 Java 缓冲区键位、`<Tab>` 归属漂移、lemminx `xsl`、`site/pack/core/opt` 空目录、启动耗时基线。
- **驳回的疑似问题（误报记录）**：① "snacks `bufdelete` 是错别字"——`Snacks.bufdelete` 是真实模块，**不成立**；② "lsp.log 靠 100 KB 轮转、设 ERROR 后失效"——运行时**只有 >1 GB 的警告、没有轮转**，正确结论见 §2.1；③ "`defaults.lazy = false` 导致插件被 eager 加载"——lazy 的 `or` 链会让触发器优先，**不成立**（真实原因是各 spec 的 `lazy = false` 与裸 `opts`）；④ "`/tmp` 下 C++ 缩进只有 2 格"——clang-format 只向上层目录查找，属假象。
- **原始分线报告**已归档：`~/backups/nvim-audit-raw-20260924.tar.gz`（含 4 份分线报告 + 上游调研全文 + 本次审查的辅助输出）。

## 附录 B：本次审查**没有**改动任何配置

审查前后 `git status --porcelain` 一致：

```
 M lazy-lock.json          M lua/core/autocmds.lua      M lua/core/cheatsheet.lua
 M lua/plugins/filetree.lua  M lua/plugins/lang/java.lua  M lua/plugins/terminal.lua
```

以上 6 个 `M` 是**审查开始前就存在**的未提交改动（其中自动保存、Java 增强是本次审查的对象之一），不是审计产生的。
---

# 第二轮：从插件设置深挖（代码操作 / 错误显示 / leader 提示）

> **触发**：用户看了截图（jdtls 构造器字段选择浮窗）后追问三点——①「按 Enter 是选中、Esc 是完全确认，体验不好」②「错误显示有没有问题」③「leader 后的快捷显示有问题」，并要求从**插件设置**入手。
> **方式**：3 条并行审查线（代码操作/输入链路 · 错误与诊断显示 · leader 提示+插件设置扫描）+ 1 条上游调研 + Lead 逐条实证。**全程只读**，未修改任何配置；原始分线报告归档在 `~/backups/nvim-audit-raw2-20260924.tar.gz`。

## 7. 你的三个问题，逐条回答

### 7.1 「Enter 选中、Esc 完全确认」——根因不在 dressing 也不在 noice，是 jdtls 自己

**那条浮窗的真实身份**：`~/.local/share/nvim/lazy/nvim-jdtls/lua/jdtls/ui.lua:61-111` 的 `M.pick_many`。它用 **`vim.fn.input()`** 把编号清单塞进多行 prompt，然后 `while true` 循环：

| 你按的键 | 真实行为 |
|---|---|
| `1` + Enter | 勾选第 1 项，重新弹出清单（该项后面多一个 `*`） |
| 空 Enter | 结束，把**已勾选的**交给 code action |
| **Esc** | **与空 Enter 完全相同**（`input()` 返回同一个空串）⇒ **不是取消，而是"按当前勾选继续"** |
| `<C-c>` | 抛 `Keyboard interrupt`（唯一的"中止"，但表现为报错） |
| 输入越界编号（3 项时按 `9`） | **抛 Lua 错误**（`ui.lua:50`），整个 code action 报错收场 |

- **证据**：Lead 在 0.12.5 实测 `input()` 的返回矩阵（输入 `ab` 后 Esc → `""`，不是 `"ab"`）；A 线用 pty 送**真按键**跑真 `pick_many` 得到同样结论（`ITER1 ANSWER="1" / ITER2 ANSWER=""`）。
- **更糟的一点**：`jdtls.lua:138` 字段选择路径**不检查返回值**（父类构造器那条 `:126` 反而有 `return` 守卫）⇒ Esc 之后照样执行 `java/generateConstructors`。
- **上游**：这正是 [nvim-jdtls#358](https://github.com/mfussenegger/nvim-jdtls/issues/358)「using the command line to select them is pretty uncomfortable」（2022-10 开、2026-01 关闭未修，async 化 PR 未合），所以**别等上游**。
- **noice 只是渲染者**：标题 `Input` 由 noice 生成（`noice/config/cmdline.lua:37`，取 kind 名首字母大写），边框是 `NoiceCmdlinePopupBorderInput`（实测 **#B4BEFE 淡蓝**）。**`dressing.lua:29-37` 里写的"透明底 + 粉边（WizBg/WizBorder）"在这条链路上完全不生效** —— dressing 只管 `vim.ui.select/input`，管不到 `vim.fn.input()`。

**修法一：观感（5 分钟，改 `plugins/noice.lua`）**

```lua
cmdline = {
  enabled = true,
  view = "cmdline_popup",
  format = { input = { title = " 代码操作 " } },  -- 默认是 kind 名 " Input "；设 "" 可隐藏
},
views = {
  cmdline_popup = { position = { row = "50%", col = "50%" }, size = { width = 74 }, border = { style = "rounded" } },
  cmdline_input = { position = { row = "50%", col = "50%" }, size = { width = 74 }, border = { style = "rounded" } },
},
-- 想真正统一成向导的粉边/透明底：这些组是 noice 启动时 link 出来的，覆盖 link 比改 view 可靠
vim.api.nvim_create_autocmd("ColorScheme", { callback = function()
  vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorderInput", { link = "WizBorder" })
  vim.api.nvim_set_hl(0, "NoiceCmdlinePopupTitleInput",  { link = "WizTitle" })
  vim.api.nvim_set_hl(0, "NoiceCmdlinePopup",            { link = "WizBg" })
end })
```
（宽度必须从 78 改 74：实测浮窗总宽 = 78 + 左右 padding 2 + 边框 2 = **82 列**，80 列终端左右各裁 1 列，与你截图里"顶满屏幕"一致。）

**修法二：功能（真正的多选 + Esc 能取消）**——override `jdtls.ui.pick_many`，A 线已端到端实测：

```lua
-- 放进 lua/plugins/lang/java.lua 的 config = function(_, opts) 里（首次打开 Java 文件即生效，早于任何 code action）
local ok_ui, ui = pcall(require, "jdtls.ui")
local ok_snacks, Snacks = pcall(require, "snacks")
if ok_ui and ok_snacks and not ui._snacks_pick_many then
  local original = ui.pick_many
  ui._snacks_pick_many = true
  ui.pick_many = function(items, prompt, label_f, opts)
    if type(items) ~= "table" or #items == 0 then return {} end
    local co, is_main = coroutine.running()
    if not co or is_main then return original(items, prompt, label_f, opts) end -- 主线程兜底
    label_f, opts = label_f or tostring, opts or {}
    local is_selected = opts.is_selected or function() return false end
    local finder_items = {}
    for idx, item in ipairs(items) do
      finder_items[idx] = { idx = idx, item = item, text = label_f(item) }
    end
    local finished = false
    local function finish(value)
      if finished then return end
      finished = true
      if coroutine.status(co) == "suspended" then
        vim.schedule(function() coroutine.resume(co, value) end)
      end
    end
    local ok_pick, picker = pcall(Snacks.picker.pick, {
      source = "jdtls-pick-many",           -- 独立 source：避开 snacks 同 source 互相顶掉的机制
      title = (tostring(prompt or "选择"):gsub("%s+", " ")),
      items = finder_items,
      filter = {},
      formatters = { selected = { show_always = true, unselected = true } },
      format = function(item) return { { label_f(item.item or item) } } end,
      win = {
        input = { keys = { ["<Esc>"] = { "cancel", mode = { "n", "i" } } } },
        list = { keys = { ["<Space>"] = { "toggle_item", mode = { "n", "x" } } } },
      },
      actions = {
        toggle_item = function(pk) pk.list:toggle() end,
        confirm = function(pk)
          local sel = pk.list and pk.list.selected or {}
          local ret = {}
          for _, it in ipairs(sel) do if it.item then ret[#ret + 1] = it.item end end
          finish(ret)
          pcall(function() pk:close() end)
        end,
      },
      on_show = function(pk)                 -- is_selected 预勾选（构造器字段默认选中项）
        local tries = 0
        local function mark()
          tries = tries + 1
          if #pk.list.items == 0 and tries < 25 then return vim.defer_fn(mark, 20) end
          for _, it in ipairs(pk.list.items) do
            if it.item and is_selected(it.item) and not pk.list:is_selected(it) then pk.list:toggle(it) end
          end
        end
        mark()
      end,
      on_close = function() finish(nil) end, -- Esc → nil = 取消
    })
    if not ok_pick or type(picker) ~= "table" then return original(items, prompt, label_f, opts) end -- 失败回退
    return coroutine.yield()
  end
end
```

三条**必须知道**的约束（都实测过）：
1. **不能用 `vim.wait` 同步等**：实测 `vim.wait` 期间按键 6 秒完全不被处理（映射不触发、feedkeys 也无效）。必须走 coroutine 让出——jdtls 自己的 `tests.lua:144-152` 就是这个模式，`async.lua` 保证 code action 都跑在协程里。
2. **`multi = true` 不能加**：snacks 的 `multi` 是"多数据源"，传 boolean 会抛 `picker/config/init.lua:130: bad argument #1 to 'ipairs'`，异常被 jdtls 的 xpcall 吞成静默 notify（Lead 已复现该抛错）。勾选靠 `toggle_item` + `formatters.selected`。
3. **`snacks.picker.ui_select = false` 的现状是对的、别动**：snacks 同 source 有活动 picker 时会"关旧的 + 不创建新的 + 返回 nil"（`picker/init.lua:77-82`），而向导也用 `source="select"`；override 用独立 source 正是为了绕开它。

### 7.2 错误显示：查到 3 个真问题（其中 2 个是 P1）

| # | 问题 | 证据 | 修法 |
|---|---|---|---|
| **P1** | **`severity_sort` 没设**（默认 false）⇒ 同一行有 ERROR + WARN 时，**行尾显示的是"插入序最后一条"而不是最严重那条**，1 列宽的符号列也画 `W` 而不是 `E` | 用真实 jdtls 复现你截图那条 `This method must return a result of type T.LikeMapper`：现状屏幕 `W …●● lua_ls: unused method build`，加 `severity_sort=true` 后同一帧变成 `E …●● jdtls: Type mismatch…`；依据 `diagnostic.lua:2263-2284`（virt_text 只取最后一条 message）+ sign 优先级（不开排序时全是 10） | `severity_sort = true,`（`[d`/`]d` 的跳转顺序不受影响，实测仍是位置序） |
| **P1** | **noice 接管 `vim.notify` 后，LSP/插件类报错只闪一次通知，`:messages` 永远查不到** —— 唯一的逃生口 `:Noice errors` / `:Noice history` 本机**没有任何键位、也没有文档**提到 | VimEnter 后实测：`vim.notify(ERROR)` 与真实 `vim.lsp.buf.rename()` 失败都只进 noice 历史（`noice history=[notify/error]…`），`nvim_exec2("messages")=""`；而 `echomsg`/autocmd/键位回调里的 Lua 报错**能**查到（所以第一轮"启动时 `:messages` 为空"是"启动没报错"，不是命令坏了） | 二选一：① `messages = { view_error = "split" }`（错误改用不消失的 split 视图）；② 加逃生键位 `<leader>se = :Noice errors`、`<leader>sh = :Noice history` |
| **P2** | **ERROR 用行尾 virtual_text**：长消息铺满代码行尾，还会被 80 列截断（你截图里那半行就是这个） | 真实 jdtls：`E 5 return; ● This method must return a result of type T.LikeMapper`；WARN 长消息截断成 `…only syn` | 见下面的推荐块：WARN 留行尾、ERROR 挪到代码行下方 `virtual_lines`（**注意有硬上限：超宽直接 trunc**，310 字消息只能看到 80 列，看全文仍要用 `]d` 的 float） |
| **P2** | `[d`/`]d` 的浮窗带 jdtls 内部数字码（`[603979884]`），且光标一动就关 | `diagnostic.lua:2561-2563` 默认 suffix 就是 code | 推荐块里的 `float.suffix = function() return "" end`（实测去掉 code） |
| 建议 | 注释写"画波浪线"（`options.lua:70`），实测是**直线下划线**（catppuccin 默认 `underlines={"underline"}`，无 undercurl） | `nvim_get_hl` 实取值 `DiagnosticUnderlineError={underline=true, sp=#F38BA8}` | 想要真波浪线：`theme.lua` 加 `lsp_styles = { underlines = { errors = {"undercurl"}, … } }`；否则改注释 |
| 建议 | `:checkhealth vim.diagnostic` 在 0.12 **不存在**（实测 `No healthcheck found`）；`~/md/nvim` 没有一处写诊断显示配置与 `:Noice errors` | — | 排障改用 `vim.diagnostic.config()` 探针 + `:checkhealth vim.lsp`；在 `nvim命令.md` 补一节 |

**推荐配置（可直接替换 `core/options.lua:67-74`，B 线实测通过）**

```lua
vim.diagnostic.config({
  severity_sort = true, -- 同行多诊断：让最严重那条排最后（virt_text 只显示最后一条），符号列才会显示 E
  virtual_text = {      -- 行尾只留 WARN；INFO/HINT 只看符号列与下划线
    spacing = 2, prefix = "●", source = "if_many",
    severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.WARN },
  },
  virtual_lines = {     -- ERROR 改在代码行下方单独占一行，且只在当前行显示
    severity = { min = vim.diagnostic.severity.ERROR },
    current_line = true,
    format = function(d) return d.message end,
  },
  underline = true,
  signs = true,
  float = {
    border = "rounded", source = "if_many",
    max_width = math.floor(vim.o.columns * 0.8), max_height = 12,
    suffix = function() return "" end, -- 去掉 jdtls 的 [603979884]
  },
  update_in_insert = false,
})
```
只想改最小两处也可以：`severity_sort = true` + `virtual_text.severity = { min = WARN, max = WARN }`。

### 7.3 leader 提示：3 类问题（都有渲染实测）

**问题 1：5 个前缀没有名字。** Java 缓冲区按空格实测渲染出（A/C 线复现 + Lead 复核）：

```
J ➜ +5 keymaps    m ➜ +7 keymaps    o ➜ +1 keymap    R ➜ +4 keymaps    G ➜ +4 keymaps
```

`whichkey.lua:14-24` 只声明了 b/c/d/f/h/r/s/t/w 九个组，而这几个前缀里是 Maven 生命周期、Java 测试、提取重构、代码生成——**最常用的 Java 键位全是没有标题的裸列表**。更麻烦的是：这些键是 buffer-local，**没有 LSP attach 的普通文件里 `c`/`r`/`J`/`m`/`R`/`o` 整组消失**（同一弹窗只剩 12 项），所以你看到的 leader 菜单会随文件类型变脸。

```lua
{ "<leader>G", group = "代码生成（Java）" },
{ "<leader>J", group = "Java 测试/调试" },
{ "<leader>m", group = "Maven 构建" },
{ "<leader>R", group = "重构：提取" },
{ "<leader>o", group = "整理 import" },
```

**问题 2：按 `g`/`z`/`[`/`]`/`<C-w>` 也会弹巨窗。** which-key v3 的 auto trigger 实测包含这些；非插件节点 delay=200ms。于是 `gg`/`gd`/`zz` 之前先闪一整屏：**z 弹窗 33 项 / 20 行，g 弹窗 42 项 / 24 行，且中英混排**。收敛成"只有 leader 才弹"（已实测有效）：

```lua
triggers = {
  { "<leader>", mode = "n" },
  { "\\", mode = "n" },
},
delay = 300,
```

**问题 3：spec 里 142 条有 71 条是重复劳动。** which-key v3 的 `presets` 插件默认开启，**已经内置** `w/b/e/z/g/<C-w>` 等内置键的中文说明；官方文档明确 spec 只用于"分组描述"和"不存在真实 keymap 的映射"。本机手写的 z 全家桶、`<C-w>` 全家桶、motions 等 71 条与内置逐字重复（重复不报错，但会互相覆盖描述）。另外三处小问题：`<leader>s` 把"窗口分割"和"Spring"混装（实测子项 `sh/sv` + `sp/sP` + `sr`）、`t` 组是死条目（真实键位是 `<leader>tt/th/tv`，顶层 `t` 永远不弹）、`fp` 的描述"搜索项目"在一个叫"Telescope"的组里但实际走 `<cmd>Projects<cr>`。

**另外两个"内置键被吃掉"的问题（P2，实测）：**
- `java.lua:338` 把 `gU` 覆盖成"跳父类" ⇒ **Java 文件里 `gU{motion}` 转大写失效**（实测 `gUw` 只触发映射、文本不变）。建议改用 `gA` 之类不冲突的键，which-key 第 39 行同步。
- `lsp_on_attach.lua:34` 的 `gr` 覆盖了 **0.12 内置的 `gr` 前缀**（`gra/grn/grr/gri/grt/grx`），which-key 里 `gr` 显示成"查找所有引用"但展开是另外 6 条。建议删掉这条映射，改成组标题 `{ "gr", group = "LSP 引用 / 重命名 / 代码操作" }`。

## 8. 第二轮另外挖出的"按下去就不对"（都已实测）

| 严重度 | 问题 | 位置 | 证据（Lead 复核标 ✔） | 修法 |
|---|---|---|---|---|
| **P1** | **插入模式 `<C-u>`/`<C-d>`/`<C-e>` 静默失效**：被 blink 占用却没写 `fallback`，菜单/文档窗没开时 blink 直接吞键 | `completion.lua:19-25` | ✔ 用户配置下 `A<C-u><Esc>` 后 buffer 逐字不变；`maparg` 显示 desc 全是 `blink.cmp: …`；`--clean` 对照组正常 | 三行都加 `"fallback"`（`{"hide","fallback"}` 等）；更稳的是把文档滚动换成 `<C-b>`/`<C-f>` |
| **P1** | **`<leader>th`/`<leader>tv` 在已有终端时变成"关闭终端"**：toggleterm 的 `smart_toggle` 忽略 direction | `terminal.lua:34-40` | ✔ Lead 实测 `:ToggleTerm`(float) 后 `:ToggleTerm direction=horizontal` → 终端窗口消失；`toggle(id,…)` 分 id 调用则可共存 | 每个方向独立 id：`toggle(1,20,nil,"float")` / `toggle(2,15,nil,"horizontal")` / `toggle(3,60,nil,"vertical")` |
| P2 | neo-tree 里 `p` 被改成 toggle_hidden，**粘贴没了**（`H` 本来就是切换隐藏） | `filetree.lua:40` | 默认表 `defaults.lua:482 ["p"]="paste_from_clipboard"` | 删掉这行；想保留就换 `P` |
| P2 | blink 补全文档 `auto_show = true`（上游默认 false）+ `max_height=20`，一停 500ms 就挡代码 | `completion.lua:38` | blink 默认值源码 | `auto_show_delay_ms = 800` + `max_height = 12`，或改回 false |
| 建议 | `WizBg` 实测是**空组**（无 bg ⇒ 透明），与 `dressing.lua:34-36` 注释"实底 #1E1E2E"不符 | `dressing.lua` | ✔ `nvim_get_hl("WizBg") = {}` | 改注释，或真给 WizBg 加 `bg = "#1e1e2e"` |

**已核实没问题的（第二轮）**：lazy 的 `keys` 桩不会产生重复映射或丢 desc（加载前后各 1 条、desc 完整）；`[d`/`]d` 映射与 which-key 描述一致；`snacks.picker.ui_select=false` 的注释（同 source dedupe）属实；`dressing` 确实通过 `patch.lua:25` 接管 `vim.ui.select/input`（nui 后端）。

## 9. 第二轮外部事实（带来源）

| 事实 | 含义 | 来源 |
|---|---|---|
| nvim-jdtls #358（已关未修）："using the command line to select them is pretty uncomfortable" | 你的抱怨上游有同款；async 化 PR 未合并 ⇒ **不要等上游，自己 override** | [issue](https://github.com/mfussenegger/nvim-jdtls/issues/358) |
| `:h input()` 的 `cancelreturn`（默认 `""`）="取消时返回的值"；官方 `vim/ui.lua` 注释明说"应该区分取消与输入空串" | Esc 与空回车**默认不可区分**；想区分要用 `input({cancelreturn=…})` | [builtin](https://neovim.io/doc/user/builtin.html#input()) |
| noice 的 cmdline 标题 `top = format.title or (" " .. kind_cc .. " ")` | `Input` 标题可改可关（`cmdline.format.input.title`） | [config/cmdline.lua](https://github.com/folke/noice.nvim/blob/main/lua/noice/config/cmdline.lua) |
| dressing **已归档**；作者建议用 snacks 做 `vim.ui.input`、任意 fuzzy picker 做 `vim.ui.select`；snacks `ui_select` **只有单选**；Neovim 0.12 也无原生多选（#17044 open、#18161 closed） | 真多选只能自建（本文 override）；dressing 属于"能跑但无上游" | [dressing#190](https://github.com/stevearc/dressing.nvim/issues/190) · [select.lua](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/select.lua) · [#17044](https://github.com/neovim/neovim/issues/17044) |
| which-key v3 的 `presets` 默认开启、已内置内置键说明；spec 只该写分组 | 本机 71 条 spec 属冗余 | [presets.lua](https://github.com/folke/which-key.nvim/blob/main/lua/which-key/plugins/presets.lua) · [doc](https://github.com/folke/which-key.nvim/blob/main/doc/which-key.nvim.txt) |

## 10. 第二轮方法与只读证明

- 3 条并行审查线（各自独立发现文件、互不重叠）+ 1 条上游调研（带 URL）+ Lead 复核：本文件中标 ✔ 的条目均为 Lead 亲自复现（`input()` 返回矩阵、blink 吞键、toggleterm 方向失效、which-key 前缀枚举、noice 标题/边框高亮、snacks API 形状与 `multi=true` 抛错）。
- 有效方法沉淀：**涉及 noice/which-key 的探针必须用 `--cmd "autocmd VimEnter * lua vim.defer_fn(…)"`**（`-c` 在 VimEnter 之前执行，会测到"插件还没 setup"的假状态）；`which-key.show()` 是交互式的，headless 会挂住，改用"枚举前缀映射 + spec"等效复现。
- 第二轮同样**没有改动任何配置**：`git status --porcelain` 与第一轮结束时一致（仍是那 6 个 `M` + 本报告这一个 `??`）。
---

## 11. 实施记录（2026-09-24 晚，按 preflight 分批计划执行）

> 备份：`~/backups/nvim-config-preflight-20260924-185532`（含 `.git` 全量、未提交 patch、`lsp.log.before-truncate.gz`）；回滚命令见 `nvim-config-preflight-20260924.md` §3。

### 11.1 批次 1（零风险，全部自证）✅

| 改动 | 文件 | 验收证据 |
|---|---|---|
| catppuccin 的 lualine 集成改成 override 表 | `plugins/theme.lua` | 探针：`theme = catppuccin-mocha`（不再 `auto`）、`lualine_a_normal.bg=#89b4fa`、`lualine_c_normal` 无 bg ⇒ **纯黑带消失** |
| 诊断加 `severity_sort = true` | `core/options.lua` | `vim.diagnostic.config().severity_sort = true` |
| blink 的 `<C-u>`/`<C-d>`/`<C-e>` 补 `fallback` | `plugins/completion.lua` | `A<C-u><Esc>` / `A<C-d><Esc>` 的结果与 `--clean` **逐字一致**（`{"    "}` / `{"bbbb"}`）⇒ 插入模式内置行为恢复 |
| 终端三键改成独立 id + 浮窗聚焦时先切窗 | `plugins/terminal.lua` | headless 台账：1/float→2/horizontal→3/vertical 可共存；**真 pty**（`tt → jk → th → jk → tv`）实测 float 关闭、horizontal/vertical 并存 |
| which-key：补 5 分组、触发收敛、`delay=300`、删死条目、补中英混排 | `plugins/whichkey.lua` | 生效配置 `triggers = {<leader>, \\}`、14 个分组（含 G/J/m/o/R）；`g/z/[/]/<C-w>` 不再自动弹窗 |
| noice 命令行浮窗宽度 78→74、标题「 Input 」→「 输入 」 | `plugins/noice.lua` | 解析后配置：两处 `size.width=74`、`cmdline.format.input.title=" 输入 "` |
| 新增 `<leader>he`/`<leader>hh`（`:Noice errors`/`:Noice history`） | `core/keymaps.lua` | `maparg` 有 desc；noice 吞 `vim.notify` 后终于有逃生口 |
| 首个 Java buffer 按 buffer 去重 | `plugins/lang/java.lua` | `LSP_START_CALLS` **4 → 3**：jdtls 1 次 ✔；spring-boot 仍 2 次——那是**插件自身 `auto_enable` 的 FileType 路径**，`vim.lsp.start` 去重后 `CLIENTS=2`，无重复进程 |

### 11.2 批次 2（键位/观感/清理/文档）✅

| 改动 | 验收证据 |
|---|---|
| `gU`（Java 跳父类）→ **`gA`**；删掉覆盖内置前缀的 `gr` 映射 | LSP buffer 里 `gr=false`、`grr=true`、`gra=true`、`gd=true`；`gU{motion}` 转大写恢复 |
| 补 `application.properties` / `*.gotmpl` 的 devicon（复用字体已有码点 U+E615 / U+E627） | `get_icon` 返回 `DevIconProperties` / `DevIconGotmpl`（不再 nil）；新增 `plugins/devicons.lua` |
| `lsp.log` 27 MB → gzip 备份后清空 | 备份 `lsp.log.before-truncate.gz`（1.1 MB）在备份目录；现在 0 字节 |
| `stylua`：只格式化 3 个**非 WIP** 文件（lazy/spring_wizard/springboot） | `stylua --check .` 剩余失败仅 `cheatsheet.lua` + `lang/java.lua`——两个都是未提交的 WIP，按约定没动 |
| 用户文档同步（8 个文件 51 处）+ 技能 `architecture.md` 4 格→2 格 | JavaInit 只剩"已删除"墓碑；"34 个"已 0 处；`architecture.md` 已订正为 2 格 |

### 11.3 ✅ 已全部结清（原「批次 3：代码已落地，需要你真机确认」；真机面见 §27.8）

| 改动 | 验收证据 | 需要你 |
|---|---|---|
| `jdtls.ui.pick_many` → snacks picker（`<Tab>` 勾选 / `<CR>` 确认 / **`<Esc>` 取消**；协程让出；失败回退上游） | 队友 pty 真按键：`Tab×2+CR` → 返回 2 项；`Esc` → `nil`；主线程调用仍走上游（无回归）。**比归档代码多一行** `layout.preview=false`（否则右侧预览渲染 `Item has no 'file'`） | 在真实 Java 工程里从 code action 菜单走一次 |
| 向导创建项目：`vim.system():wait()` → `bridge` 协程让出 | 队友 pty 真键盘 + `spring` stub：窗口内 **15 次心跳、最大间隔 113 ms**（旧写法按键 1.6 s 无响应）；A/B 同埋点对照 | 自己走一遍向导（headless 走不完 11 步交互） |

### 11.4 本轮**订正/精修**了报告里的 3 处（真实性自查）

1. **§2.11 撤回**：`site/pack/core/opt` 不是残留——它由 nvim 0.12 内置 `vim.pack` **每次启动自动重建**（我删掉后跑一次 nvim 就回来了）⇒ 那条 checkhealth 警告对任何不用 vim.pack 的配置都是常态，**不要处理**。
2. **§1.2 机制表述精修**：向导 `:wait()` 期间 **uv timer 照常触发**，被挡住的是**按键处理**与 **`vim.schedule` 回调**（`vim.defer_fn` = uv timer + schedule，所以表现为"timer 不触发"）。冻结结论不变，机制更准确。
3. **§7.1 适用范围收窄**：代码操作的多选现在走 snacks picker，**不再经过 noice cmdline**；noice 的标题/宽度改造对其它 `input()` 路径仍有效（已同步进 `~/md/nvim/nvim配置架构.md`）。

### 11.5 ✅ 已全部结清（原「仍未做 / 需要你拍板」，逐项落点见 §27.2 + §27.8）

- **未做（按约定不动）**：停维护插件替换（project.nvim/dressing/Comment/bufferline/toggleterm）、`~/.config/kitty/kitty.conf`、2 个 WIP 文件的 stylua 全树格式化。
- **需要你实机确认**：真 Java 工程里的多选弹窗；向导 11 步；补全菜单里 `<Tab>` 的最终归属；状态栏/浮窗观感；Neovide。
- **观察项**（文档线提出，我未改）：`:JavaSetRuntime` 命令存在，但 `java.lua` 未配 `settings.java.configuration.runtimes`，nvim-jdtls 可能提示 "No runtimes found"——要不要补配置由你定。
- **未验证项**（队友如实标注）：`is_selected` 预勾选后 Tab 追加的时序；`<Space>` 勾选只在列表窗口生效；字段路径的"真取消"受上游 `jdtls.lua:138` 不检查返回值限制。
---

## 14. 第四批：picker 观感精修（2026-09-24 深夜）

> 用户反馈「这些框的 UI 有点难看」，并选中 fzf-lua 那种**紧凑列表**风格（细边框 + 标题栏带查询/计数 + 小框 + 背景变暗）。

### 14.1 诊断：难看的根源是布局预设，不是配色

代码操作多选用了 snacks 的 `preset = "default"` ⇒ 它按 **width 0.8 / min_width 120 / height 0.8** 预留空间，而预览窗又被我们隐藏 ⇒ **3 个选项也要撑出 80% 屏幕的大空框**。真 pty（80×24）实测：旧 = **80×19**，新 = **40×7 居中**。

### 14.2 改了什么

| 项 | 改法 | 验证 |
|---|---|---|
| 默认布局 | 在 `plugins/snacks.lua` 注册自定义预设 **`picker_compact`**（克隆内置 `select`：居中、`min_height=2` 随内容变高），只改 `min_width 40` 与 `height 0.4` | pty 实测 40×7 居中、不裁边 |
| picker 皮肤 | 默认 **soft**：`SnacksPickerBorder/Title/InputBorder` → `#7f849c`（含蓄灰蓝）、`SnacksPickerBackdrop` → bg `#11111b`（否则 backdrop 窗透明，变暗无效） | 启动 2.5s 后仍为 soft（向导的高亮覆盖已用 `defer_fn` + `ColorScheme` 处理） |
| 背景变暗 | `backdrop = 60` | 与布局一起实测 |
| 运行时切换 | `:let g:jdtls_pick_layout = 'ivy'`（或 `default/vscode/dropdown/select/vertical`）、`:let g:jdtls_pick_backdrop = 0`、`:PickerSkin soft\|pink` | 三种都实测生效 |
| 回退可见性 | picker 启动失败时 `vim.notify` 告警（原来静默回退到 `input()`，样式不生效完全查不出原因） | 修 `border = "rounded"` 报错时正是靠它定位 |

### 14.3 踩到的两个 snacks 坑（记录备查）

1. **不要给 `layout` 传裸表**：不带 `preset` 直接写 `{ box = "vertical", { win = "input" }, … }` 会报 `layout.lua:102: no root box found`（深层合并把数组部分揉坏）。定制要**注册预设**再按名字引用。
2. **预设里定义的键会赢过调用处的内联覆盖**：`layout = { preset = "select", min_width = 40 }` 无效（仍是 80，80 列终端被裁 3 列）。要改就改预设本身。

### 14.4 还没做（等你定）

- 向导卡片、`vim.ui.select`（dressing）目前仍是洋红 `#f38ba8`；要"三处完全统一"需要给 dressing 换 `snacks_picker` 后端 + 把向导的 `source` 改成独立名（避免 snacks 同 source 互顶）。
- `.ui-shots/` 是这次给你看效果的临时图目录（对比图 + fzf-lua 官方 demo 帧），看完可删。
---

## 15. 第五批：能换的地方都换成 fzf 形态（2026-09-24 收尾）

> 用户：「最好能替换的地方都替换成 fzf 那种形式」。做法：把**所有选择器统一到 snacks picker + 同一套 soft 皮肤**，短列表用紧凑预设、文件/内容搜索保留预览（与 fzf-lua 的文件搜索一致）。

| 位置 | 改前 | 改后 | 验证（真机探针） |
|---|---|---|---|
| `<leader>ff/fg/fb/fh` | Telescope（find_files/live_grep/buffers/help_tags） | `Snacks.picker.files/grep/buffers/help` | 调用后开出 `snacks_picker_{list,input,box}(+preview)` ✔ |
| `<leader>fc` | `telescope.builtin.find_files` | `Snacks.picker.files({ cwd = stdpath("config") })` | ✔ |
| `<leader>fp` / `:Projects` | 自定义 **Telescope** picker | `Snacks.picker.pick`（source `projects`、`picker_compact` 预设）；切 cwd + neo-tree 跟随的行为原样保留 | ✔（stub 历史后开出 snacks 窗口） |
| 起始页 3 个按钮 | Telescope | `Snacks.picker.files/recent/files({cwd=config})` | 命令字符串已换 |
| `vim.ui.select`（含 `<leader>db` 断点列表、jdtls 的 code action 选择等） | dressing 的 **nui** 后端 | dressing 的 **`snacks_picker`** 后端（`backend = { "snacks_picker", "nui", "builtin" }`） | 探针：后端 = `snacks_picker`，`vim.ui.select` 开出紧凑 snacks 窗口 ✔ |
| 向导的两个 picker | `source = "select"` | `source = "spring-wizard"` / `"spring-wizard-deps"` | 避免与 dressing 的 `select` 源**同源互顶**（snacks 同 source 会关旧实例并让新实例返回 nil） |
| 文档/标签 | `搜索（Telescope）`、`断点列表（telescope）`、`project.lua` 注释 | 全部改为 snacks 口径 | — |

**保留**：telescope 插件本身（`:Telescope` 仍可用）与 `theme.lua` 的 telescope 集成；确认不再需要后可删掉 `lua/plugins/telescope.lua`（连带 plenary；**project.nvim 要留**，`:Projects` 的历史仍由它提供）。

### 15.1 现在的"一套观感"

- **短列表**（代码操作多选、`vim.ui.select`、项目列表）：`picker_compact` = 居中、随内容变高、细灰蓝边 `#7f849c`、背景变暗 60。
- **文件/内容搜索**：snacks 内置 `default`（列表 + 预览），同样是细灰蓝边 + 变暗。
- 皮肤切换：`:PickerSkin soft|pink`；布局试：`:let g:jdtls_pick_layout='ivy'`。
---

## 16. 第六批：修 bug + 统一观感（2026-09-24 深夜，用户实测反馈驱动）

用户反馈：「还有很多 bug…操作和原来的不一样…没有选中迹象…美化不够…颜色不必只有粉…面板背景黑色难看…并没有所有地方都覆盖到…主页按 p 出现 bug」。

### 16.1 ⚠ 数据事故与修复：项目历史被清空（已恢复）

| 项 | 内容 |
|---|---|
| 现象 | 主页按 `p`（`:Projects`）**什么都不开**，只弹"暂无项目历史" |
| 根因 | `core/commands.lua` 里**旧有的** `read_project_history_sync()` 会写 `project_nvim.utils.history.recent_projects`；而 project.nvim 在 `VimLeavePre` 用 **mode=\"w\"（截断）** 重写整份历史文件（`history.lua:145-173`）⇒ 只要内存里被赋成空表，退出时就把 `~/.local/share/nvim/project_nvim/project_history` 清成 **0 字节**。我这一晚跑了 50+ 次 headless 探测，把它触发了 |
| 修复 | 删除该函数，改为 `read_project_history()`：**只读文件**构造列表（并从 shada 的 oldfiles/字符串里恢复），**绝不写插件内存状态** ⇒ 这条清空路径不复存在 |
| 恢复 | 从 shada 捞回 `~/Projects/Feed stream`、`~/Projects/leetcode`，并补上 `~/Projects/*` 里带 `.git` 的项目，共 **15 条**写回历史文件（`/tmp/project_history.before-restore` 是空文件副本）|
| 遗留 | 原始列表无法完全还原（shada 的 oldfiles 已被我的探测轮换掉）。**但这份历史会随你打开项目自动重建**；目前 15 条是我按现有项目补的种子，多余的可删 |

### 16.2 观感/交互 bug（全部实测）

| 问题 | 根因 | 修复 |
|---|---|---|
| **看不出选中哪一条** | `SnacksPickerCursorLine` 在所有主题里都是**空组** | 设为 `bg=#313244, bold` |
| **面板背景发黑难看** | `SnacksPickerBox`/`SnacksPickerList` 也是空组 ⇒ 浮窗透明、透出终端黑底 | 设为 catppuccin base `#1e1e2e` 实底（卡片感） |
| **上下键不顺手** | snacks 默认在输入窗只认方向键 | 全局绑 `<C-j>/<C-k>`（你 Telescope 时代的习惯）+ `<C-n>/<C-p>` |
| **卡住/关不掉** | snacks 默认在输入窗把 `<Esc>` 当"退出插入模式"，框不关 ⇒ 连开三个 picker 会**叠在一起** | 输入窗绑 `<Esc> = cancel`（一次关掉），实测窗口数每次回到 1 |
| **颜色只有粉** | 我们只改了边框，标题仍是灰、选中仍是空 | 边框灰蓝 `#7f849c`、**标题主题蓝 `#89b4fa`**、匹配关键字暖黄 `#f9e2af`、背景 base |
| **覆盖不全** | `theme.lua` 的 catppuccin 集成**漏了 snacks/flash/notify**；dressing 输入框与向导仍用洋红 `Wiz*` | 补上三个集成；soft 模式下同时改写 `WizBg/WizBorder/WizTitle` ⇒ dressing 输入框与向导卡片一起统一 |

### 16.3 数据事故的教训（写进本报告备查）

1. **不要把插件的内存状态当缓存**：project.nvim 的 `recent_projects` 是"退出时落盘"的权威副本，外部写它等于替它决定文件内容。
2. **headless 探测会污染 `shada`**（oldfiles 轮换）——这次连恢复素材都差点被自己冲掉；以后要恢复用户数据，优先在探测**之前**做快照。
3. 任何"读到空就赋空"的写法，在有"退出回写"的插件上都是**数据删除**。
---

## 17. 第七批：UI 提供者单一化（2026-09-24 收尾，用户："能尽量全换的都换，免得地方冲突"）

### 17.1 收敛结果：全机只剩 snacks 一家 UI 提供者

| 面 | 改前 | 改后 | 验证 |
|---|---|---|---|
| `vim.ui.select` | dressing（nui 后端） | **snacks.picker**（`picker.ui_select = true`） | 真 TTY：`ui.select <- snacks/picker/init.lua`，实开出 `snacks_picker_{list,input,box}` ✔ |
| `vim.ui.input` | dressing input | **snacks.input**（`input.enabled = true`） | 真 TTY：`ui.input <- snacks/input.lua`，实开出 `snacks_input` ✔ |
| dressing.nvim | 装 | **spec 删除 + `:Lazy! clean` 从磁盘删除** | `lazy/dressing.nvim` 已不存在，lock 无引用 ✔ |
| telescope.nvim | 装（键位已迁走） | **同上删除** | 同上 ✔ |
| plenary.nvim | telescope 依赖 | **保留**（neo-tree 的依赖） | — ✔ |
| catppuccin 集成 | 漏了 snacks/flash/notify、含 telescope | 补三个、去掉 telescope | 高亮组实测非空 ✔ |

### 17.2 本轮抓到的**同一类真 bug**：snacks 的 `win.*.keys` 是**整体替换**

- 现象：`<C-j>` 加上了，但 **`<CR>` 确认没了、`<Esc>` 关不掉（要按两次）、向导按 CR 不推进**。
- 根因：我们（以及向导自带的 `win_config()`）在 `win.input.keys` / `win.list.keys` 里只写了几个键 —— snacks 是**替换**语义，默认的 51/44 个键（`<CR>` confirm、`<Tab>` 多选、`<Esc>` cancel、方向键…）被整表干掉。
- 修复：三处（全局 picker 配置、jdtls 多选 picker、向导 `win_config()`）统一改成 `vim.tbl_extend("force", vim.deepcopy(defaults.win.*.keys), 追加键)`。
- 验收：input 键数 **51**、list **44**，`<CR>`/`<Esc>`/`<Tab>` 均在；pty 实测 `ff → ↓ → CR` 真打开了文件、`ff → Esc` 一次关掉 ✔。

### 17.3 其他修复

- 向导两个 picker 的 `source` 改 `spring-wizard*`（避免与 `vim.ui.select` 的 `select` 源互顶）。
- **项目历史事故的修复与恢复**见 §16.1（`read_project_history()` 只读文件；从 shada 恢复 15 条）。
- 文档侧的 dressing/telescope 描述已交给文档线同步（插件总数会从 38 变 36，以 `lazy-lock.json` 为准）。

### 17.4 仍需你真机确认

- 向导 11 步（我这边 pty 只能确认它开着、键位已恢复，走不完整个交互）。
- `:PickerSkin pink` 与 soft 的取舍、以及 `picker_compact` 是否合口味。
---

## 18. 第八批：项目切换两个报错（2026-09-24 深夜，用户截图）

用户报：`:Projects` 选中项目后弹 **Error**（`project.lua:180: Invalid 'dir': Expected Lua string`）+ **Warning**（neo-tree `parser.lua:199` 解析失败）。两个都定位到并修好了。

| # | 根因 | 修复 | 验证 |
|---|---|---|---|
| 1 | **`source = "projects"` 撞上 snacks 的**同名内置源**（`sources.lua:888`，finder = `recent_projects`）⇒ 走的是 snacks 自己的 finder，**我们喂的 items 根本没生效**，confirm 收到的是别的项目条目，`.dir` 取到 `true`/nil ⇒ `nvim_set_current_dir(nil)` 报 Invalid 'dir' | 源改名 `project-history`（并保留 `file`/`_path`/`text` 反查兜底） | pty：`DirChanged → /home/pang/Projects/Feed stream` ✔，四类报错全 0 |
| 2 | 我们沿用的老写法 `Neotree filesystem reveal dir=<path>`：neo-tree 的命令解析器**按空格切分参数**（`parser.lua` 的 `utils.split(args, " ")`）⇒ **路径含空格的项目（"Feed stream"、"MD Reader"…）必然解析失败** | 删掉该命令；neo-tree 联动交给 `lua/plugins/project.lua` 里对 `set_pwd` 的补丁（Lua API `manager.navigate`，不受空格影响） | 同上，`文件树刷新失败` 0 次 ✔ |

**顺带学到的两条 snacks 约束**（已写进代码注释）：
1. **不要用内置源名当自定义 source**（`projects`/`files`/`select`… 全在内置表里）——同名会被路由到内置 finder。
2. **不要用 `dir` 当自定义字段名**：snacks 补全文件项元数据时 `dir` 是布尔标志（"是目录"），会覆盖你的字符串。

### 18.1 同类风险复查

我们全部四个自定义 source（`project-history`、`spring-wizard`、`spring-wizard-deps`、`jdtls-pick-many`）与 snacks 内置源（`files/grep/projects/select/…`）**均不重名** ✔。
---

## 19. 最终状态与交接（2026-09-24 收尾，本次工作结束）

> 这一节是**唯一入口**：先读这里，再看前面各轮细节。全部结论都有真机证据（headless 探针 / 真 pty / 运行时取值）；标注"未解决"的项**都核实过现状**，不是估计。

### 19.1 一句话结论

审查发现的 8×P1 + 13×P2 + 建议项里，**能自证的全部改完并验证**；UI 侧收敛成 **snacks 一家提供者**（dressing / telescope 已从磁盘删除，插件 38 → 36；第二轮又删掉 Comment.nvim → **35**，见 §20）；期间发生并修复 **1 起数据事故**（项目历史被清空，已恢复种子）；剩余 12 项**未解决或待你决定**（见 19.3），其中 1 项被阻塞在你未提交的 WIP 文件上。

### 19.2 ✅ 已解决（都验证过）

| 面 | 改动 | 验证方式 |
|---|---|---|
| 状态栏主题 | catppuccin 的 `lualine` 集成 `true` → `{enabled=true}`（原来主题模块抛错、静默退化成 `"auto"` 的纯黑带） | 探针：theme=catppuccin-mocha、lualine_c_normal 无 bg |
| 诊断排序 | `severity_sort = true`（同行多诊断时行尾才显示最严重那条、符号列才是 E） | 配置探针 |
| 插入模式按键 | blink 的 <C-u>/<C-d>/<C-e> 补 `fallback` | 与 --clean 对照结果逐字一致 |
| 终端三键 | <leader>tt/th/tv 各自独立 terminal id + 浮窗聚焦时先切窗 | headless 台账 + **真 pty**（float→horizontal→vertical 共存） |
| 键位让位 | Java `gU` → **gA**（gU{motion} 恢复）；删掉覆盖内置前缀的 `gr`（grr/gra/grn 可用） | LSP buffer 实测 gr=false / grr=true |
| 逃生键位 | 新增 <leader>he（:Noice errors）/ <leader>hh（:Noice history） | maparg |
| Java 双 attach | 首个 Java buffer 按 buffer 去重 | LSP_START_CALLS 4 → 3（余下 2 次是插件自身 auto_enable，去重后 CLIENTS=2） |
| :JavaSetRuntime | 补 `settings.java.configuration.runtimes`（原来只会 warning） | jdtls 客户端收到 2 个 runtime、_complete_set_runtime 返回两个名字 |
| 代码操作多选 | jdtls.ui.pick_many → snacks picker（Tab 勾选 / CR 确认 / **Esc 取消**；协程让出；失败回退并告警） | pty 真按键：Tab×2+CR 返回 2 项、Esc 返回 nil |
| 向导创建卡死 | 同步 `vim.system():wait()` → `bridge` 协程让出 | pty：窗口内 15 次心跳、最大间隔 113ms（旧写法按键 1.6s 无响应） |
| 向导健壮性 | 第 10 步补包名校验；lazy.lua 的 defaults 注释改成实话 | 模块加载 + stylua |
| 尺寸把控 | noice 命令行 `width="auto"`、select 动态夹取、dap-ui 侧栏自适应、blink 文档窗 800ms/12 行、dashboard logo 阈值 58、<leader>tv 自适应、neo-tree 宽度函数 | 真 pty 80×24：: 弹窗 44 列、select 58 列居中、neo-tree 32 列；无超屏浮窗 |
| devicon | 补 application.properties / *.gotmpl | get_icon 返回非 nil |
| UI 单一化 | vim.ui.select → snacks.picker、vim.ui.input → snacks.input（UIEnter 接管）；**dressing / telescope 的 spec 删除 + :Lazy! clean 从磁盘删除**；补 catppuccin 的 snacks/flash/notify 集成 | 真 TTY：ui.select ← snacks/picker/init.lua、ui.input ← snacks/input.lua；插件 36、两目录已消失 |
| picker 观感 | soft 皮肤（边框 #7f849c、标题 #89b4fa、面板实底 #1e1e2e、选中行 #313244+bold、匹配 #f9e2af、背景变暗 60）；自定义预设 picker_compact（居中、随内容变高）；:PickerSkin soft / pink | 高亮组实测非空；pty 几何实测 |
| picker 键位 | 保留 snacks 全部默认键（CR 确认 / Tab 多选 / **一次 Esc 关闭** / 方向键），**追加** <C-j>/<C-k>/<C-n>/<C-p> | 键表实测 input 51 / list 44；pty：ff→↓→CR 真打开文件、Esc 一次关掉 |
| 项目切换 | source 改名 project-history（避开 snacks 内置同名源）、自定义字段 dir → project_dir、删掉按空格切分必炸的 Neotree … dir= 命令 | pty 选带空格的 Feed stream：DirChanged 成功、四类报错 0 次 |
| 卫生 | lsp.log 27MB → gzip 备份后清空 | 备份在回滚点目录 |
| 文档 | ~/md/nvim/* 8 个文件 ~96 处 + DSH 技能 architecture.md，**双向 0 处不一致** | 文档线实测 40 个 :命令 全存在；:Telescope 已清零 |

### 19.3 ✅ 已全部结清（原「未解决 / 待你决定」，第一轮快照）

> **✅ 本表 15 项已全部结清（终态见 §27.2）**：①（stylua）②（键位作用域）见 §23.2/§23.3；③④⑤⑦⑧⑨ 见 §20.1；⑥ 见 §22.5.1（virtual_lines 已开）；⑩ 见 §20.1（Comment.nvim 已删）+ §23.3 #1（其余三项维持）；⑪（向导 11 步）见 §26.12；⑫（pick_many 三条边界）见 §27.8；⑬⑭ 见 §20.1 #10；⑮ 已撤回。**本表保留为当轮证据快照**，最新状态看 §23/§27。

| # | 事项 | 现状与建议 |
|---|---|---|
| 1 | **stylua --check . 仍失败 2 个文件** | lua/core/cheatsheet.lua、lua/plugins/lang/java.lua —— 都是你未提交的 WIP，我按约定没动。你 commit/stash 后跑 stylua . 即可 |
| 2 | Java 构建/Maven 键仍是 **buffer-local** | 非 Java 缓冲区按 <leader>mc 无效（文档已按实际作用域如实写）；要改全局就说一声 |
| 3 | lang/springboot.lua:13 仍是 `lazy = false` | 它让同 spec 的 ft 成死配置，并把 nvim-jdtls/DAP 拖进启动期；建议删掉只留 ft |
| 4 | lang/init.lua 的 pcall 仍静默吞错 | 整门语言加载失败会无提示消失；建议加 vim.notify(..., ERROR) |
| 5 | statusline.lua 的 `extensions = {"neo-tree"}` 仍是死配置 | 切到文件树时整条状态栏空白；删 extensions 或删 disabled_filetypes 里的 neo-tree |
| 6 | 诊断显示只做了 severity_sort | virtual_lines（ERROR 单独占一行）、[d/]d float 去掉 jdtls 内部码（如 [603979884]）**都没做**（当时为保零观感变化，你选的最小改动） |
| 7 | treesitter 缺 tsx / vue / svelte / scss / latex 等解析器 | 写前端时高亮与缩进会缺；前三个建议加进 ensure_installed |
| 8 | autosave 只保存当前 buffer | :qa 对"后台被改过的 buffer"仍弹确认；且每个 BufLeave 都走一遍 conform（含 Java 的 JVM 开销） |
| 9 | lemminx 未裁 filetypes | :checkhealth vim.lsp 常驻 Unknown filetype 'xsl'（同类历史坑的新实例） |
| 10 | **停维护插件替换**（需求变更，我没擅自动） | project.nvim 默认分支 42 个月无提交；dressing 已归档（**已删**）；Comment.nvim 27 个月、bufferline.nvim 20 个月、toggleterm.nvim ~18.5 个月 |
| 11 | 向导 11 步真机走查 | pty 只能确认"能打开、键位已恢复"，完整交互要你点一遍 |
| 12 | pick_many 三条边界 | ① 预勾选后 Tab 追加的时序（改 set_selected 后 pty 验证可追加，真实 Java 工程没走）② <Space> 勾选只在列表窗生效 ③ 字段路径的"真取消"受上游 jdtls.lua:138 不检查返回值限制 |
| 13 | kitty.conf:14 残留对话式注释 | 属别的配置目录，我没动；一句话的事 |
| 14 | .ui-shots/ | 给你看布局对比的**临时图目录**（4 张 PNG），确认不需要可 rm -rf .ui-shots |
| 15 | ~~site/pack/core/opt 空目录~~ | **已撤回该结论**：由 nvim 0.12 内置 vim.pack 每次启动重建，那条 checkhealth 警告是常态，不是缺陷 |

### 19.4 🔴 本次出现过的问题（含我自己的失误，都已修复）

| 事故 | 根因 | 处理 |
|---|---|---|
| **项目历史被清空**（project_history 0 字节，首页按 p 无反应） | 旧代码 read_project_history_sync() 会写 project.nvim 的内存列表，而该插件在 VimLeavePre **截断重写**历史文件；我的 50+ 次 headless 探测触发了它 | 函数改成**只读文件**（清空路径不复存在）；从 shada 恢复 Feed stream / leetcode 并补 ~/Projects/* 带 .git 的项，共 **15 条种子**（原始列表不能完全还原，会随使用自然重建） |
| **picker 的 CR 不确认、Esc 关不掉、向导不推进** | snacks 的 win.*.keys 是**整体替换**语义，我（和向导自带的 win_config()）只写了几个键，把默认 51/44 个键整表干掉 | 三处改为 vim.tbl_extend(force, deepcopy(defaults), 追加)；键表实测恢复 |
| **:Projects 选中后 `Invalid 'dir'`** | source = "projects" **撞上 snacks 同名内置源**（走它的 finder，我们的 items 无效）；且自定义字段 dir 被 snacks 的布尔标志覆盖 | 源改名 project-history、字段改 project_dir、加 file/_path/text 兜底 |
| **neo-tree "文件树刷新失败"（带空格路径必炸）** | 旧写法 Neotree … dir=<路径>：neo-tree 解析器按空格切分参数 | 删该命令，改用 project.lua 里已有的 Lua API 补丁（manager.navigate） |
| **picker 看不出选中 / 面板黑底** | SnacksPickerCursorLine、SnacksPickerBox/List 在所有主题里都是**空组**；theme.lua 还漏了 snacks/flash/notify 三个集成 | 显式给实底/选中色 + 补集成 |
| **恢复素材差点被自己冲掉** | 我的 headless 探测轮换了 shada 的 oldfiles（上限 100 条） | 教训：动用户数据前先快照；本次改为直接从 shada 二进制抓路径 |
| E1568: Terminal did not respond to DSR… | 我这边的**假 pty** 不回应终端查询，与你的配置无关 | 忽略 |

### 19.5 🔧 改动规模与回滚点

- **代码**：21 个文件改动（**+993 / −289**）+ 新增 lua/plugins/devicons.lua；插件 **38 → 36**（删 dressing.nvim、telescope.nvim；plenary 保留给 neo-tree）。
- **文档**：本报告（19 节）+ nvim-config-preflight-20260924.md（动手前评估）+ ~/md/nvim/* 8 个文件 + DSH 技能 architecture.md。
- **回滚点**：

| 目录 | 内容 | 用途 |
|---|---|---|
| ~/backups/nvim-config-final-20260924-231741/ | 最终全量（含 .git）+ **fixes-uncommitted.patch（我的全部改动，可 review / 单独回退）** + diff-stat + system-state | **首选**：看改了什么，或整体回退 |
| ~/backups/nvim-config-preflight-20260924-185532/ | 改造前全量 + 你 6 个未提交改动的 patch + lsp.log.before-truncate.gz + 原始分线报告 | 回到"动手前" |
| ~/backups/skills-layout-20260924-164818/ | DSH 技能目录改造前的 ~/.dsh/skills | 技能目录回滚 |

回滚命令：单文件 `git -C ~/.config/nvim checkout -- <文件>`；整体解包对应 tar。两处**非配置**改动：lsp.log 已清空（备份在 preflight 目录）、project_history 已重建。

### 19.6 🧰 验收清单（可直接复制运行）

```bash
cd ~/.config/nvim
nvim --headless "+qa"                                    # 期望：无输出（启动零报错）
stylua --check .                                         # 期望：只剩 cheatsheet.lua 与 lang/java.lua（你的 WIP）
grep -c '": {' lazy-lock.json                            # 期望：36
ls ~/.local/share/nvim/lazy | wc -l                      # 期望：36
for p in dressing.nvim telescope.nvim; do test -d ~/.local/share/nvim/lazy/$p && echo "$p 还在"; done  # 期望：无输出
wc -l < ~/.local/share/nvim/project_nvim/project_history  # 期望：16（含 1 条本次会话项目）
bash ~/.dsh/skills/dsh/dsh-upgrade/scripts/verify.sh     # 期望：13 通过 / 0 漂移 / 2 警告
```

**交互验收**（真 TTY 逐条点）：<leader>ff/fg/fb/fh/fc/fp（snacks 紧凑列表，<C-j>/<C-k> 上下、一次 Esc 关闭）、:Projects 选**带空格**的项目（应切换 + 文件树跟随）、<leader>ca 代码操作多选（Tab 勾选 / CR 确认 / Esc 取消）、<leader>sp 向导、<leader>db 断点列表、<leader>hk 速查、:PickerSkin soft|pink。

### 19.7 ⚠️ 方法论坑（下个会话 / 其他 agent 直接用）

1. **headless 没有 UIEnter** ⇒ snacks 不接管 vim.ui.*、lazy 的 VeryLazy 也可能没跑；涉及这些的结论**必须用真 pty**。
2. **-c 在 VimEnter 之前执行**，探针要用 --cmd "autocmd VimEnter * lua vim.defer_fn(...)"。
3. **snacks 的 win.*.keys 是整体替换**：要么从 snacks.picker.config.defaults 拷贝再 merge，要么别写。
4. **自定义 picker 的 source 不能撞内置源名**（files/grep/projects/select/… 60+ 个），也不能用 dir 当自定义字段（snacks 会覆盖成布尔）。
5. **neo-tree 命令按空格切分参数** ⇒ 路径不能走 dir=<path>，要用 Lua API。
6. **带"退出回写"的插件**（project.nvim 的 history）：不要写它的内存状态，否则等于替它决定落盘内容。
7. **vim.wait 不处理按键**；which-key.show() 会挂住 headless；nvim__inspect_cell 别乱试（会挂）。
8. **探测会污染 shada**：要恢复用户数据，先在探测前做快照。
9. 假 pty 的 E1568（DSR/背景色）是噪音，不是配置问题。

### 19.8 📌 下一轮建议顺序

1. 你 commit/stash 那两个 WIP 文件 → 跑 stylua . 收尾格式。
2. 四个小改（各 1-3 行）：springboot.lua 去 lazy=false、lang/init.lua 加 notify、statusline.lua 修 neo-tree 死配置、lsp/init.lua 裁 lemminx filetypes。
3. 诊断显示升级（virtual_lines + float 去内部码）—— 观感会变，需要你点头。
4. treesitter 补 tsx / vue / svelte。
5. 停维护插件替换（project.nvim / Comment / bufferline / toggleterm）—— 需求变更，需你先决定。

---

## 20. 第九批：按 §19.8 继续收尾（2026-09-24 深夜第二轮，用户："根据文档继续处理问题"）

> 本节是**最新一轮**记录，§19 仍是第一轮交接快照；凡与 §19.3 冲突，**以本节为准**。所有结论都有真机证据（headless 探针 / 真 pty / 进程表 / 配置文件核对）；**故意没做、仍等你点头的项在 20.2**，本轮新踩的坑在 20.3。

### 20.1 ✅ 本轮已解决（10 项）

| # | 事项（对应 §19.3 编号） | 改动 | 证据 |
|---|---|---|---|
| 1 | ④ `lang/init.lua` 的 pcall 静默吞错 | 抽出 `load_lang(name)`：失败时 `vim.notify(..., ERROR)`（含文件名+原因）并返回 `{}`，其余语言照常加载 | 探针把 `plugins.lang.rust` 注入抛错 → 收到 **1 条 ERROR**，其余 4 门语言 spec 正常，SPECS_COUNT=7 |
| 2 | ③ `springboot.lua` 的 `lazy = false` | 去掉；改 `cmd = { "SpringBoot" }` 保住启动期命令。`springboot-nvim` 加 `cmd = { "SpringBootNewProject" }`（它的命令由自己注册，而 `<leader>sP` 是全局键，不声明 `cmd` 时在非 java 缓冲区按会 E492） | 启动后 `:SpringBoot`/`:SpringBootNewProject`/`:SpringBootCreate` 的 `exists()` 都是 **2**；`:SpringBoot @` 实测拉起插件并执行；启动期已加载列表里**没有** spring-boot.nvim / nvim-jdtls（旧 `lazy=false` 会把 nvim-jdtls+DAP 拖进启动期，并让同 spec 的 `ft` 变死配置） |
| 3 | ⑤ statusline 的 neo-tree 死配置 | `disabled_filetypes` 只留 `alpha`（原来的 `{"neo-tree","alpha"}` 与 `extensions.neo-tree` 互斥：禁用时 lualine 返回空串，扩展永远轮不到生效） | 真 pty：`LASTSTATUS=3`、`LUALINE_LOADED=true`、把光标切到 neo-tree 窗口后 `nvim_eval_statusline` **渲染长度 80**（改前是整条空白） |
| 4 | ⑨ lemminx 未裁 filetypes | 显式 `filetypes = { "xml", "xsd", "xslt", "svg" }`（lspconfig 默认表里的 `xsl` 是"扩展名当 filetype"；runtime 把 .xsl/.xslt 都识别成 filetype `xslt`） | `:checkhealth` 里 `Unknown filetype` 命中数 **0**（改前固定 1 条）；健康报告 lemminx 段显示 `filetypes: xml, xsd, xslt, svg` |
| 5 | ⑦ treesitter 缺前端解析器 | `ensure_installed` 补 `typescript / tsx / vue / svelte / scss`；`highlight_filetypes` 补 `typescript / typescriptreact / vue / svelte / scss` | 5 个解析器全部 `Language installed`；探针对这 5 个 filetype 各建缓冲区跑 `vim.treesitter.start()` → `highlighter.active = true`（sh / jsonc / yaml 一并复核通过） |
| 6 | ⑦ 附：装不上时会刷屏 | 缺解析器时的自动下载加 **6 小时节流**（stamp：`~/.local/state/nvim/treesitter-install-stamp`），节流期内只发一条 INFO，不再联网 | 控制组（无 stamp）：进程表出现 `curl … tree-sitter-scss …`、stamp 被写入；实验组（stamp 新鲜）：**无下载进程**、stamp 内容未被改写 ⇒ 确实走了"跳过"分支 |
| 7 | ⑧ autosave 只保存当前 buffer | `QuitPre` / `VimLeavePre` 改为保存**所有**被改过的缓冲区（统一 `is_savable` 判定 + 重入保护 + `nvim_buf_call` 逐个写）；`BufLeave` / `FocusLost` 仍只存当前 | 两个缓冲区同时在内存里改过 → `:qa` **无 E37**、两份文件内容都落盘（对照实验证明 `:1write` 这种"缓冲区号当计数"的写法是静默 no-op） |
| 8 | ⑥ 诊断浮窗里的内部码 | `float.suffix` 自定义：**只**丢掉纯数字码（jdtls 的 `[603979884]`），保留 `E0308`、eslint 规则名这类有意义的文字码 | 探针：`suffix{code=603979884}` → `""`；`{code="E0308"}` → `" [E0308]"`；无 code → `""` |
| 9 | ⑩ 停维护插件——第一项（唯一低代价项） | 删除 `lua/plugins/comment.lua` + `:Lazy! clean`；注释改由 **Neovim 内置**（0.10+）提供 | `maparg("gc"/"gcc")` 指向 `vim/_core/defaults`；`gcc` 可反复切换、可视 `gc` 注释两行；`lazy/Comment.nvim` 目录消失、插件 **36 → 35**、`lazy-lock.json` 不再引用 |
| 10 | ⑬⑭ 卫生项 | `~/.config/kitty/kitty.conf:14` 的对话式注释改成正常注释；`.ui-shots/`（4 张临时截图）归档到 `~/backups/nvim-ui-shots-20260924/` | 第 14 行现为 `remember_window_size no      # 不记忆上次窗口大小（固定初始尺寸）`；`~/.config/nvim` 下已无 `.ui-shots`，备份目录里 4 个 PNG 完好 |

### 20.2 ✅ 已全部结清（原「本轮故意没做」；3 项均已拍板落地，见 §27.2）

| # | 事项 | 为什么没动 | 怎么开 |
|---|---|---|---|
| 1 | ~~诊断 **virtual_lines**（⑥ 的另一半）~~ **已于 2026-09-25 开启**（用户点头） | 实现见 **§22.5.1**：`virtual_text.current_line=false` + `severity={min=WARN}`、`virtual_lines={current_line=true, severity={min=WARN}, format=去内部码}` | 要退回最小改动：删 `virtual_lines` 两行、`virtual_text` 去掉 `current_line`/`severity` 即可 |
| 2 | Java 构建/Maven 键仍是 **buffer-local**（② 的一半） | 只挂在 jdtls 附加的缓冲区上，非 Java 缓冲区按 `<leader>mc` 无反应 | ✅ **2026-09-25 已决定保持 buffer-local**（§23.3 #2）：实测全局化会在含 `pom.xml` 的目录里直接跑 `mvn compile` |
| 3 | **project.nvim / bufferline.nvim / toggleterm.nvim** 替换（⑩ 其余三项） | 三者都还能用，替换属需求变更、代价中～高（见 20.2.1） | ✅ **2026-09-25 已决定维持**（§23.3 #1）：上游实查均**未归档**（最后提交 2024-08-12 / 2025-01-14 / 2025-03-09） |

#### 20.2.1 停维护插件调研结论（2026-09-24 快照，四个都**没有**归档、也没有停维护声明，属"事实停更"）

| 插件 | 默认分支最后提交 | 替代方案 | 代价与风险 | 建议 |
|---|---|---|---|---|
| numToStr/Comment.nvim | 2024-06-09（27 个月） | **Neovim 内置 gc/gcc**（0.10+） | 极低 | **本轮已做**（见 20.1 #9）。代价：内置**没有** `gb`/`gbc`（块注释）和 `gcO`/`gco`/`gcA`，本配置与文档都没用过这些键 |
| ahmedkhalf/project.nvim | 2023-04-04（42 个月） | ① 活跃 fork `DrKJeff16/project.nvim`（2026-09-22 仍在推）：**模块名从 `project_nvim` 改成 `project`**，本配置的 `plugins/project.lua` 补丁与 `core/commands.lua` 读 `project_nvim.utils.path.historyfile` 都得改，且**该 fork 是否沿用现有历史文件未核实**（搞错就又是一次历史清空）② 彻底去插件：`vim.fs.root()` + 自维护历史 | 中～高 | **暂缓**：LazyVim（2026-09）自己仍依赖 ahmedkhalf 版；要动先备份 `project_history` |
| akinsho/bufferline.nvim | 2025-01-14（20 个月） | barbar.nvim（2026-06 活跃，功能最接近）；mini.tabline（极简，但文档明写不支持自定义顺序、无诊断/关闭按钮） | 中：`<S-h>`/`<S-l>`、catppuccin 的 `special.bufferline` 高亮、`close_command`、诊断计数都要重做 | **暂缓** |
| akinsho/toggleterm.nvim | 2025-03-09（18.5 个月；本机装的还是 2024-12-30 提交） | snacks.terminal（同一家，已有 snacks） | 中～高：三个终端 id 的"方向+尺寸记忆"与两个已被实测踩过的坑要重写重验（`smart_toggle` 带 direction 只关不开、浮窗内 `Terminal:open()` 静默失败）；且 `plugins/snacks.lua` 现在**显式关掉了** snacks.terminal（注释写着"会顶掉 toggleterm"） | **暂缓** |

### 20.3 🔍 本轮新踩的坑（已同步进 DSH 技能）

1. **GitHub 下载要走本机 Clash 代理**：`~/.config/fish/conf.d/proxy-env.fish` 只在代理监听时才导出 `HTTPS_PROXY=http://127.0.0.1:7890`。从 fish 启动的 nvim 有代理；headless/非 fish 环境没有 ⇒ nvim-treesitter 用 curl 拉 GitHub 必然超时，解析器装不上（**这就是本轮一开始"5 个解析器装不进去"的真正原因**，不是配置错）。手动装法：`HTTPS_PROXY=http://127.0.0.1:7890 nvim --headless -c "lua require('nvim-treesitter').install({...}):wait(420000)" -c "qa!"`。
2. **`:{N}write` 不会写缓冲区 N**：`:1write` 对被改过的 buffer 1 是**静默 no-op**。要写指定缓冲区用 `vim.api.nvim_buf_call(buf, function() vim.cmd("silent! lockmarks write") end)`（实测成功且当前窗口/缓冲区不变）。
3. **lazy 的 `cmd` 桩能让"插件 setup() 里注册的命令"在启动期就存在** ⇒ `ft` 懒加载插件也能保住启动即可用的命令（本轮 `:SpringBoot` / `:SpringBootNewProject` 就是这么修的）。
4. **nvim-treesitter 自带 filetype→parser 别名注册**（`plugin/filetypes.lua`：tsx↔typescriptreact、json↔jsonc、bash↔sh、xml↔xsd/xslt/svg…）⇒ 装好解析器即可，**不需要**自己写 `vim.treesitter.language.register`。
5. **`:checkhealth vim.lsp` 的 "Unknown filetype" 判定 = 服务端 filetypes 里出现了"扩展名而不是真 filetype"**（`xsl` 的真身是 `xslt`）。任何 server 的默认表都可能带这种条目。
6. **探针自己也会制造假象**：headless 探针里给缓冲区设 `filetype = "yaml"` 会触发 `ft` 懒加载，把 spring-boot.nvim / nvim-jdtls 加载进来——第一遍差点误判成"启动期就加载了"。凡"启动期加载了什么"的结论，探针里别碰 filetype。
7. **lualine 的 `disabled_filetypes` 与 `extensions` 互斥**（禁用优先），配合 `globalstatus` 就是"切到那个窗口整条状态栏空白"。

### 20.4 📚 文档同步（本轮）

| 文件 | 改了什么 |
|---|---|
| `~/md/nvim/nvim插件介绍.md` | Comment.nvim 段落改写为"注释由 Neovim 内置提供"（含 gb/gbc 缺失说明）；配置文件对应表删掉 `plugins/comment.lua`；插件总数 36 → **35**；treesitter 清单补 5 个前端解析器；lualine 备注改为"仅 alpha 隐藏状态栏（neo-tree 现在照常显示）"；springboot 段落的加载方式改为 `cmd + ft` |
| `~/md/nvim/nvim配置架构.md` | 目录树删掉 `comment.lua`；treesitter / lemminx 相关行更新 |
| `~/md/nvim/nvim快捷键.md` | 注释一节标注为"Neovim 内置映射"，并说明没有 `gb`/`gbc` |
| DSH 技能 | `nvim-troubleshooting/references/nvim-troubleshooting-history.md` 新增 **§12「插件精简与启动收尾」12.1–12.9**（537 → 672 行）；`local-patterns.md` 补 7 个小节并把启动基线改成实测集合；`nvim-config/references/architecture.md` 特殊处理表补 7 行、目录树删 `comment.lua`；两个 `SKILL.md` 的章节速查/约定同步 |

**本轮文档交叉核对又抓出一条陈年错误**：`:Projects` 的自定义 picker 源名在**文档里一律写成 `source = "projects"`**，而代码早已改成 `project-history`（§18：`projects` 是 snacks 内置同名源，会走它的 finder ⇒ 选中项目报 `Invalid 'dir'`）。已修正 5 处：`~/md/nvim/nvim自定义命令.md`、`~/md/nvim/nvim配置架构.md`、技能 `architecture.md`、`local-patterns.md`，并在 `nvim-troubleshooting-history.md` §10.1 下加了带原因的更正注记。同时把 `nvim-config/references/local-checklist.md` 里 3 处 Telescope 时代检查项改写成 snacks 版（§2.1 / §2.1.1），并精修了两个会误报的 grep（注释里提到插件名不该算命中）。

### 20.5 🧾 验收清单（本轮更新版，可直接复制）

```bash
cd ~/.config/nvim
nvim --headless "+qa"                                    # 期望：无输出
stylua --check .                                         # 期望：只剩 cheatsheet.lua 与 lang/java.lua（你的 WIP）
grep -c '": {' lazy-lock.json                            # 期望：35
ls ~/.local/share/nvim/lazy | wc -l                      # 期望：35
ls ~/.local/share/nvim/site/parser | grep -cE '^(tsx|vue|svelte|scss|typescript)\.so$'   # 期望：5
nvim --headless '+checkhealth' '+write! /tmp/h.txt' '+qa!' < /dev/null >/dev/null 2>&1
grep -c "Unknown filetype" /tmp/h.txt                    # 期望：0
wc -l < ~/.local/share/nvim/project_nvim/project_history  # 期望：≥16
bash ~/.dsh/skills/dsh/dsh-upgrade/scripts/verify.sh      # 期望：13 通过 / 0 漂移 / 2 警告
```

**交互验收**（真 TTY）：`gcc`/`gc`（内置注释，应可用）、`<leader>e` 后**底栏不该空白**、`<leader>ff/fg/fb/fh/fc`、`:Projects` 选带空格项目、`<leader>ca` 多选、`<leader>sp` 向导、`:SpringBoot`（spring-boot 符号查询）、`:qa` 不再对后台改过的文件弹确认。

### 20.6 🔧 本轮改动规模与回滚

- 本轮代码改动：`lua/core/autocmds.lua`、`lua/core/options.lua`、`lua/plugins/statusline.lua`、`lua/plugins/treesitter.lua`、`lua/plugins/lsp/init.lua`、`lua/plugins/lang/init.lua`、`lua/plugins/lang/springboot.lua`，删除 `lua/plugins/comment.lua`（连带 `lazy-lock.json` 更新）；配置目录外：`~/.config/kitty/kitty.conf`。
- ⚠ 补丁的 diff 基线是 **HEAD**：`core/autocmds.lua` 与 `plugins/treesitter.lua` 里本来就含你**未提交的 WIP**（自动保存雏形、treesitter 的自装逻辑），所以这两个文件的 hunk 比"本轮改动"大；本轮只改了自动保存的触发范围/实现与解析器清单/节流。你的两个 WIP 文件（`core/cheatsheet.lua`、`plugins/lang/java.lua`）本轮**一行未动**（diff 仍是 18 / 264 行）。
- **本轮快照**：`~/backups/nvim-config-round2-20260924-233519/` —— `nvim-config-round2.tar.gz`（全量，含 `.git`，解包后与现场**逐字节一致**）+ `fixes-round2.patch`（17.9 KB，只含本轮 9 个路径：8 个 Lua 文件 + `lazy-lock.json`，可直接 review）+ `diff-stat.txt` + `system-state.txt`；指针文件 `~/backups/.last-nvim-config-round2`。第一轮的全量快照 `~/backups/nvim-config-final-20260924-231741/` 仍然有效。
- 回滚：单文件 `git -C ~/.config/nvim checkout -- <文件>`；**想恢复 Comment.nvim**：`git -C ~/.config/nvim checkout -- lua/plugins/comment.lua` 然后 `:Lazy sync`。
- 归档：`.ui-shots` → `~/backups/nvim-ui-shots-20260924/`。






---

## 22. 第六轮：全面复查（2026-09-25，用户："再次全面检查并修复"）

> 三条并行只读审查线（视觉一致性 / 正确性与兼容性 / 交互体验与性能）在跑，本节先记录 Lead 自己这条线的结果；审查线的发现会追加到 §22.x。

### 22.1 本轮修掉的问题

| # | 问题 | 证据 | 修法 |
|---|---|---|---|
| 1 | **`:JavaBuildProjects` / `:JavaSetRuntime` 在非 Java 会话里不存在**（文档和速查都写了它们，但它们是 nvim-jdtls 的 config 里注册的 ⇒ 只有打开过 .java 才会注册，直接输会 E492） | 探针：启动后 `exists(':JavaBuildProjects')=0`、`exists(':JavaSetRuntime')=0`（`:JavaRun`/`:SpringBootCreate` 都是 2） | nvim-jdtls spec 加 `cmd = { "JavaBuildProjects", "JavaSetRuntime" }`（lazy 桩，启动即存在）**并**给两个命令加守卫：没有 jdtls 客户端时提示"需要先打开一个 Java 项目（jdtls 尚未附加到任何缓冲区）"。实测：两命令 `exists()` 从 0 → **2**，空会话下调用不再报错、弹出上述提示（`vim.notify` 捕获到 2 条 level=3） |
| 2 | 速查面板里"有前提的键"没说前提（LSP 键、Java 键在普通缓冲区按了没反应） | cheatsheet 89 条自动核对：`gd/gh/gi/gA/<leader>ca/<leader>rn/[d/<leader>mc…` 在无 LSP/无 Java 的会话里确实没有映射 | 小节标题补作用域：**代码导航（LSP：需 LSP 附加）**、**代码操作（需 LSP）**、**Java / Spring Boot（需 Java 缓冲区）**、**Maven / Gradle（需 Java 项目）**、**补全（blink.cmp：插入模式）** |
| 3 | **`:PickerSkin pink` 是"半粉混搭"**：切到 pink 后只有标题/计数变粉，边框仍是灰的、面板仍是实底（因为 soft 皮肤把这些组设成了非 default，而向导的 `SNACKS_HL` 里没有它们） | 探针：`SnacksPickerBoxBorder=#7f849c`（应粉）、`SnacksPickerBox=#1e1e2e`（pink 皮肤设计是透明底） | 向导的 `SNACKS_HL` 补上 `SnacksPickerBoxBorder/ListBorder/Box/List/Input` 五组 ⇒ pink = 粉边框 + 透明面板，soft = 灰边框 + 实底，来回切换实测都正确 |
| 4 | 文档写 `<leader>db` 是"`vim.ui.select` → snacks picker"，实际是 `dap.list_breakpoints()` 打开 **quickfix 窗口** | `dap/init.lua:84-86`；pty 实测：打一个断点后按 `<leader>db` 出现 `qf@split` 窗口，没有 picker | 速查面板 + `~/md/nvim/nvim快捷键.md` 的描述改成"打开 quickfix 窗口" |
| 5 | 上一轮我写的 `winhl` 赋值被 stylua 要求单行 | `stylua --check lua/core/cheatsheet.lua` 差异区间 300-307（"是我的行"） | 改成单行；现在该文件的差异只剩用户 WIP 的 146-159 区间 |

### 22.2 复查过、确认没问题的（避免下一轮重复劳动）

| 项 | 结论 | 证据 |
|---|---|---|
| 启动 | 零报错、退出码 0 | `nvim --headless "+qa"` 无输出 |
| 启动期加载 | 只有 15 个插件（catppuccin / mason 三件套 / blink / noice / nui / notify / lspconfig / treesitter / devicons / project / snacks / lazy / friendly-snippets）；jdtls、dap、alpha、lualine、bufferline、toggleterm 都是懒加载 | `require("lazy").stats()` + `lazy.core.config.plugins[*]._.loaded` |
| 弃用 API | `vim.deprecated: ✅ No deprecated functions detected` | `:checkhealth` 落盘 |
| checkhealth 里的 ❌/⚠️ | 全部是**良性噪音**：① `Snacks.image/lazygit/notifier/words…` 这些**已禁用**的模块仍会跑自己的工具检查（magick/gs/tectonic/mmdc/lazygit）② `vim.ui.input/vim.ui.select` 的 ERROR 是 **headless 没有 UIEnter**（真 TTY 实测已是 snacks）③ `vim.pack` 的 lockfile 警告是 0.12 内置 `vim.pack` 常态 ④ mason 的 luarocks/ruby/php/julia/pip 是系统可选依赖 ⑤ blink/lazy 各 1 条是说明性提示 | `/tmp/r5-health.txt` 逐节核对：`vim.deprecated ✅`、`vim.lsp ✅`、`Unknown filetype = 0`、`nvim-treesitter ✅`、`mason-lspconfig ✅`、`noice ✅` |
| 文档 vs 配置（键位） | **我们自己的键位全部有文档**；自动比对里"未文档化"的 49 个是 **Neovim 0.12 内置默认**（`[b`/`]t`/`[%`/`gx`/`grx`/`gO`/`<C-W>d` 等），不属于本配置 | 脚本：dump 116 个真实映射 + lazy keys → 与 `~/md/nvim/*.md` + cheatsheet 里的 token 比对 |
| 文档 vs 配置（命令） | 0 缺失（修完 #1 之后） | `:Projects/:LspInfo/:LspLog/:JavaRun/:JavaBuildProjects/:JavaSetRuntime/:SpringBootCreate/:SpringBoot/:SpringBootNewProject/:PickerSkin` 全部 `exists()=2` |
| 速查面板条目 | 89 条；标记"未映射"的 38 条经分类：LSP/Java 键（buffer-local，符合预期）、blink 的插入模式键（`<Tab>`/`<C-n>`/`<C-e>` **在 InsertEnter 时才装**，实测真插入模式里都在）、`<C-h/j/k/l>`/`J / K` 这类**多键合写的说明行**、Neovide 的 `<C-=>` 等（速查里已标"仅 GUI"） | 探针：真 pty 进插入模式后 `maparg("<Tab>","i")` 指向 `blink/cmp/keymap/apply.lua:51`，`<S-Tab>/<C-n>/<C-e>/<C-u>` 同理 |
| TODO/FIXME 残留 | 0 处 | `grep -rn "TODO\|FIXME\|HACK"` |
| 插件集合 | 35 个全部被实际引用（没有装了不用的） | 逐个 grep 引用 |



### 22.5 三条审查线的发现与修复（2026-09-25，全部逐条复核后落地）

三条只读审查线（视觉一致性 / 正确性与兼容性 / 交互体验与性能）共报 P1 5 项、P2 11 项、P3 十余项。**逐条实测复核后**修复如下（未修的都写明原因）。

#### P1（真 bug，全部已修并验证）

| # | 问题 | 证据 | 修法 / 验证 |
|---|---|---|---|
| 1 | **非 modifiable 缓冲区按 `J`/`K` 抛 `E5108`**（终端缓冲区、所有 picker 列表窗、alpha、`:help`、quickfix、neo-tree、速查面板） | `core/keymaps.lua:78` 的 `move_current_line` 直接 `nvim_buf_set_lines` 无守卫（同文件的可视版 `move_visual_lines` 有守卫，属漏写）；审查线真机复现 | 函数开头加 `if not vim.bo.modifiable then return end`。验证：pty 里在终端缓冲区与 picker 列表窗按 `J`/`K` → `errmsg=""`（修前必报 E5108） |
| 2 | **`{Visual}<leader>Rv/RV/Rc/Rm` 会删掉选区并写入 `v`** | 只有 n 模式映射（`lang/java.lua:496-499`），而文档/速查都写"先可视模式选中"；Vim 里 `{Visual}R` = 删行 + 进替换模式 | 补 4 条 **x 模式** 映射（`extract_*(true)`），n 模式保留"光标处表达式"语义。文档与速查同步改成"可视=选区，普通=光标处" |
| 3 | **jdtls 多选弹窗 `<Space>` 勾选报错** | 动作调 `pk.list:toggle()`，而本机 snacks 的 List **没有 toggle**（实测 `type(L.toggle)=nil`，上游也没有同名 action） | 改 `pk.list:select()`（内部先 unselect，本身就是切换）。验证：`list.select=function` |
| 4 | **picker 卡片高度 off-by-one：底边框被列表盖掉、最底 1 行漏到卡片外** | 实测 160×50：box `h=18`、input `h=1 @row0`、list `h=16 @row2` ⇒ 占用 18 > 内高 16，屏幕上**看不到 `╰──╯` 底边框**；80×24 时底边框画到 alpha 文字上 | 在 `picker_compact` 预设加**顶层** `config` 回调，按 `floor(lines*height)-2` 反算内高、把 list 高度显式设为 `内高-2`。⚠ 两个坑：`config` 必须与 `layout` 同级（写进 `layout.layout` 会被当 box 选项丢掉）；snacks 的 `size()` 还会再减一次边框，所以是"减两次"。验证：160×50 → box16/input1@0/list14@2（2+14=16 正好贴合，底边框可见）；80×24 → box5/list3@2 ✔；160×36 → box10/list8 ✔ |
| 5 | **pink 皮肤下输入框仍是灰边**（`SnacksPickerInputBorder`/`InputTitle`、`SnacksInput*` 未进 `SNACKS_HL`） | 视觉线 headless + 真机对比：pink 时 `SnacksPickerInputBorder=#7f849c`、`SnacksInputNormal bg=#1e1e2e` 都没变 | 向导 `SNACKS_HL` 补齐 `SnacksPickerInputBorder/InputTitle`、`SnacksInputBorder/Title/Normal`、`NoiceCmdlinePopup(Border)`。验证：pink 下这些组全部变 `#f38ba8`/透明；soft 下回到灰边/实底 ✔ |

#### P2（已修）

| # | 问题 | 修法 |
|---|---|---|
| 1 | **全机两套浮窗边框色**：picker/速查灰 `#7f849c`，而 noice 命令行、LSP 悬浮/签名、诊断浮标、blink 文档、which-key、dap-ui 全走 catppuccin 的蓝 `FloatBorder` | `apply_skin()` 里写全局 `FloatBorder=#7f849c`、`FloatTitle=#89b4fa bold`（pink 时向导写粉色版本）。验证：两个皮肤下 headless dump 全组一致 |
| 2 | 标题三种样式（picker 蓝粗 / noice 灰斜体 / LSP 无） | 同上（`FloatTitle` 一处修全部） |
| 3 | pink 下 noice 命令行弹窗/输入框不跟随 | 见 P1-5（补进 `SNACKS_HL`） |
| 4 | noice 命令行弹窗透明、透出启动页文字 | `apply_skin()` 加 `NoiceCmdlinePopup bg=#1e1e2e`（pink 时 `NONE`） |
| 5 | 通知 fade 期间边框被压暗（`#f9e2af→#f8e2af`、`#f38ba8→#c16f86`） | `noice.lua` 的 nvim-notify `background_colour` 从 `#000000` 改成 `#1e1e2e`（它是**混合基准色**不是卡片底色） |
| 6 | `:messages` 是底部 20% 全宽 split，和全机卡片风格不一致 | `noice.lua` 加 `views.messages = { view = "popup", … }`。验证：真机 `:messages` 现在是居中圆角弹窗 |
| 7 | jdtls `pick_many` 取消返回 **nil**（上游契约要求 table），且 `coroutine.resume` 的错误被吞 | `return coroutine.yield() or {}`；resume 加 `ok, err` 检查并 `vim.notify(ERROR)` |
| 8 | `<leader>dL`/`<leader>dB` 按 Esc 仍会设出空 condition/logMessage 的"假断点" | 空输入直接不建 + INFO 提示（`vim.fn.input` 取消返回 `""`，Lua 里为真） |
| 9 | Java `<F5>` 手输主类时默认值被追加（`DemoApplicationcom.example.App`） | 默认值只写进提示文本、空输入取默认（与向导同一手法） |
| 10 | neo-tree `p` 被抢成 toggle_hidden ⇒ `y/x/c` 复制剪切后无粘贴入口 | 删掉该映射（隐藏文件用 neo-tree 自带 `H`）；文档/速查同步 |

#### P3（已修）

- **诊断跳转弃用项**：`[d`/`]d` 的 `jump({float=true})` 在 0.12 已软弃用（`vim.deprecate('opts.float','opts.on_jump','0.14')`，实测 runtime 源码）⇒ 改显式 `on_jump + open_float`。验证：手动造两条诊断，`]d` 跳到第 3 行、开 1 个浮窗、焦点不抢、无弃用告警。
- **速查面板**：顶栏加"`j/k 滚动 · q / Esc 关闭`"（123+ 行在小终端只显示得下 41 行）；补 `<leader>he`/`<leader>hh` 与 `:JavaBuildProjects`/`:JavaSetRuntime` 条目。
- **向导死代码**：`define_highlights()` 里第二道 `picker_skin` 守门恒假 ⇒ 删；多选结构断言只 notify 不中断 ⇒ 改成 `finish({})` 后中止（否则会带着 0 依赖继续创建）。
- **`DirChanged` 无条件记 cwd** ⇒ 只在目录含项目标志（.git/pom.xml/build.gradle/package.json/go.mod/Cargo.toml/pyproject.toml/CMakeLists.txt/.hg）时才记。验证：`:cd /tmp` 不再进副本。
- **残留注释**里的 dressing/telescope（noice.lua:4、snacks.lua:9、devicons.lua:5、keymaps.lua:17）已改。

#### P2（追加）：`vim.ui.select` 的高度同样溢出

snacks 的 `ui.select` 自带 `layout.config`（按条目数算列表高，`select.lua:44-52`），会**覆盖**预设里的高度修正 ⇒ 30 项时 `box 20 / list 18@2` 仍然溢出。修法：在 snacks 之上再包一层 `vim.ui.select`（**只在 UIEnter 之后、且确认当前实现来自 snacks 时才包**——config 阶段立即包会被 snacks 在 UIEnter 覆盖，第一次就白包了一场），先跑它自己的 config 再把 list 高度收 2。验证：30 项 → `box 18 / list 16@2`（正好贴合）；`vim.ui.select` 来源显示为我们的包装函数。

#### 22.5.1 三处"统一"（用户点头后执行，2026-09-25）

| 项 | 改法 | 验证 |
|---|---|---|
| 状态栏中段透明（"洞"） | `statusline.lua` 的 `opts()` 里给主题表**每个模式**的 `c` 段补 `bg=#181825`（原来只有 normal 有 c、其余靠继承） | 真 pty dump：`normal c.bg=#181825`；headless 看不到是因为 lualine 在 UIEnter 才加载（老陷阱） |
| 背景两档（picker base vs 其它浮窗 mantle/透明） | `apply_skin()` 给 `NormalFloat` 补 `bg=#1e1e2e` ⇒ which-key / LSP 悬浮 / 诊断浮标 / blink 文档全变成与 picker 同色的实底卡片；pink 皮肤下回 `NONE`（洋红那套本来就是透明面板） | 真 pty：自建一个带边框的浮窗，边框 `#7f849c`、标题蓝、内部实底 base（截图 `float-after.png`）；两态 dump：soft `#1e1e2e` / pink `NONE` |
| 宽屏下 picker 只有 49% 宽 | 预设 `width` 从继承的 `0.5` 改成函数 `max(40, min(110, floor(columns*0.55)))` | 实测：160→88、120→66、100→55、80→44 ✔（窄终端仍夹在 40 列起） |
| **诊断 `virtual_lines`**（§19.3 第 6 项的最后一半，用户点头后开启） | `options.lua`：`virtual_text.current_line=false` + `severity={min=WARN}`；`virtual_lines={current_line=true, severity={min=WARN}, format=function(d) return d.message end}` | 真 pty 造三条诊断：当前行 ERROR → 下一行整行展开（红色，且**没有** `[603979884]` 内部码，因为自定义 format 去掉了）、非当前行 WARN → 行尾 `●` 文字（黄）、HINT → 只有符号列 ✔。INFO/HINT 从此不再占行尾 |

#### 仍留着的（已记录，等你点头或确认无感）

| 项 | 现状 | 建议 |
|---|---|---|
| 状态栏中间段透明（lualine `c` 段 bg=NONE，两端是实色块） | 主题 `transparent_background` 的既定副作用，与"实底卡片"不一致 | 要统一的话给 lualine 的 `c` 段显式 `bg=#181825`；**观感会变**（整条状态栏变实底），等你一句话 |
| 背景两档（picker base `#1e1e2e` vs which-key/LSP 浮窗 mantle `#181825`） | 已通过 FloatBorder/FloatTitle 统一了"边框与标题"，底色仍是主题默认 | 要全统一把 `NormalFloat` 也写实底，但会影响所有浮窗（含 LSP 悬浮） |
| 宽屏下 picker 卡片宽 49%（`width=0.5`，`max_width=100` 没触到） | 有意为之的紧凑风格 | 想更宽改预设 `width` |
| alpha 按钮强调色 `#74c7ec` 与 picker 的 `#f9e2af` 不是同一支；bufferline 透明底 | 主题自带 | 属可选调色 |
| neo-tree 80 列下分隔符 1 列错位 | 边界情况，160 列正常 | 未复现到稳定结论，先记着 |

### 22.4 真机走查（120×32 与 80×24 两种终端）

| 路径 | 结果 | 备注 |
|---|---|---|
| `:Neotree show/close` | ✔ 2 窗 → 1 窗 | |
| `<leader>ff/fg/fb/fh` | ✔ 都开出紧凑 picker（list/input/box 三窗），**一次 Esc 关闭**（窗口数回到 1） | `<leader>fb` 用真键验证：4 窗 → Esc → 1 窗 |
| `vim.ui.select` / `vim.ui.input` | ✔ 分别开 `snacks_picker_*` / `snacks_input` | |
| `<leader>hk` 速查 | ✔ 开/关正常；80×24 下窗口 76 列、内容自动裁剪在框内 | |
| `:Projects` | ✔ 开/关正常 | 切换项目在 §21 已验 |
| `<leader>tt/th/tv` | ✔ float → horizontal → vertical 三实例共存（再按 `tt` 浮窗回来，共 4 窗）；与注释里"浮窗聚焦时先切窗（副作用浮窗关闭）"的既定行为一致 | 用 mapping.callback 直接调（真键会被终端模式吃掉） |
| `<leader>db` | ✔ 有断点时打开 **quickfix 窗口**列出断点（无断点时静默） | ⚠ 文档原写"vim.ui.select → snacks picker"，**已订正**（速查 + 快捷键文档） |
| `:LspInfo`（0 客户端） | ✔ 走 `vim.notify` → noice 弹窗 | |
| `:JavaBuildProjects`（无 Java） | ✔ 友好提示，不报错 | 见 22.1 #1 |
| `gcc` 注释 | ✔ 内置注释生效（`-- local x = 1`） | |
| 80×24 窄终端 | ✔ files picker 40 列居中不溢出；速查 76 列、行尾被正确裁剪 | 单元格级 dump 核对（不是看截图猜的） |
| 懒加载验证 | `<leader>tt` 首次按下时拿到的是 lazy 桩映射（会先加载插件再回放按键）⇒ 用 `maparg(...).callback` 直接调用会"看起来没反应"；**这是探针陷阱，不是配置问题** | 记录以免下轮误判 |

### 22.3 顺手记下的容量事实（不是问题，供参考）

- `~/.local/share/nvim/site/jdtls-workspace` = **397 MB**（Java 项目索引缓存，按项目名+哈希分目录）；`site/parser` 16 MB；`lazy/` 109 MB。
- `lsp.log` 172 KB（已限 ERROR 级）、`mason.log` 632 KB、`nvim.log` 72 KB。
- 想清 Java 索引缓存：`rm -rf ~/.local/share/nvim/site/jdtls-workspace/*`（下次打开 Java 项目会重建，首次导入会慢一些）。

## 23. 工作台账（2026-09-25 10:5x，压缩后从这里继续）

> 用户要求："先更新当前目录下面的工作文档…然后对工作文档进行标记：哪些解决了、哪些没有解决、哪些需要解决、哪些还没有查出来的"。本节就是**唯一台账**；§0–§22 是过程记录，本节是状态汇总。
> 状态图例：✅ 已解决（有实测证据）　⏳ 未解决（写明阻塞）　🟡 待你决定　❓ 尚未排查/未证实

### 23.1 ✅ 已解决（按主题汇总，共 40+ 项）

| 主题 | 内容 | 见 |
|---|---|---|
| 主题/观感 | 状态栏主题退化、lualine 的 neo-tree 死配置、picker 皮肤与高亮组补齐（SnacksTitle/BoxBorder/ListBorder/Prompt/InputBorder…）、全机 `FloatBorder`/`FloatTitle`/`NormalFloat` 统一、noice 弹窗实底、`:messages` 改居中 popup、通知 fade 混合色、状态栏中段实底、picker 宽度自适应（160→88/120→66/100→55/80→44） | §19.2 §21.5 §22.5 §22.5.1 |
| 诊断 | `severity_sort`、浮窗去掉 jdtls 内部码、**`virtual_lines`（光标行整行展开）**、`[d`/`]d` 改用非弃用的 `on_jump` | §19.2 §22.5.1 |
| picker | UI 单一化（删 dressing/telescope/Comment）、全局紧凑预设、`:Projects` 观感重做 + 源名/字段修正、**高度 off-by-one（含 ui.select）**、`<Space>` 勾选修好、`pick_many` 取消返回空表 + resume 错误不再吞、`<C-j>/<C-k>`/一次 Esc | §17 §21 §22.5 |
| 数据安全 | 项目历史**三层保护**（只追加副本 ∪ 并集 ∪ append 回填 + `DirChanged` 过滤项目标志），截断成 0 字节可自愈；事故后 17 条已恢复 | §21.2 |
| Java | springboot 懒加载（`cmd` 桩）、`:JavaBuildProjects`/`:JavaSetRuntime` 启动即可用 + 无 jdtls 时友好提示、`<F5>` 手输主类默认值不再被追加、可视模式 `<leader>Rv/RV/Rc/Rm` 补 x 映射 | §22.1 §22.5 |
| 其他正确性 | `J`/`K` 在非 modifiable 缓冲区不再抛 E5108、`<leader>dB/dL` Esc 不再建空断点、neo-tree `p` 恢复粘贴（隐藏文件用 `H`）、自动保存覆盖所有被改缓冲区、treesitter 前端解析器 + 下载节流、lemminx filetypes、`lang/init` 加载失败会报错 | §20 §22.5 |
| 卫生 | lsp.log 清理、`.ui-shots` 归档、kitty 注释、Telescope/dressing 残留注释清理、速查面板补 `he/hh` + 滚动提示 + Java 命令 | §20 §22.5 |

### 23.2 ✅ 已清空（原「未解决」，两项均已结）

| # | 项 | 阻塞/原因 |
|---|---|---|
| 1 | ~~`stylua --check .` 仍有 2 个文件不过~~ | ✅ **2026-09-25 已解决：41/41 通过（exit=0）**（补丁已应用，§26.11）。复核纠正（§26.2）：不是「你的 WIP 引入」——两个文件在 `git show HEAD:` 版本上**同样失败**（cheatsheet.lua 是历史欠账，blame 到 2026-09-02；java.lua 在 HEAD 失败于旧行、当前失败于 WIP 新增块）。所以 `git stash` 不会让它变绿，必须真跑一次 `stylua .`；注意它会改到你 WIP 的 4 处（java.lua:292 / 458-460 / 475-478 + cheatsheet.lua:149-156）。最小序列见 §26.2；**当前 41/41 通过** |
| 2 | ~~未提交的改动~~ | ✅ **2026-09-25 已提交**（用户："开始提交"）：5 个提交 `6e2e29f`（移除已弃用插件）/ `438048f`（UI 观感）/ `c5ab8cf`（LSP·Java·DAP）/ `f1162b8`（core 键位与命令）/ `a9f1232`（审计文档）；提交后 `git status --porcelain` 为空（§26.13） |

### 23.3 ✅ 已决定（2026-09-25，用户："你推荐的来完成即可"）

| # | 项 | 决定 | 落地 |
|---|---|---|---|
| 1 | project.nvim / bufferline.nvim / toggleterm.nvim 是否替换 | **维持** | 无需改动。上游实查均未归档（最后提交 2024-08-12 / 2025-01-14 / 2025-03-09） |
| 2 | Java 构建/Maven 键是否改全局 | **保持 buffer-local** | 无需改动。实测全局化会在含 `pom.xml` 的目录里直接跑 `mvn compile` |
| 3 | which-key 六组（`c/r/J/m/o/R`）是否常显 | **保持上下文相关** | 无需改动。占位会把第一屏 12 项变 18 项，其中 6 项按了没反应 |
| 4 | which-key 右下角英文 footer | **接受** | 无需改动。硬编码 `which-key/view.lua:442/445/448`，全 opts 无文本配置项 |
| 5 | `<leader>s` 语义混合 | **方案 A：窗口切分挪到 `<leader>v`** | ✅ 已改 4 个文件：`keymaps.lua:28-30`（`sh/sv`→`vh/vv`）、`whichkey.lua:34/36`（s=Spring Boot、新增 v=窗口：切分）、`cheatsheet.lua:38-39`、`~/md/nvim/nvim快捷键.md:37-38` |
| 6 | 向导卡片粉系强调色 | **接受现状 + 修 4 处过期注释** | ✅ 已改 `spring_wizard.lua:2/409/416/1113`（纯注释，渲染零变化） |

### 23.4 ✅ 已全部结清（11/11；下表保留原始描述 + 结项标注，逐项证据见 §27）

| # | 项 | 现状 |
|---|---|---|
| 1 | ~~which-key **可视模式**触发器不生效~~ | ✅ **已定位并修复（§26.1）**：根因是 `whichkey.lua:13/19` 的 triggers 只写了 `mode = "n"`，不是上游不支持；已改 `mode = { "n", "v" }`，真 pty A/B 验证（对照 0 弹窗 / 修法弹出 `+Visual » R ➜ +4 keymaps`）。§24 的「三种写法都不注册」结论已证伪 |
| 2 | DAP **真机完整调试**（Java：断点→F5→变量/调用栈/REPL） | ✅ **已在自建 Maven 工程验证（§26.3）**：断点→F5→stopped→变量 `a=3 b=4 result=7`、调用栈 `sum → main`、dapui 六窗、step_over、terminated 全部实测通过（有截图）。唯一未证实：探针用 `session:request` 拉 threads/stackTrace 拿到空数组（dapui 同期正常），排查方向见 §26.3 |
| 3 | Java 项目的 LSP 重命名/代码操作/测试运行真机走查 | ✅ **已验证（§26.3）**：hover / definition / references / documentSymbol / inlayHint / 诊断 / codeAction 逐项有输出；`<leader>Jt` 真跑 `mvn test` 得 `Tests run: 1 … BUILD SUCCESS`。**注意**：Java 缓冲区同时挂 `jdtls` + `spring-boot` 两个 client，后者对 hover/documentSymbol/references 返回空（`vim.lsp.buf_request` 是扇出）——排查 LSP 问题时必须先分辨谁在回答 |
| 4 | ~~向导"真的创建项目"路径~~ | ✅ **已真建（§26.12）**：隔离目录里端到端跑完 11 步 + 确认创建 → `~/tmp/nvim-probe/wizard-out/demo/`（pom/mvnw/主类/`.mvn` 全套，`java.version=21`），jdtls 自动导入并编译出 `target/classes/DemoApplication.class`，主类自动打开。**UX 观察**：第 3 步 Java 版本列表降序排，指针默认落在最新（27）而不是带"LTS，推荐"hint 的 21 |
| 5 | ~~`:JavaRun` 各种 package / 依赖场景~~ | ✅ **已验证（§26.12）**：3 个场景全绿——`App.java`（有 package + 跨文件依赖 Helper）→ `total=7 / hello nvim / A,B,C`；`tools/ToolApp.java`（第二包 + 第二 main）→ `tool=TOOL!`；无 package 单文件 → JDK 单文件模式 `i=1..3` |
| 6 | 大文件/大仓库性能（tree-sitter 高亮、grep、jdtls 索引） | ✅ **2026-09-25 已压测（§27.7）**：20k 行/666KB 首屏 3.2ms、跳底 0.14ms；grep 162M/6536 文件首键→出结果 7.4–9.3ms；jdtls 到 `documentSymbol` 非空 冷 7.16s / 热 7.28s（峰值 1658MB RSS、1209% CPU）；1MB 单行 JSON 打开 13.4ms。**无 >500ms 交互停顿**（唯一 4.8s 是**没绑键位**的 `picker.lines()`，已登记为已知风险）⇒ 结论：**不加**大文件阈值配置（关高亮每次只省 ≤0.2ms） |
| 7 | 多实例并发下的历史/锁行为 | ✅ **2026-09-25 已压测并修复（§27.3）**：8 实例并发 × 20 轮 + 1203 次“截断到 0 字节”注入，**复现出旧保护挡不住的路径**——插件异步读到 0 字节文件 ⇒ 内存成非 nil 空表 ⇒ 退出时 `mode="w"` 把磁盘历史抹成 0 字节（从未被镜像过的条目 = 永久丢失）。已在 `lua/plugins/project.lua:91-170` 加守卫（会丢就只追加、绝不截断）：永久丢失 True→False、插件文件轮末 0 字节 20/20→0/20 |
| 8 | neo-tree 打开时 80 列下"分隔符 1 列错位" | ✅ **2026-09-25 已定性（§27.6）**：**窗口分隔符没有错位**——79/80/81/120 四档 × 每档 27 样本，实测竖线列 = 树窗 `wincol + width`（80 列=33、79=32、81=33、120=36），与几何期望逐一吻合，PNG 像素反查（33.36–33.48 列=格 33）三方一致；真正的 1 列差在**标签栏 offset**（bufferline 的 offset 宽 = 树窗宽、不含分隔符列，上游 `offset.lua:162`）⇒ 已加 `padding = 1` 修好（120 列 `▎` 35→36、80 列 33→34 = 编辑窗首列） |
| 9 | java-debug 对空 logMessage 的处理 | ✅ **2026-09-25 已实测（§27.4）**：空 logMessage/condition/hitCondition 上游**不报错**，一律退化成**普通断点**（真 JVM 里会真的停住）；我们的“空输入不建断点”守卫正确，注释已按实测订正（`dap/init.lua:87-90`） |
| 10 | alpha 按钮强调色 / bufferline 透明底是否并入统一调色 | ✅ **2026-09-25 已并入（§27.1）**：bufferline 54 个条目全部补实底（选中 base #1e1e2e / 其余 mantle #181825）、分隔符 overlay1、指示条 blue、未保存点 yellow；alpha 的 Logo+快捷键改 blue、按钮文字 text、页脚 overlay1；另加 `always_show_bufferline=false` 去掉“单缓冲区时多出一条**空**实底横条” |
| 11 | 观感是否合口味（picker 紧凑度、卡片配色、状态栏实底…） | ✅ **2026-09-25 已按"统一 soft 调色"收口（§27.1）**：before/after 真 pty 截图在 `~/backups/nvim-config-round12-20260925-131000/palette/`；不满意随时按"哪一块 + 期望"提 |

### 23.5 建议的下一步顺序（原计划已全部完成；新候选见本节末）

1. ✅ **已完成**：格式化补丁已应用，`stylua --check .` → **41/41 通过（exit=0）**（§26.11）。
2. ~~Java DAP + LSP 真机走查~~ → ✅ **已完成**（§26.3）。剩下的真机面是 §23.4 #4/#5（向导真建项目、`:JavaRun` 多场景）与探针 `session:request` 空数组的差异。
3. ✅ **6 项已全部决定并落地**（1 维持 / 2 保持 / 3 不改 / 4 接受 / 5 方案 A / 6 接受+修注释）——证据包见 §26.4，落地清单见 §26.11。
4. ✅ which-key 可视模式触发器已修复并真机 A/B 验证（§26.1）；`<leader>s` 拆分（§23.3 #5）已按方案 A 落地（`sh/sv` → `vh/vv`）。
5. ✅ 已完成：jdtls 的 `reloadBundles` ERROR 已在 nvim 侧挂 handler 消掉（§26.12，日志 ERROR 64 → 0）。

**§23.4 的 6 项已在第十一轮全部做完（逐项见 §27）**：① 多实例并发压测 → ✅ 复现出真实截断 bug 并做最小修复（§27.3）；② 大文件/大仓库/索引性能 → ✅ 已压测，判定**无需**加配置（§27.7）；③ neo-tree 80 列 → ✅ **窗口分隔符没有错位**，真正差 1 列的是**标签栏 offset**，已加 `padding = 1` 修好（§27.6）；④ java-debug 空 logMessage → ✅ 实测退化成**普通断点**，守卫正确（§27.4）；⑤⑥ bufferline/alpha 调色与整体观感 → ✅ 已并入统一 soft 调色（§27.1）。**⇒ §23.4 = 11/11 结清。**

---

## 24. which-key 完善清单（用户截图："看看哪些情况是没有漏写上的，哪些是没有中文注释的"）

> 截图是普通缓冲区按 `<leader>` 的弹窗。核查方法：真 pty dump 全部 leader 映射（含 desc）+ 读 `plugins/whichkey.lua` 的 spec + 读 which-key 3.17 源码 + 三种触发器写法实测。

### 24.1 结论速览

| 现象 | 结论 | 状态 |
|---|---|---|
| 弹窗里只有 12 个入口（e/F/j/q + b/d/G/f/h/s/t/w），没有 `c/r/J/m/o/R` | **不是漏写**：这 6 组只在 LSP/Java 缓冲区才有映射，which-key 只显示"当前缓冲区里真有子映射"的前缀。Java 缓冲区里它们会带着中文 desc 出现（`java.lua` 的 `d()` 都是中文） | ✅ **已决定保持上下文相关**（§23.3 #3，2026-09-25） |
| 所有 `<leader>x` 映射是否都有中文 | **都有**（真机 dump 33 条 + lazy 桩 16 条，desc 全是中文；DAP/终端/格式化/springboot 都是） | ✅ |
| 右下角 `Esc close / ⏎ back` 是英文 | which-key 源码里**硬编码**（`view.lua:442-448` 的 `{ key = "<esc>", desc = "close" }` / `{ key = "<bs>", desc = "back" }`），没有配置项 | ✅ **已决定接受**（§23.3 #4，2026-09-25）：无配置项；"渲染后替换那行文本"太脆弱，不划算 |
| 内置注释键 `gc`/`gcc` 的 desc 是英文（Neovim 内置 "Toggle comment"） | spec 里原先没有这两条 ⇒ 将来若开启 g 弹窗会看到英文。**本轮已加中文覆盖**（`{ "gc", desc = "注释/取消注释（可视、可配 motion）" }`、`{ "gcc", ... }`） | ✅（本次修） |
| ~~可视模式按 `<leader>` 没有提示~~ | ✅ **2026-09-25 订正**：不是「which-key 不注册」，而是 `whichkey.lua:13/19` 的 triggers 只写了 `mode = "n"`；改成 `mode = { "n", "v" }` 后真 pty A/B 实测弹出（对照 0 弹窗）。旧结论「三种写法实测均无效」已证伪——当时很可能是在**非 Java 缓冲区**测的：那里 x 模式没有 `<leader>` 映射，which-key 按设计不挂触发器。详见 §26.1 |
| `g`/`z`/`[`/`]`/`<C-w>` 的 spec 条目看不到 | 我们的 `triggers` 只留了 `<leader>` 与 localleader（当初 `<auto>` 会带来 g/z 闪烁）⇒ 这批 spec 只在手动 `:WhichKey g` 时可见，属"文档性质" | ✅ 有意如此（记录） |
| 还有哪些键没进弹窗 | 与真机 leader 映射逐条比对：**没有遗漏**（唯一的"隐藏项"就是上面那 6 个上下文组） | ✅ |

### 24.2 逐条细节与建议

1. **上下文组是否常显**（`c` 代码操作 / `r` 重命名·运行 / `J` Java 测试调试 / `m` Maven·Gradle / `o` 整理 import / `R` 重构提取）
   - 现状：普通缓冲区不显示（无映射）；Java/LSP 缓冲区显示且中文齐全。
   - 想常显的做法：给每组加"占位条目"（which-key v3 是否渲染"只有 desc 没有映射"的条目**未证实**，需要一次实测）。
   - 我的建议：**保持现状**——常显会在普通缓冲区里塞进 6 个按了没反应的组。

2. **可视模式触发器**（✅ 2026-09-25 已解决，见 §26.1）
   - 根因不是上游：`triggers` 只写了 `mode = "n"`。当时怀疑的 `buf.lua:70-92` 的 `is_safe` / `Mode:has` / `Triggers.schedule` 三处**全部是误判**（实测 `is_safe(<leader>)` 在 x 模式返回 true）。
   - `v` 与 `x` 等价（which-key 把 v/V/C-V 归一成 `"x"`）；官方写法 `{ "<leader>", mode = { "n", "v" } }`（`doc/which-key.nvim.txt:357-362`）。
   - 在普通缓冲区 `maparg('<Space>','x')` 恒为 nil 属**设计如此**（该 buffer 的 x 模式树里没有 `<leader>` 映射 → 不挂触发器）；判定必须用 Java 缓冲区 + 真按键（触发器还是懒创建的）。
   - 修法已落地并真 pty A/B 验证；`<auto>` 仍不可用（会给 g/z/[/]/<C-w>/<Space> 建触发器）。

3. **英文 footer**：`view.lua:442-448` 硬编码，`show_help` 只能整体开关。要么接受，要么在弹窗渲染后替换该行文本（脆弱，不推荐）。

4. **`<leader>s` 语义混合**：标签"Spring Boot / 窗口切分"里 `sp/sP`（向导）与 `sh/sv`（分屏）无关；建议拆前缀（例如分屏挪到 `<leader>v`），属你定。

5. **已做的两处小改**（本轮）：
   - `gc`/`gcc` 中文 desc 覆盖；
   - triggers 注释里记录了可视模式三种写法的实测结论（避免下次重复试）。

6. **另记**：`plugins.presets`/`marks`/`registers` 这些 which-key 子插件的英文预设只在对应前缀（`g`/`z`/`'`/`"`）被触发时才出现——我们把触发器收窄到 `<leader>` 后基本看不到它们，所以"英文注释"只在上面第 3 条（footer）真实存在。

---

## 25. 新会话启动提示词（压缩/换会话后直接粘这段）

> 用法：**新开一个会话**，把下面代码块整段发过去即可。它自带目标、必读顺序、环境前提、不要重做的事、待办与验收命令。

```text
继续维护本机 Neovim 配置（~/.config/nvim）。先按顺序读工作文档，再动手：
1) ~/.config/nvim/nvim-config-audit-20260924.md 的 §25（本节）与 §23「工作台账」——§23 是唯一状态台账；
   第十一轮（最新）逐条记录在 §27（§27.1 统一调色 / §27.3 项目历史并发压测与修复 / §27.4 DAP 深挖 /
   §27.5 Neovide 死配置 / §27.6 neo-tree 80 列定性 / §27.7 性能压测）；第九、十轮在 §26。
2) 需要细节时再查 §22（第六轮全面复查 P1/P2/P3 逐条证据）、§21（:Projects 观感 + 项目历史三层保护）、
   §19（第一轮交接）、§24（which-key 清单）、§22.4/§19.7（方法论坑，必看，能省很多时间）。

当前状态（2026-09-25 第十一轮收尾，别重新发现一遍）：
- 配置已全部提交 git（master）；~/md/nvim 的文档改动也在 ~/md 仓库提交（只提交 nvim/ 子目录）。
- Neovim 0.12.5 + lazy.nvim，插件 35 个（telescope/dressing/Comment.nvim 已删；UI 全走 snacks）。
- picker 用 picker_compact 预设 + soft 皮肤（灰边 #7f849c + 蓝标题 #89b4fa + 实底 #1e1e2e；:PickerSkin pink 可切）；
  第十一轮把 bufferline 与 alpha 也并进同一套色：bufferline 54 个高亮条目全部补实底（选中 base #1e1e2e / 其余 mantle #181825）、
  分隔符 overlay1、指示条 blue、未保存点 yellow，并加 always_show_bufferline=false（单缓冲区不画标签栏）；
  alpha 的 Logo/快捷键 = blue、按钮文字 = text、页脚 = overlay1（AlphaDash* 四个组 + ColorScheme autocmd）；
  bufferline 的 neo-tree offset 加了 padding = 1（修掉「标签起点比编辑窗首列早 1 列」，上游 offset.lua:162 的宽度算法）。
- 窗口切分在 <leader>v（vh/vv），<leader>s 是纯 Spring；<leader>sP（原版向导）与它的 cmd 桩已删除；
  which-key triggers = mode { n, v }（Java 缓冲区可视模式也会弹）；右下角英文 footer 已决定接受。
- Java 真机面已全部验证（§26.3 / §26.12）：LSP、<leader>Jt 跑 mvn test、<leader>Jg/JG 测试调试、DAP（断点→变量/调用栈/步进/终止）、
  向导真建项目、:JavaRun 三种 package 场景；第十一轮又实测：空 logMessage/condition/hitCondition 上游不报错、一律退化成**普通断点**
  （所以 <leader>dB/dL 的「空输入不建断点」守卫是对的）；<Tab> 补全归属 = blink 的 Accept/Snippet Forward（压过 neotab 的全局映射）。
- 已修（第十一轮新增）：① **项目历史插件文件被截断的真实 bug**——lua/plugins/project.lua 包了一层 write_projects_to_history 守卫
  （写前比对「磁盘现有条目 vs 本次将写出的条目」，会丢就只追加、绝不截断；实测永久丢失 True→False、插件文件轮末 0 字节 20/20→0/20）；
  ② lua/neovide.lua 的 neovide_corner_style 是**死配置**，已订正为 neovide_corner_preference（官方标注 Windows only，Linux 本来无效）；
  ③ DAP 注释订正（plugins/dap/init.lua:87-90，写清「空 logMessage 会退化成普通断点」）。
- 项目历史：三层保护（只追加副本 + 并集 + append 回填，~/.local/state/nvim/project-history.list 现约 19 行）+ 上面的插件写守卫。
- 备份/快照在 ~/backups/nvim-config-round{3..12}-*/（round12 内含本轮调色 before/after PNG 与 verify-palette.txt；
  hist-stress 的真实历史备份与配置 .orig/.patched 在 ~/backups/nvim-config-hist-stress-20260925-130658/ 与 -131002/）；
  pty 抓屏工具在 ~/backups/nvim-config-round7-20260925-092204/（pty_size.py / render_term.py；**探针一律 nvim -n**）。
  ⚠ /tmp 会被清空：pyte 需要时重建 —— python3 -m venv /tmp/termvenv &&
  HTTPS_PROXY=http://127.0.0.1:7890 /tmp/termvenv/bin/pip install pyte pillow。
- 探针方法论必读（能省几个小时）：技能 nvim-troubleshooting 的 §14 + §18 —— jdtls attach ≠ 语义就绪、
  别用 server_capabilities 静态字段做门控、Java 缓冲区同时挂 jdtls+spring-boot 且 buf_request 是扇出、vim.wait 不处理按键、
  -c luafile 里的未捕获错误会静默杀死探针、长消息 hit-enter 冻住探针、pty 探针必须 nvim -n（残留 swap 会卡 E325 静默吃掉按键）、
  DAP 请求的 arguments 传 nil 别传空表（空表会被 vim.json.encode 编成 JSON 数组、适配器静默丢帧永不回调）、
  stackTrace 的字段是 stackFrames、blink 的菜单要用 blink.cmp.is_menu_visible() 判断（pumvisible 恒 0）。

不要重做的事（已核实无问题）：启动零报错、0 弃用 API、checkhealth 里的告警全是良性噪音
（snacks 模块工具检查 / headless 无 UIEnter / vim.pack lockfile / 系统可选依赖）、文档↔配置键位与命令双向一致、
stylua --check . 41/41、picker/标签栏/状态栏配色一致、大文件与索引性能（无 >500ms 交互停顿）、终端三键/自动保存/项目切换已实测。

用户偏好：中文回答、给证据（file:line 或命令输出）、动配置前先备份、改完同步 ~/md/nvim
（那是独立 git 仓库，只提交 nvim/ 子目录，别碰他其它未提交文件）；提交粒度先问他，同意后再 commit。
★他机器上常态跑着自己的 Neovide 会话（neovide + nvim --embed）并常驻 jdtls/spring-boot LS/lua-language-server ——
那是他在用的，**绝对不要 kill**；探针要用副本工程 + 全新 -data，性能类数字要标注这个背景负载。

待办：**§23 台账已 100% 结清（0 未解决 / 0 待决定 / 11-11 已排查），没有必须做的事**。
下一步候选（等用户点头，别自己开工）：① 把 DAP 相关 spec 从 ft=java 收窄（打开任意 .java 会同步加载 nvim-jdtls+nvim-dap+spring-boot，
性能压测建议的性价比最高项，量级 25–50ms）；② 若担心未来 5MB+ 文件，可加一条 BufReadPost 大文件防御 autocmd（本轮实测「不加也不卡」）；
③ 观感微调（按「哪一块 + 期望」告诉你就行）。
验收命令：nvim --headless '+checkhealth' '+write! /tmp/h.txt' '+qa'；stylua --check .（期望 41/41）；
ls -d ~/.local/share/nvim/lazy/*/ | wc -l（期望 35）；wc -l ~/.local/state/nvim/project-history.list。
```

### 25.1 什么时候该换新会话（结论）

**该换**：① 已经压缩过 1–2 次；② 阶段切换（实施 → 收尾/新主题）；③ 需要精确回想一小时前的细节；
④ 上下文里塞了大量探针输出。**可以留**：正在同一个文件上做"改一行—验证一行"的紧密循环，且没压缩过。

换会话的成本几乎为零——因为**状态都在文档与快照里**（§23 台账 + §23.5 顺序 + §22 证据 + 各 round 快照）；
留在长会话里的收益只是"我记得刚才做过什么"，而压缩会持续削弱这一点，还容易拿旧结论当现状。

---

## 12. 第三批：窗口尺寸把控 + 两个遗留问题（2026-09-24 更晚）

---

## 21. 第十批：`:Projects` 观感重做 + 第二次历史事故与加固（2026-09-24 深夜 / 用户截图："不是很好看，好难看"）

> 用户对 `:Projects` 的列表观感不满意（截图：每行是 `名字 + 完整绝对路径` 的纯文本、无图标无层次、框宽固定半屏导致大片空白）。重做过程中**又发现项目历史被清空了一次** —— 这次定位到了上游实现的根因，并做成"再也丢不了"。

### 21.1 观感重做（前后对比见本节末尾）

| 面 | 改前 | 改后 | 说明 |
|---|---|---|---|
| 行内容 | `text` 纯串（`名字 + 两个空格 + 绝对路径`），单色 | **图标（蓝色文件夹）+ 项目名（正文亮色）+ 父目录（灰）**，名字列按最长名字对齐 | 用 snacks 的 `format` chunk 数组（`{ {text, hl}, ... }`），匹配高亮仍由 snacks 在渲染后的文本上重算 |
| 路径 | `/home/pang/Projects/xxx`（又长又重复，name 在路径里再出现一次） | `~/Projects`（home 缩成 `~`，只显示**父目录**，名字已在第一列） | 行宽从 ~60 列降到 ~40 列 |
| 框宽 | 固定 `0.5 × columns`（宽终端上一半是空白） | **贴合内容**：按最长一行算，夹在 `[40, min(96, columns-8)]` | 用户 160 列终端下：85 列 → **52 列** |
| 当前项目 | 与其它条目无区别 | **置顶** + 名字蓝色加粗 + 行尾灰色 `当前` 徽标 | cwd 可能是项目子目录 ⇒ 取最长匹配 |
| 选中行 | 只设了 `SnacksPickerCursorLine`（**白设**），实际生效的是 link 到 `Visual` 的 `SnacksPickerListCursorLine`（偏亮的 surface1） | 两个组一起设成 `bg=#313244, bold` | 见 21.3 的坑 |
| 行层次色 | `SnacksPickerFile` 是空组（=Normal 色）、`SnacksPickerDir` 只 link NonText | 名字 `#cdd6f4`、路径 `#7f849c`、计数 `#7f849c`、当前项 `#89b4fa` | 文件/搜索 picker 也一起吃这套色 |

**验证**：真 pty（160×36，pyte 终端回放 + PIL 渲染成 PNG，见 21.4）：`17/17` 条、第一行是当前项目 `󰉋 nvim ~/.config 当前`、其余行为 `󰉋 <名字>  ~/Projects`；单元格级核对：选中行 `bg=313244` 覆盖到框内最后一列，**不压边框**（col 106 的 `│` 仍是 `#7f849c`）。行为回归：`:Projects` → `<C-j>` → `<CR>` 实测切到 `/home/pang/Projects/Feed stream`，无报错。

**走过的弯路（记下来免得再犯）**：曾把 list 子窗收窄 2 列想让底色不压边框 —— snacks 的子窗本来就与父框**同宽**（内置默认布局也是 `list w == box w`），收窄后右侧多出一条 2 列宽、颜色不一致的竖条，更难看，已回退。另外实测**内联 `layout.layout.width` 能盖过预设**（53 → 61），此前"预设总是赢"的说法只对窗口键位成立。

### 21.2 🔴 第二次项目历史清空（2026-09-25 00:00）——这次是上游实现的竞态

| 项 | 内容 |
|---|---|
| 现象 | 历史文件只剩 1 行（`/home/pang/.config/nvim`），`:Projects` 里 17 条变 1 条（截图里那个 `1/1`） |
| 根因 | `project_nvim/utils/history.lua`：`write_projects_to_history()` 在 `recent_projects ~= nil` 时用 **mode="w" 截断**重写；而读文件是**异步**的（`uv.fs_read` 回调 + fs_event 监视）。实例 A 退出时 `fs_open("w")` 先把文件截成 0 字节、内容尚未写回；实例 B 的异步读正好落在窗口里 → `deserialize_history("")` 得到**空表**（非 nil）→ B 退出时按空表截断写回 ⇒ 整份历史没了。**只要并发跑多个 nvim 就可能踩**（当晚我这边探针 + 后台任务多实例） |
| 与第一次的关系 | 第一次（§16.1）我归因为"外部写了插件的内存表"；这次**不改内存表也会丢**，证明那是插件自身的截断语义 + 异步竞态。用户日常单实例风险低，但两个 kitty 标签页就会有机会 |
| 处理（三层保护，`core/commands.lua`） | ① 自维护**只追加**副本 `~/.local/state/nvim/project-history.list`；② 列表 = 副本 ∪ 插件文件 ∪ 会话项目（**并集，永不缩小**）；③ 每次 `:Projects` 把"插件文件缺、副本有"的条目 **append** 回插件文件（append 不截断；插件的 fs_event 监视器会因此重读文件，把它的内存一起修好）；④ `DirChanged` autocmd 把当前项目追加进副本 |
| 恢复 | 17 条已写回（用户截图里的 15 个项目 + `~/Projects/Feed stream/feed-java` + `~/.config/nvim`）；被清空前的 1 行状态备份在 `/tmp/project_history.wiped-*` |
| 验证 | 手动把插件历史截成 **0 字节** → 打开 `:Projects` 仍列出 **17 条**，插件文件被**回填成 17 行**（自愈成功） |

### 21.3 本批新踩的坑

1. **snacks 的选中行高亮组是 `SnacksPickerListCursorLine`**（默认 link `Visual`）——只写 `SnacksPickerCursorLine` 完全没用（我们之前那条软皮肤设置一直是白设）。
2. **snacks 子窗与父框同宽**（`list w == box w`），不要试图收窄；选中行底色铺满一行是它的正常观感。
3. **内联 layout 能盖过预设**（`width` 实测生效）——旧结论"预设总是赢"只适用于窗口键位。
4. **`opts.format` 会整体替换内置文件行格式器**；chunk 数组 + `resolve(max_width)` 是 snacks 行渲染的完整能力。
5. 探针之间要留神**并发实例**：不只是"别写插件内存"，并发本身就能触发上游的截断竞态。

### 21.6 收尾：速查面板 + 向导卡片也并入同一套色（2026-09-25，用户截图："还是有些地方没有做到位的，比如说…"）

用户截图指出 `<leader>hk` 速查面板（`core/cheatsheet.lua`，全机唯一的**自绘浮窗**）与新风格不一致。

| 面 | 改前（实测单元格色） | 改后 |
|---|---|---|
| 边框 / 窗标题 | 边框 `#89b4fa`（主题蓝）、窗标题吃全局 `FloatTitle`（**带蓝底**） | `winhl` 映射到自己的组：边框 `#7f849c`、标题 `#89b4fa` 加粗无底色。⚠ `winhl` **不是** `nvim_open_win` 的合法字段（会报 `invalid key: winhl`），必须开完窗再 `vim.wo[win].winhl = ...` |
| 面板底色 | `NormalFloat` 默认（与 picker 的 base 不同档） | `#1e1e2e`，与卡片一致 |
| 顶行色块 | 面板 `cursorline = true` + 光标停在首行 ⇒ 顶行糊一条底色带 | `cursorline = false`（纯展示面板），顶栏改成"灰 ▍ + 蓝标题 + 右侧灰提示"两段式 |
| 分隔线 / 小节 | 分隔线=主题蓝；小节名=Function 蓝 | 分隔线 `#585b70`；小节 `▍` 灰 + 名字 `#89b4fa` 加粗 |
| 按键 / 说明 | 按键=`Special`（**粉** `#f5c2e7`）、说明=NormalFloat | 按键 `#f9e2af` 加粗（与 picker 的"匹配色"同一支）、说明 `#cdd6f4` |
| 卡片同色 | picker 的输入框行是 catppuccin 的 mantle `#181825`、列表面板是 base `#1e1e2e` ⇒ 一张卡片两种底色 | 把 `SnacksPicker`/`SnacksPickerInput` 也设成 `#1e1e2e`，整卡同色（所有 picker + 向导一起变） |

**同时把向导卡片也并入 soft**（用户要"所有都统一"）：
- `spring_wizard.define_highlights()` 现在**整段**只在 `vim.g.picker_skin == "pink"` 时执行（此前只 gate 了共享组）。
- soft 下 `Wiz*` 全套由 `plugins/snacks.lua` 给色（`WizCursorLine/WizKey/WizSel/WizBadge/WizHint/WizDim/WizMagenta/WizMarker/WizPeach/WizMenuSel`），边框呼吸也从"粉阶"换成"灰→蓝→深灰"（`border_colors()`）。
- 实测两态：soft → `WizBorder=#7f849c / WizSel=#89b4fa / SnacksTitle=#89b4fa`；`:PickerSkin pink` → `WizBorder=#f38ba8 / WizSel=#f5c2e7`；切回 soft 还原 ✔。向导卡片真 pty 截图确认：标题"1. 构建工具"蓝色加粗、边框灰、行内 ▸ 蓝、命中词黄。

**本轮验证**：真 pty（160×36）出图 4 张（速查面板、向导卡片、files、grep）+ 单元格级色值核对；`stylua --check` 我改的三个文件全过（全量仍只剩用户那两个 WIP 文件，其中 `core/cheatsheet.lua` 的 WIP 区段本就没格式化，我没动它）。

### 21.5 全局统一：所有 picker 都换成这套风格（2026-09-25 早，用户："基本上所有的都换成这种风格"）

| 面 | 改动 | 为什么 |
|---|---|---|
| 全局布局 | `opts.picker.layout = { cycle = true, preset = "picker_compact" }` | 原来 snacks 默认是"≥120 列用 default（0.8 宽 + 右侧预览）、窄屏 vertical"。现在**文件/内容/缓冲区/帮助/最近/ui.select/项目**全部走同一个紧凑预设：居中、细灰边、无预览 |
| 行内标签配色 | 补 `SnacksPickerIdx`（灰）、`SnacksPickerBufNr`（灰）、`SnacksPickerBufFlags`（暖黄）、`SnacksPickerSpecial`（蓝） | `ui.select` 的 `1.`、缓冲区编号/flags、代码操作里的 `[jdtls]` 统一到同一套色阶 |
| 边框/标题组补齐 | 补 **`SnacksTitle`**（box 标题，**不是** `SnacksPickerTitle`）、`SnacksPickerBoxBorder`、`SnacksPickerListBorder`、`SnacksPickerPrompt` | 之前只设了 `SnacksPickerTitle/Border/InputBorder` ⇒ 标题吃 catppuccin 默认的**红**（实测 #f38ba8），边框靠默认 link 才碰巧是灰的 |
| `:PickerSkin pink` | 原来**切了没反应**（pink 分支只让 `apply_skin()` 早退，而洋红那套由向导定义、没人去写）→ 现在切 pink 会重新调用 `core.spring_wizard.setup()` 写入粉系基座 | 实测：soft `#89b4fa/#f9e2af` → pink `#f38ba8/#cba6f7` → 切回 soft 还原 ✔ |
| 向导不再污染共享组 | `spring_wizard.define_highlights()` 的 `SNACKS_HL` 段改为**只在 `vim.g.picker_skin == "pink"` 时执行** | 以前只要启动时 `setup()` 一次、或跑过一次向导，`SnacksPickerBorder/Title/Match/Totals/Prompt`、`SnacksTitle`、`SnacksNormal` 就被刷成洋红且**永不还原** ⇒ 之后 `<leader>ff` 标题是红的、匹配色是 mauve —— 这就是"地方冲突"的根源。实测向导打开期间这些组仍是 `#89b4fa / #f9e2af / #7f849c` ✔ |

**证据**（160×36 真 pty，pyte 回放 + PIL 出图，各一张）：`Files` 45/45 蓝标题 + 图标列 + 选中行底色；`Grep` 227/227（查询 `snacks`，命中暖黄、`file:line:col` 灰前缀）；`ui.select`（`1. Alpha …` 序号灰、`3/3`）；`:Projects`（§21.1）。外加 soft/pink 两态的高亮组逐条 dump。

**取舍（不满意改一行就行）**：
- 全局紧凑 ⇒ **预览窗被 `hidden` 掉**（`<a-p>` 也叫不出来）。某个 picker 想单独要回预览：调用处传 `layout = { preset = "default" }`。
- 宽度用预设的 `width = 0.5`（160 列 → 80 列）。grep 的长行在 80 列里会截断；要更宽改 `plugins/snacks.lua` 里 `layouts.picker_compact` 的 `width`。
- 向导卡片**内部**仍用它自己的粉系设计（`Wiz*` 组 + 边框呼吸），只影响向导自身；要一并改 soft 说一声。

### 21.4 验收与预览工具（这次新增的能力，以后可复用）

- **真 pty + 终端回放出图**：`/tmp/r3/pty_size.py`（带 TIOCSWINSZ 的 expect 式驱动，可指定列×行）→ pyte 回放 ANSI → PIL 用 JetBrainsMono Nerd Font 渲染成 PNG。`S:` 发键、`D:` 等待；渲染脚本 `render_term.py`、纯文本屏 `dump_text.py`、单元格检查 `cells.py`（能看到每个单元格的 fg/bg/bold —— 本次就是靠它抓到"底色压边框/2 列竖条/高亮组写错"）。
  - 依赖装在 `/tmp/termvenv`（pyte），PIL 用系统 python3；用法：`PYTHONPATH=/tmp/termvenv/lib/python3.14/site-packages python3 render_term.py <raw> <out.png> <cols> <rows> <fontsize>`。
  - 注意：预览里 CJK（`截图`）会显示成方框——渲染字体没有中文字形，**真机 kitty 正常**。
- **交互验收**：`:Projects`（看新样式与"当前"徽标）→ `<C-j>`/`<C-k>` → `<CR>` 切项目；`:PickerSkin soft|pink` 两种皮肤都看一眼。
- **历史自愈验收**：`: > ~/.local/share/nvim/project_nvim/project_history` 后再开 `:Projects`，列表不应变短（随后会被自动回填）。


> 用户要求「窗口大小你要把控好」。做法：先做**全配置尺寸审计**（找出所有写死的宽/高/阈值），再逐个改成自适应，最后用**真 pty（80×24）**实测几何。

### 12.1 尺寸改动一览（都带实测证据）

| 面 | 改前 | 改后 | 实测 |
|---|---|---|---|
| noice 命令行浮窗 | 写死 74（+padding/border = 82 列，80 列终端裁边） | `width = "auto", min_width = 40, height = "auto"`（noice 只在 auto 时才夹 `columns-4`） | 真 pty：`:` 弹窗 **44 列**、居中、不溢出 |
| dressing `select`（nui） | `max_width = 84` 写死、无夹取 → 80 列溢出 | `config()` 里 setup 后 + `VimEnter/VimResized` 动态夹 `max_width = min(84, columns-4)`、`min_width` 同步收缩 | 生效值：60→56 / 80→76 / ≥86→84；真 pty select 浮窗 **58 列居中** |
| dap-ui 右侧面板 | 写死 45 列 | `max(28, min(45, columns*0.32))` | 80 列→28、120→38、200→45 |
| blink 补全文档窗 | `auto_show`（上游默认 500ms 延迟）+ 20 行高 | `auto_show_delay_ms = 800`、`max_height = 12`、`desired_min_width = 40` | 配置探针 |
| dashboard logo 阈值 | `columns >= 68`（logo 实测宽 52） | `columns >= 58` | 58~67 列窗口不再退化成纯文字 |
| `<leader>tv` 垂直分屏 | 写死 60 列 | `max(30, min(80, columns*0.45))` | 80 列→36、200 列→80 |
| neo-tree 宽度 | 写死 35 | 函数：`max(20, min(35, columns*0.4))` | 实开窗口宽 32（80 列） |

**没有改的**（审计后确认本来就自适应）：which-key 弹窗（内容宽度会被夹进 `vim.o.columns`，且 `win.border` 跟随 `winborder=rounded`）、noice 的 hover/popupmenu/mini（`width="auto"`）、cheatsheet（已按 `columns-4` 夹）、Spring 向导卡片（`min(104, columns-2)`）。

### 12.2 顺手结掉的两个遗留问题

1. **`:JavaSetRuntime` 之前是"半可用"**：`jdtls.set_runtime()` 要求 `settings.java.configuration.runtimes` 非空，而本机没配 ⇒ 只会 warning。已在 `lang/java.lua` 补上本机真实存在的两个 JDK（JavaSE-21 默认 + JavaSE-1.8，路径不存在自动跳过）。**实测**：jdtls 客户端收到 2 个 runtime、`_complete_set_runtime("")` 返回两个名字 ⇒ 命令与 Tab 补全都可用。
2. **代码操作多选的"预勾选后 Tab 失效"**：归档实现的 `on_show` 用逐个 `list:toggle()` 预勾选，与 snacks 首帧渲染抢状态。改用 snacks 自己的 `list:set_selected()` + `render()`。**实测（pty 真按键）**：预选 feedMapper（显示 ●）→ Tab 追加 likeMapper（●）→ 再 Tab 取消 feedMapper → CR 返回当前选择 ✔。

### 12.3 验证方式（可复现）

---

## 13. 文档闭环（2026-09-24 收尾）

> 用户问「文档中的问题有没有全部解决？」→ 做了一次**双向**交叉核对（配置→文档、文档→配置），结论：**两个方向都是 0 处不一致**。核对方法与清单见 `~/backups/nvim-config-preflight-20260924-185532/docs-crosscheck.md`（原始交付）。

| 方向 | 方法 | 结果 |
|---|---|---|
| 文档 → 配置（防"幽灵文档"） | 抓文档里所有 `:命令`/`<leader>x`/`<C-x>`/插件名，逐个用 `vim.fn.exists(':X')`、`maparg`、lazy 配置在**真机加载后的配置**里验证 | **0 处不存在**（44 个命令候选全部实测；89 个键位 token 逐项过）。唯一真实问题：技能文档写了 `<leader>fd`（并不存在）→ 已改为 `<leader>fc` |
| 配置 → 文档 | 导出全局键位 / lazy keys / buffer-local 键位 / 用户命令 / 插件 spec 文件，逐个查文档 | **0 处遗漏**（本轮补了 8 项：`<leader>RV`、`Rv/Rm/Rc` 入表、`<leader>Gc/Gi/Ge/Gr`、Neovide `<C-=>/<C-->/<C-0>`、`:SpringBootCreate`、`lemminx`、`tree-sitter-cli`/`vscode-spring-boot-tools`、which-key 14 个分组） |

**尺寸与新增能力也已入文档**：noice 自适应宽（实测 44 列）、dressing 动态夹取、dap-ui 侧栏、blink 文档窗、logo 阈值 58、`<leader>tv` 自适应、neo-tree 宽度函数、devicons、`:JavaSetRuntime`（6 份文档）、`pick_many` 预勾选细节。

**有意保留的 4 处**：`:JavaInit` 在 4 份文档里以"**已删除**（该命令不存在）"的墓碑形式出现——这是防止有人再照旧文档敲命令，不是残留；要彻底零出现可删（需要你一句话）。

#### 13.1 本轮最后两条代码完善（报告 §3 的建议项）

- `core/spring_wizard.lua` 第 10 步"包名"补上 `valid_segment` 校验（7/8/9 步都有、唯独它漏了；非法值此时已过"确认创建"，只能等 CLI 报错）。
- `core/lazy.lua` 的 `defaults` 注释改成实话（这两项与 lazy 默认值相同；`defaults.lazy=false` **不会**让 `event/ft/keys/cmd` 触发器失效——我最初误判过，已在注释里写明）。


```bash
# 尺寸：真 pty 80×24，开 : 与 vim.ui.select，定时 dump 所有浮动窗几何
python3 /tmp/ux2a/pty_drive.py 'D:3.0|S: :|D:1.5|S:\x1b|D:0.8|S: :lua vim.ui.select({"A","B"},{prompt="选"},function() end)\r|D:2.0|S:\x1b|D:1.0|S:\x1b:qa!\r|D:1.2' \
  nvim /tmp/b-ui.txt --cmd "lua dofile('/tmp/ui-pty-probe.lua')"
# runtimes：开一个 .java 等 jdtls attach 后读 client.config.settings.java.configuration.runtimes
# 预勾选：pty 里 Tab/Tab/CR 驱动真 pick_many，读 PROBE|RESULT
```

---

## 26. 第九轮：Agent Teams 并行收尾（2026-09-25，按 §23.5 顺序执行）

> 执行方式：1 Lead + 3 teammate（stylua/验收基线、文档一致性审计、§23.3 决策证据）+ 1 专项 subagent（which-key 根因）。
> **本轮唯一改动的配置文件：`lua/plugins/whichkey.lua`**（§26.1）。改动前快照：`~/backups/nvim-config-round9-20260925-111706/`。
> 全部探针、原始日志与工程：`~/tmp/nvim-probe/`（java-demo 工程、pty driver、探针脚本、逐阶段日志、DAP 截图）。

### 26.1 ✅ which-key 可视模式触发器：已定位 + 修复 + 真机 A/B 验证（§23.4 #1、§24 第 2 条）

**根因**：`whichkey.lua` 的 `triggers` 两条都只写了 `mode = "n"`，x 模式没有任何触发器键映射；
which-key 只在「该 buffer 对应模式的键树里存在 `<leader>` 前缀映射」时才挂触发器（`buf.lua` 的 `Mode:attach` → `tree:find("<leader>")`）。
旧结论「上游不支持、三种写法都不注册」**已证伪**——当时多半是在**非 Java 缓冲区**测的（那里按设计就没有触发器）；
当时怀疑的 `buf.lua:70-92` 的 `is_safe` / `Mode:has` / `Triggers.schedule` 三处**全部是误判**。

**修法（已落地）**：`mode = { "n", "v" }`（`v` 与 `x` 等价，which-key 内部把 v/V/C-V 归一成 `"x"`；
官方写法见 `doc/which-key.nvim.txt:357-362`），并把那段"实测都不注册"的错误注释改写成结论。
**不要**改成 `{ "<auto>", mode = "x" }`：实测会给 `g/z/[/]/<C-w>/<Space>` 全建触发器，把当初收窄触发器要避免的噪音搬回来。

**A/B 验证**（真 pty 170×48、同一个 Java 缓冲区、配置副本 + `XDG_CONFIG_HOME` 隔离，原始日志 `~/tmp/nvim-probe/wk2-{A,B}.log`）：

| 变体 | 按键前 `maparg('<Space>','x')` | 可视模式按 `<leader>` 后浮窗 | 按键后 `maparg` |
|---|---|---|---|
| 对照 `mode = "n"` | nil | **0 个** | nil |
| 修法 `mode = { "n", "v" }` | nil | **2 个**（`+Visual »` 头 + `R ➜ +4 keymaps`） | `which-key-trigger/x` |

触发器的映射是**懒创建**的（按键前 `maparg` 为 nil 属正常），所以判定只能靠"真按键后弹不弹"。

### 26.2 §23.5① stylua 收尾（复核纠正 §23.2 #1）

| 项 | 结果 |
|---|---|
| 通过率 | **39/41**（`.lua` 文件总数 41） |
| 失败文件 | `lua/core/cheatsheet.lua`、`lua/plugins/lang/java.lua` |
| 失败区段 | cheatsheet.lua:149-156（缩进 8 → 期望 6）；java.lua:292（130 字节 > 120）、458-460、475-478（手拆多行但拼起来 ≤120，要合并） |

**复核纠正**：这两个文件在 `git show HEAD:` 版本上**同样失败**（用 `stylua --config-path ~/.config/nvim/stylua.toml --check <HEAD 副本>` 复核；
⚠ 直接复制到 `/tmp` 再跑会因找不到 `stylua.toml` 退回默认 tab 缩进，得到假结论）。
cheatsheet 的失败区段 blame 到 2026-09-02（历史欠账，与 WIP 无关）；java.lua 在 HEAD 失败于 298-299 的旧写法，当前失败在 WIP 新增块。
**所以 `git stash` 不会让 stylua 变绿**，必须真跑一次格式化。

收尾序列（建议）：

```bash
cd ~/.config/nvim
cp lua/core/cheatsheet.lua lua/plugins/lang/java.lua /tmp/   # 兜底备份（或先 git stash 你的 WIP）
~/.local/share/nvim/mason/bin/stylua .                       # 只做格式化，无语义变化
~/.local/share/nvim/mason/bin/stylua --check . ; echo "exit=$?"   # 期望：静默 + exit=0
git diff --stat                                              # 看它到底改了什么
```

注意它会改到你 WIP 的 4 处（java.lua:292 / 458-460 / 475-478 + cheatsheet.lua:149-156）。

### 26.3 §23.5② Java LSP + DAP 真机走查：✅ 已覆盖（§23.4 #2/#3）

工程 `~/tmp/nvim-probe/java-demo`（Maven + JUnit5），探针在真 pty 里跑，逐项原始输出在 `~/tmp/nvim-probe/*.log`。

| 面 | 结果 |
|---|---|
| LSP | hover = `int com.example.App.sum(int a, int b)`；definition → App.java:18；references = 3 处；documentSymbol = `[com.example, App]`；inlayHint = `a:/b:/who:/items:`；诊断 `The import java.util.HashMap is never used`；codeAction 列表正常 |
| 测试运行 | `<leader>Jt` → toggleterm 2 号终端真跑 `mvn test`：`Tests run: 1, Failures: 0, Errors: 0, Skipped: 0` + `BUILD SUCCESS` |
| DAP | `<F9>` 断点 → `<F5>` 自动扫出 `mainClass=com.example.App` → `stopped{reason="breakpoint", threadId=1}` → dapui 六窗自动打开 → **变量 a=3 b=4 result=7、调用栈 sum → main**、行内虚拟文本 → `step_over`（reason=step）→ `exited` + `terminated`，结束时 dapui 自动关闭。截图：`~/tmp/nvim-probe/dap-stopped.png` |
| bundle | java-debug + java-test + spring-boot-tools 共 33 个 jar 全部加载成功，无 bundle 加载失败 |

**本轮新发现（写进 nvim-troubleshooting §14/§16）**：

1. **Java 缓冲区同时挂两个 client**：`jdtls` + `spring-boot`（JavaHello/spring-boot.nvim 的 LS）。`vim.lsp.buf_request` 是**扇出**，spring-boot 对 hover/documentSymbol/references 返回**空**。排查任何"某个 LSP 功能失灵"必须先 `vim.lsp.get_clients({bufnr=0})` 分辨谁在回答。
2. jdtls `.metadata/.log` 每次启动记一条 ERROR：`Command _java.reloadBundles.command not supported on client`。**功能无影响**（bundles 启动时已传，主类扫描/断点/测试全部正常），属噪音。
3. ✅ **2026-09-25 已查明（§27.4）**：不是“适配器回空数组”，而是 `session:request("threads", {}, cb)` 的空表被 `vim.json.encode` 编成 **JSON 数组 []**，java-debug 用 Gson 解析 `$.arguments` 抛 `JsonSyntaxException` 后**静默丢帧、永不回调**；正确写法是传 `nil`（或 `vim.empty_dict()`）。dapui 正常是因为 nvim-dap 自己就用 `nil` 调（`session.lua:685`）；旧探针另有把 `stackFrames` 读成 `frames` 的第二个 bug。

### 26.4 §23.5③ §23.3 六项：决策证据包（teammate 交付，全文 `~/tmp/nvim-probe/decisions/decisions-brief.md`，428 行）

| # | 项 | 关键证据（本轮实测） | 推荐 |
|---|---|---|---|
| 1 | project.nvim / bufferline / toggleterm 是否替换 | GitHub API：三者**均未归档**，pushed 2024-08-12 / 2025-01-14 / 2025-03-09 | **全部维持** |
| 2 | Java 构建/Maven 键是否改全局 | 实测：非 Java 缓冲区按 `<leader>mc` 现状"什么都不发生"；一旦全局化，在含 `pom.xml` 的目录里会**真的执行 mvn compile**（`run_build` 无 filetype 守卫，java.lua:322-360） | **保持 buffer-local** |
| 3 | which-key 六组上下文组是否常显 | 实测 which-key 3.17 **会渲染**"只有 desc、没有映射"的占位条目；但按 `<leader>` 的第一屏里 `<Space>` 节点自身不渲染，占位只能直接塞进顶层（12 → 18 项、6 个死键） | **保持现状** |
| 4 | 右下角英文 footer | 源码硬编码 `view.lua:442/445/448`，唯一相关 opts 是 `show_help`（`config.lua:170`），无文本配置项 | **接受**（别打补丁） |
| 5 | `<leader>s` 语义混合 | 真扫全配置：已占 17 个顶层前缀（b c d e f F G h j J m o q r R s t w），空闲含 `v/x/n/u`；`sh/sv` 在 keymaps.lua:28-29、`sp/sP` 在 springboot.lua:27-34 | **方案 A：窗口切分挪到 `<leader>v`**（vh/vv），改 2 文件 4 行 + 4 处文档同步 |
| 6 | 向导卡片内部粉系强调色 | soft 下粉系已被 `spring_wizard.lua:324` 的门禁挡住；运行时实测已是灰边 #7f849c + 蓝标题 #89b4fa + 实底 #1e1e2e，只剩 3 处暖色（WizBadge/WizMagenta #f9e2af、WizPeach #fab387） | **接受 + 顺手修 4 处过期注释**（:2/:409/:416/:1113 仍写着"粉"） |

回一句「**1 维持 2 保持 3 不改 4 接受 5 方案 A 6 接受**」即可全部拍板。

### 26.5 文档↔配置一致性审计（teammate 交付，全文 `~/tmp/nvim-probe/docs-audit/docs-sync-report.md`）

- **真缺口 3 项**（配置有、三处文档都无）：neo-tree `Z`=展开全部子节点（filetree.lua:46）、`.__`=已禁用（:47）、Java 主类选择列表里的 `<Space>`=toggle_item（java.lua:232，会盖住 leader）。
- **cheatsheet 漂移 11 键 + 10 命令**，重点：`<leader>hk` 只存在于窗口标题串（cheatsheet.lua:279）而无条目；`<leader>RV` 整条缺；`<leader>Rv/Rm/Rc` 丢了 n 模式"光标处表达式"语义；命令缺 `:PickerSkin`、`:SpringBootCreate`。
- **措辞 1 条**：`nvim自定义命令.md:14/26` 说 `:SpringBootCreate` 注册在 `core/commands.lua`，实际在 `spring_wizard.lua:1176`（commands.lua:58-64 只是启动期 require）。
- **事实一致性全部通过**：插件 35 == lazy-lock.json 35；telescope/dressing/Comment.nvim 在所有文档里都是"已删除"叙述且无 live spec；文档引用的路径全部存在。
- 未改任何文档，只给建议文本（**需要你点头才动** `~/md/nvim` 与 cheatsheet）。

### 26.6 本轮验收结果与下一步

| 项 | 结果 |
|---|---|
| checkhealth | exit 0、1027 行；❌ 11 条**全为良性**（headless 无 UIEnter / 系统可选依赖 / `site/pack/core/opt` 空残留目录），真问题 0 |
| stylua | 39/41（仅 §26.2 那 2 个历史欠账文件；本轮改动的 whichkey.lua 通过） |
| 插件 | lazy 目录 35 == lazy-lock.json 35 |
| 启动 | 44–56 ms（headless，抖动 ~10ms） |
| 项目历史 | 18 行（探针跑动 +1，三层保护工作正常） |
| 本轮配置改动 | 仅 `lua/plugins/whichkey.lua`（triggers）；stylua 通过、`nvim --headless '+qa'` exit 0。另改了 `~/md/nvim` 3 处（§26.9），两个补丁已于 §26.11 应用 |

**下一步（按价值排序）**：① 跑一次 `stylua .` 收尾（§26.2）；② 回一句定 §23.3 六项（§26.4）；③ 想看真机就试 §23.4 #4/#5（向导真建项目、`:JavaRun` 多场景）；④ 可选：消掉 jdtls 的 `reloadBundles` ERROR 噪音、查 §26.3 的 `session:request` 差异。

### 26.7 🔴 新发现（P1）：`e` / `e!` 之后 Java LSP 静默失效（补丁就绪 + A/B 已验证）

**症状**：Java 文件里执行过 `:e` / `:e!` 之后，`gh` 报 `Empty hover response`、`gd` 报 `No locations found`、
`gra` 报 `No code actions available`、`grn` 报 `no matching language servers with rename capability`——
**不抛错、只是没反应**。而 `<leader>ot`（整理 import）、`<leader>Jt/Jg/JG`、DAP 仍然正常（它们按 client 名字直接取 jdtls），
所以很容易被误判成"jdtls 抽风"。

**根因**（真 pty 事件日志 `~/tmp/nvim-probe/reload.log`）：

```text
attach 后        clients=1:jdtls,2:spring-boot     hover 正常
:e!  → LspDetach  client=1 buf=1                  ← Neovim 重载缓冲区时把所有 client 都 detach
       LspAttach  client=2 buf=1                  ← 只有 vim.lsp.enable 按 filetype 管的 spring-boot 自己回来
edit! 后         clients=2:spring-boot            ← jdtls 没回来
hover            → Empty hover response
```

`lua/plugins/lang/java.lua` 的 `started_bufs[bufnr]` 去重守卫让第二次 `start_jdtls()` 直接 `return`，
于是 nvim-jdtls 的 `start_or_attach()` 不会再被调用 ⇒ jdtls 永远不回到这个 buffer。
另外实测：**去别的 Java 文件再回来也不会恢复**（jdtls 挂到了新文件上，回到旧文件仍是只有 spring-boot）。

**修法**：`~/backups/nvim-config-round10-20260925-121051/java-detach-fix.patch`（6 行，命中去重守卫时改为
`vim.lsp.buf_attach_client(bufnr, existing.id)`；已试应用通过语法检查）。

**A/B 验证（真 pty，配置副本 + XDG_CONFIG_HOME）**：

| 配置 | `:edit!` 之后 | hover |
|---|---|---|
| 现状 | `clients=2:spring-boot`（jdtls 掉了） | `Empty hover response` |
| 打补丁 | `clients=1:jdtls,2:spring-boot` | 正常（无告警） |

**不重开 nvim 的应急命令**：`:lua vim.lsp.buf_attach_client(0, vim.lsp.get_clients({name="jdtls"})[1].id)`

### 26.8 真机覆盖再推进一截（§23.4 #3/#5）

| 项 | 结果（原始日志 `~/tmp/nvim-probe/lsp2.log`、`lsp3.log`、`jg2.log`） |
|---|---|
| 跨包/跨文件导航 | hover = `String com.example.util.Helper.shout(String s)`；definition → Helper.java:8；references = 3 处（ToolApp.java:9、Helper.java:8、HelperTest.java:11）；documentSymbol = `com.example.util,Helper` |
| 整理 import | `<leader>ot` 真实键位回调 → 移除未使用的 `import java.util.HashMap` ✓（上一轮"没生效"是 §26.7 那个 attach 问题的连带） |
| rename | jdtls 就绪后（5–6s）成功，且**跨文件**生效（App.java + AppTest.java 同时改） |
| 0.12 内置键 | `grn`/`gra`/`grr` 在 Java 缓冲区存在；`gh`/`gd`/`gi` 是 buffer-local（on_attach 生效的证据） |
| java-test bundle（§9.3 判据） | `executeCommandProvider` 74 条命令里 11 条测试/调试题，含 `vscode.java.test.findTestTypesAndMethods` ✓ |
| 测试调试（DAP） | `<leader>Jg` → dap-repl `✓ sum_addsTwoNumbers`；`<leader>JG` → `✓ greet_prefixesHello` + `✓ sum_addsTwoNumbers`；无 §9.3 的 `No LSP client found…` |
| 测试运行（终端） | `<leader>Jt` → `Tests run: 1, Failures: 0, Errors: 0` + `BUILD SUCCESS` |

> ⚠ 过程中真实踩到一次"探针自己改文件"：rename 的 workspace edit 把 **AppTest.java** 也改了，
> 探针退出时被"保存所有被改缓冲区"落盘，导致后续测试编译失败（dap-repl 里像插件坏了）。
> 已恢复正常并写进 `nvim-troubleshooting` §14.11；探针收尾现在会清 `modified` 标记。

### 26.9 文档同步（`~/md/nvim`，已改 3 处，备份在 round10 快照）

| 文件 | 改动 |
|---|---|
| `nvim快捷键.md` | 文件树段补 `Z`（`expand_all_subnodes`）并注明 `.` 被显式禁用（`filetree.lua:46-47`，此前两处文档都缺） |
| `nvim插件介绍.md` | which-key「配置」行补"普通模式与可视模式都生效"（对应 §26.1 的修复） |
| `nvim自定义命令.md` | `:SpringBootCreate` 注册点措辞精确化（`commands.lua` 启动期调用 → 实际注册在 `spring_wizard.lua:1176`） |

未动 `lua/core/cheatsheet.lua`（你的 WIP）：审计发现的 **11 键 + 10 命令** 漂移仍待补。

### 26.10 两个补丁（✅ 2026-09-25 已全部应用，见 §26.11）

| 补丁 | 作用 | 应用命令 | 验证状态 |
|---|---|---|---|
| `stylua-fix.patch` | 让 `stylua --check .` 归零（cheatsheet 8 行缩进 + java.lua 3 处换行） | `cd ~/.config/nvim && patch -p1 < ~/backups/nvim-config-round10-20260925-121051/stylua-fix.patch` | 已证明**仅空白差异**（去空白后哈希一致）+ 应用后 `--check` 通过 |
| `java-detach-fix.patch` | 修 §26.7 的 `:e` 掉 LSP（6 行） | `cd ~/.config/nvim && patch -p1 < ~/backups/nvim-config-round10-20260925-121051/java-detach-fix.patch` | 语法 OK + 真 pty A/B 确认修复有效 |

回滚：`tar -xzf ~/backups/nvim-config-round10-20260925-121051/nvim-config-round10.tar.gz -C ~/.config`

### 26.11 ✅ 决策落地记录（2026-09-25，用户："你推荐的来完成即可"）

**改动清单（5 个配置文件 + 3 个文档）**

| 文件 | 改动 | 来源 |
|---|---|---|
| `lua/plugins/lang/java.lua` | `start_jdtls` 命中 buffer 去重守卫时改为 `vim.lsp.buf_attach_client(bufnr, existing.id)` 把 jdtls 拉回来（`java-detach-fix.patch`，6 行有效改动）；同文件另含 stylua 格式化 3 处换行 | §26.7（P1）+ §26.2 |
| `lua/core/cheatsheet.lua` | ① stylua 格式化（149-156 缩进 8→6）② 窗口操作段 `sh/sv` → `vh/vv` | §26.2 + §23.3 #5 |
| `lua/core/keymaps.lua` | `<leader>sh/sv` → `<leader>vh/vv`（附注释说明来源） | §23.3 #5 方案 A |
| `lua/plugins/whichkey.lua` | `s` 组标签 "Spring Boot / 窗口切分" → "Spring Boot"；新增 `v` 组 "窗口：切分" | §23.3 #5 方案 A |
| `lua/core/spring_wizard.lua` | 4 处过期注释（:2/:409/:416/:1113 仍写"粉"）改成 soft/pink 双态描述 | §23.3 #6 |
| `~/md/nvim/nvim快捷键.md` | 窗口段 `sh/sv` → `vh/vv`；neo-tree 段补 `Z` 与 `.` 禁用说明 | §23.3 #5 + §26.9 |
| `~/md/nvim/nvim插件介绍.md`、`nvim自定义命令.md` | which-key 触发模式（n+v）；`:SpringBootCreate` 注册点措辞 | §26.9 |

**验证（全部真机 / 真命令）**

| 项 | 结果 |
|---|---|
| `stylua --check .` | **41/41 通过，exit=0**（原 39/41） |
| `:e!` 之后 jdtls 还在吗 | `clients=1:jdtls,2:spring-boot`（修复前只剩 spring-boot） |
| `:e!` 之后 hover | 浮窗返回 `int com.example.App.sum(int a, int b)`，且无 `Empty hover response` 告警 |
| 新键位 | `<Space>vh`→水平切分、`<Space>vv`→垂直切分；`<Space>sh`/`<Space>sv` 已无映射；`<Space>sp` 不受影响 |
| which-key 弹窗 | 真 pty 按 `<leader>` 实拍出现 `v ➜ +窗口：切分` |
| 配置加载 | `nvim --headless '+qa'` exit 0；`checkhealth` exit 0 |
| 回滚 | `tar -xzf ~/backups/nvim-config-round11-20260925-123023/nvim-config-round11.tar.gz -C ~/.config` |

**当时列的遗留（已在 §26.12 全部做掉）**：cheatsheet 11 键 + 10 命令文档漂移、jdtls `reloadBundles` ERROR 噪音、§23.4 #4/#5。

### 26.12 ✅ 遗留四项清零（2026-09-25 续，用户："不改吗？为什么要留着"）

上一轮列的"仍留着"里只有 **git 提交**真该由你决定，其余三项当轮就能做，已全部做掉：

| 遗留项 | 处理 | 证据 |
|---|---|---|
| cheatsheet 文档漂移（11 键 + 10 命令） | ✅ 已补：`<leader>hk`、`<leader>`、新增"选择器通用键（snacks picker）"小节（`<C-j>/<C-k>`、`<CR>`、`<Tab>/<S-Tab>`、`<Space>`、`<Esc>/<C-c>`、`/`）、文件树整段（`Enter/o、h/l、a/d/r/m、c/y/x/p、H、Z、.`）、`<leader>RV` 与"可视=选区 / 普通=光标处"语义、命令段补 `:PickerSkin`、`:SpringBootCreate` 与 4 条插件桩命令 | 条目数 **93 → 113**；`stylua --check .` 41/41；`nvim --headless '+qa'` exit 0 |
| jdtls `reloadBundles` ERROR 噪音 | ✅ 已消音：`start_jdtls` 的 client config 里注册 `workspace/executeClientCommand` handler——该命令回**成功**（bundles 启动时已通过 `init_options.bundles` 传入），其它 client 命令仍 `error({ code = -32601 })` 保持原语义。handler 必须写在 `config` 里（这条请求发生在初始化阶段，启动后再补会晚） | jdtls `.metadata/.log`：ERROR 级条目 **64 → 0**；`Command _java.reloadBundles.command not supported` **29 → 0**；同会话"语义就绪"仍 true，功能无回归 |
| §23.4 #4 向导真建项目 | ✅ 已真建：隔离目录 `~/tmp/nvim-probe/wizard-out` 用真 pty 跑完 11 步 + 确认创建 | 生成 `demo/`：`pom.xml`、`mvnw`、`.mvn/wrapper`、`src/main/java/com/example/demo/DemoApplication.java`、`HELP.md`；`<java.version>21</java.version>`；jdtls 已编译出 `target/classes/com/example/demo/DemoApplication.class` 并自动打开主类 |
| §23.4 #5 `:JavaRun` 多场景 | ✅ 三场景全绿 | ① `App.java`（package com.example，跨文件依赖 Helper）→ `total=7` / `hello nvim` / `A,B,C`；② `tools/ToolApp.java`（第二包 + 第二 main）→ `tool=TOOL!`；③ 无 package 的 `Hello.java` → 单文件模式 `hello from single-file mode` + `i=1..3` |

**新发现（仅记录，未改配置）**：向导第 3 步"Java 版本"列表按**降序**排，指针默认落在最新版（实测 27），而带"LTS，推荐"hint 的 21 排在后面——直接回车会建出 Java 27 项目。若要默认 21，改 `spring_wizard.lua` 的排序或把指针预设到 LTS 项即可（等你一句话）。

**仍只剩一件事**：28 个已跟踪文件的改动仍未提交 git——按你早先的要求，我一直没有 `git commit`。

### 26.13 收尾：git 提交 + 临时文件清理（2026-09-25，用户："开始提交，然后清理临时文件"）

**5 个提交（按主题切分，工作区最终干净）**

| 提交 | 主题 | 规模 |
|---|---|---|
| `6e2e29f` | chore(plugins): 移除 telescope / dressing / Comment.nvim，UI 收敛到 snacks 一家 | 4 文件，+9 / −155 |
| `438048f` | feat(ui): picker 皮肤 soft、浮窗/通知/状态栏/文件树观感统一，新增 devicons | 8 文件，+406 / −30 |
| `c5ab8cf` | fix(lsp,java,dap): `:e` 重载后重新 attach jdtls、静音 reloadBundles，及补全/Treesitter 修复 | 7 文件，+472 / −66 |
| `f1162b8` | refactor(core): 窗口切分挪到 `<leader>v`、which-key 支持可视模式、cheatsheet 补齐 | 10 文件，+957 / −276 |
| `a9f1232` | docs: 加入配置审查报告（§0–§26）与 preflight 分批计划 | 2 文件，+1601 |

> 切分口径：按"插件取舍 / UI / LSP·Java / core 键位 / 文档"分组，同文件的多轮改动合并进同一主题（因此每个主题的 diff 是**累积**改动，不只是本轮的）。

**证据归档**：本轮全部探针脚本、原始日志与抓屏流、DAP 截图、三份 teammate 交付（decisions-brief / docs-sync-report / stylua+baseline 报告）与两个补丁，已归档到
`~/backups/nvim-config-round11-20260925-123023/probe-evidence/`（459 文件 / 8.1M；另有同名 `.tar.gz` 628K，含 `MANIFEST.txt`）。
⚠️ 本文 §26 里出现的 `~/tmp/nvim-probe/...` 路径已随清理失效——同名文件在归档目录里。

**清理清单（已删）**

- `~/tmp/nvim-probe/`（15M）：探针脚本 / 日志 / raw、`xdgA|xdgB|xdgC` 配置副本、`wk-check`、`head-check`、`acceptance/work` 实验目录、`java-demo` 与 `wizard-out` 一次性工程；随后 `~/tmp/` 已空 → 一并删除
- 探针建的 jdtls 工作区：`java-demo-b4d2eb1060`、`demo-1bc19634ef`、`demo-561a2c8884`、`nvim-probe-d0eb1c856f`（约 180M）
- `/tmp` 探针垃圾：`r9-*`/`r10-*`/`r11-*`/`r12-*`、`acc-*`、`audit-before-bt*.md`、`sw-*.lua`、`cs-before-fmt.lua`、`jdt-log-before.log`、`cmp-*`、`tmp.*` 等

**保留**：`/tmp/termvenv`（pyte 抓屏工具链，丢了按 §25 重建）；更早轮次遗留的 jdtls 工作区（`javaproj`/`jproj`/`w1jb`/`w2verify`/`tmp-`/`some-very-long-project-name`/`docs`/`nvim`/`feed-java`，约 350M）——不是本次会话产生，未擅自删。

### 26.14 删除 `<leader>sP`（原版 Spring 向导）—— 用户截图指出（2026-09-25）

用户看到 `<leader>s` 弹窗里的第二项 `P → 原版向导（不推荐：Boot 4 版本号有 bug）` 后要求删除（"应该也没有用了"）。

| 项 | 处理 |
|---|---|
| `lua/plugins/lang/springboot.lua` | 删除 `{ "<leader>sP", "<cmd>SpringBootNewProject<cr>" }` 映射；同时移除 `springboot-nvim` 的 `cmd = { "SpringBootNewProject" }` 桩（该桩原本只为"全局键在任何缓冲区按不报 E492"而存在）。**插件本体保留**——`<leader>Gc/Gi/Ge/Gr` 类生成与保存时增量编译还在用它 |
| `lua/core/cheatsheet.lua` | 去掉对应条目（Java/Spring 段） |
| `~/md/nvim`（5 处） | `nvim快捷键.md`、`nvim命令.md`、`nvim插件介绍.md`（加载行 + 快捷键行 + 备注行）、`构建SpringBoot项目实操指南.md`、`nvim配置架构.md` 全部改为"已删除"口径 |

**真机验证**：`<Space>sP` 无映射；`:SpringBootNewProject` 启动期不存在（`exists()=0`）；真 pty 按 `<leader>s` 的弹窗现在只有 `p ➜ Spring Boot 项目向导（可搜索选择）`；`<Space>Gc`/`<Space>Gi` 仍在。`stylua --check .` 41/41、`nvim --headless '+qa'` exit 0。

**保留说明**：Java 缓冲区里插件按 `ft=java` 加载后仍会注册 `:SpringBootNewProject`，所以"应急用一次"仍可行，只是不再挂键位、也不再启动期注册。





---

## 27. 第十一轮：全量收尾（2026-09-25 下午）

> 用户要求：“你全部弄完处理好给我，开启 team 工作也可以，项目的话你随便找一个项目复制一下来测试，工作完成后清理掉即可，并更新文档，将文档中的全部内容解决掉。你推荐的来即可。”
> 执行方式：**Agent Teams 并行 4 条线 + Lead 自己 2 条线**——task-4 项目历史并发压测（hist-stress）、task-5 neo-tree 80 列复现（uirepro）、task-6 DAP 深挖（dapdev）、task-7 性能压测（perf，先备料、机器静默期执行）、task-8 观感收口（Lead）、task-9 文档收口/验收/提交/清理（Lead）；收尾另有 task-10（pick_many 等真机面）交给 uirepro。
> 证据目录 `~/tmp/nvim-audit/{hist,dap,uirepro,perf,lead}/`（交付后清理，关键件归档 `~/backups/nvim-config-round12-20260925-131000/`）。

### 27.1 ⑤⑥ 观感收口：把 bufferline / alpha 并进同一套 soft 调色（task-8，Lead 执行）

**问题**：全机 picker/浮窗是“蓝标题 #89b4fa + 灰边框 #7f849c + 实底 #1e1e2e”，状态栏也早就补成实底 mantle #181825；但① bufferline 因为 `transparent_background=true` 被 catppuccin 把所有 `bg` 写成 `NONE`（54 个高亮条目**全部透明**），顶部标签栏其实是“悬浮文字”透出壁纸；② alpha 欢迎页的 Logo/页脚用 `Type`（黄）、按钮用 `Label`（sapphire）、快捷键用 `Keyword`（mauve），三个来源都和统一调色不同源。

| 改动 | 文件 | 内容 |
|---|---|---|
| bufferline 实底 | `lua/plugins/bufferline.lua:21-75` | 包一层 `highlights` 函数：把上游结果里所有 `bg == "NONE"` 换成实底（名字含 `_selected` → base #1e1e2e，其余 → mantle #181825）；分隔符/关闭按钮统一 overlay1 #7f849c、未选中标签文字提到 subtext0 #a6adc8（压在实底上原来的 surface1 #45475a 太暗）、选中指示条改 blue #89b4fa 加粗、未保存圆点改 yellow #f9e2af。**54 个条目现在 0 个缺 bg** |
| 去掉空横条 | `lua/plugins/bufferline.lua:83-87` | 加 `always_show_bufferline = false`（bufferline 默认 true）：否则启动页/单文件时顶部会多出一条**空的**实色横条（透明时代它隐形，所以以前看不出来）。LazyVim 也是 false；实测 neo-tree 的 buffer 不算 listed，不会让标签栏闪烁 |
| alpha 调色 | `lua/plugins/dashboard.lua:14-34` | 新增 4 个组：Logo `AlphaDashHeader`=blue、按钮文字 `AlphaDashButton`=text #cdd6f4、快捷键 `AlphaDashShortcut`=blue 加粗、页脚 `AlphaDashFooter`=overlay1 #7f849c；并挂 `ColorScheme` autocmd 重新应用（页脚原来和 Logo 同为黄色，现降为次要灰） |

**证据**：
- 配置级（headless，`~/tmp/nvim-audit/lead/verify_palette.lua` → `verify-palette.txt`）：`bufferline highlights 类型 = function`、**检查 54 个条目，缺 bg 的 = 0**；`fill bg=#181825`、`buffer_selected fg=#cdd6f4 bg=#1e1e2e bold=true`、`separator_selected fg=#7f849c`、`indicator_selected fg=#89b4fa bold=true`、`modified_selected fg=#f9e2af`；四个 `AlphaDash*` 组 fg 依次 9024762/13489908/9024762/8357020（= #89b4fa/#cdd6f4/#89b4fa/#7f849c）。
- 观感级（真 pty 抓屏 → pyte → PNG，归档 `~/backups/nvim-config-round12-20260925-131000/palette/`）：`before-alpha.png` vs `after2-alpha.png`（Logo 黄→蓝、页脚黄→灰、**顶部空横条消失**：pyte 单元格 bg 直方图保持 `{default:3000}`）、`before-bufferline.png` vs `after2-bufferline.png`（标签栏透明→实底：行 0 col0 选中=#1e1e2e、col30+ 填充/未选中=#181825）。
- 回归：neo-tree 展开时 `offsets` 的“文件树”标签仍在标签栏左侧（`nt.raw`）；`stylua --check .` 41/41、`nvim --headless '+qa'` exit 0。

### 27.2 历史快照节（§11.3 / §11.5 / §19.3 / §20.2 / §24.1）全部标注结清

这些节的 ⏳/🟡 是第一轮的历史状态，早被后续轮次覆盖但没回填，压缩后容易被误读成“还没做”。本轮逐节加结清横幅与逐项指向：§19.3 标题改“✅ 已全部结清（原未解决/待你决定，第一轮快照）”并列出 15 项各自落点；§20.2 标题改“✅ 已全部结清”并给 3 项补上决策（② §23.3 #2、③ §23.3 #1）；§24.1 的 🟡（which-key 英文 footer）改 ✅ 已决定接受（§23.3 #4）；§11.3/§11.5 的真机面见 §27.8（pick_many 多选、三条边界、`<Tab>` 归属、`:JavaSetRuntime` 缺陷）。

### 27.3 ⑦ 项目历史并发压测：**复现出真实截断 bug 并做最小修复**（task-4，hist-stress 交付 + Lead 独立复跑）

**结论**：三层保护在并发下“**可见列表不缩水**”成立，但“**插件文件不丢**”不成立——project.nvim 启动时**异步**读历史（`utils/history.lua:104-118`），只要落在“文件被别的实例截断成 0 字节”的窗口里，`recent_projects` 就变成**非 nil 空表**；退出时 `write_projects_to_history()` 只在 `nil` 时用追加模式（`utils/history.lua:145-151`），空表走 `mode="w"` **截断重写**，把磁盘上完整历史抹成 0 字节。自有副本（层①）能救“看得见的列表”，但**从未被镜像过的条目就是不可恢复的永久丢失**。顺带确认：`lua/core/commands.lua` 全文只有一处 `io.open(path, "a")`（`commands.lua:120`），本来就只追加、无可修——截断发生在**插件退出路径**。

| 场景 | before（补丁前） | after（补丁后） |
|---|---|---|
| A 8 实例并发 × 20 轮 + 1203 次截断注入 | 插件文件轮末 **0 字节 20/20** | **0/20**，轮末恒定 352B/8 条 |
| A/C 可见并集 | 20/20 轮完整；插件文件行数 `[8,2,0,1,8,0,8,8,8,6]` | 20/20 轮完整；行数**恒 8** |
| B 半截行注入 + 40 次 SIGKILL | 可见列表恒 8、垃圾行不入列表 | 同左（无回归） |
| D 回填 / fs_event | append 回填确实触发重载；**跨目录 rename 不触发** ⇒ 复现 1500ms“磁盘 8 条 / 内存空表”事故窗口 | 同左（据此**故意不用** temp+rename） |
| E 核心回归点 | 受害者 `recent=table#0`、磁盘 352B → 退出后**插件文件 0 字节**、摧毁磁盘历史 True | 退出后**仍是 352B/8 条**、摧毁 False |
| F 退出写 vs append 对撞 × 20 轮 | 插件文件轮末 0 字节 **11/20** | **0/20** |
| G 永久丢失判定（两个文件同时归零） | **True** | **False**（恢复后存活 8 条） |
| H 语义代价（新增场景） | 插件文件里“已删除目录”的条目被原实现顺手清掉 | 该条目**留在文件里**（读取端 `dir_exists` 仍过滤，可见列表仍 8 条不含它） |

**修复**：`lua/plugins/project.lua:91-170`（+81 行）——包一层 `write_projects_to_history`：写之前比对“磁盘现有条目”与“本次将写出的条目”，**只要这次写会丢掉磁盘上已有条目，就降级为“只追加缺的那些”，绝不截断**；计划 ⊇ 磁盘时仍走原实现（去重/裁剪 100 条语义不变）；守卫自身抛错时 notify 并回退原实现。挂载点已确认是**动态**调用（`project_nvim/project.lua:273` 的 `VimLeavePre * lua require('project_nvim.utils.history').write_projects_to_history()`），插件 `lazy = false` ⇒ 启动期即生效。

**Lead 独立复跑**（`python3 ~/tmp/nvim-audit/hist/bin/harness.py all`，隔离 `XDG_STATE_HOME/XDG_DATA_HOME`）：`scenario E: victim_destroyed_plug=false`、`scenario G: permanent_loss=false, recover_entries_survived=8`、`scenario F: 插件 0 字节轮数 0`、`REAL FILES UNTOUCHED: True`（真实 `project-history.list` = `e232635e…`、`project_history` = `3c3164c8…` 全程未变）。

**残留风险（据实登记）**：① 插件文件仍可能出现重复行（跨进程 TOCTOU，A 场景 3/20→7/20 轮；读取端去重，无功能影响），彻底修需 flock/锁文件；② 层① 只在 `:Projects` 或 `DirChanged` 时写入，“从未被镜像过的条目”仍只有插件文件一份（补丁只是堵死了截断窗口）；③ 未测 NFS/WSL、>100 条裁剪路径。

### 27.4 ④ + ❓ DAP 深挖（task-6，dapdev 交付）

**(a) java-debug 对空 logMessage / condition / hitCondition（上游行为，报文级实测）**：
- 原始 `setBreakpoints` 十变体（`logMessage=""` / `condition=""` / `hitCondition=""` / 三个都空 / 空白串 / `hitCondition="abc"`）**全部不报错**，一律回 `{verified=true, message=""}`；
- 真 JVM 运行：`logMessage=""` 的断点**会真的停住**（reason=breakpoint，**不是**日志点），只有 `logMessage="LOG a={a} result={result}"` 这种非空串才是不停的日志点；
- 源码佐证（java-debug 0.53.2，与本机 jar 同版本）：`handleEvaluationResult` 用 `StringUtils.isNotBlank(getLogMessage())` 分流；`hitCondition` 解析失败即 `hitCount=0`（等于忽略）；
- **结论**：我们“空输入不建断点”的守卫**正确**，但理由不是“假断点无害”，而是“上游会把它当**普通断点**，用户以为设了日志点却会真的停下” ⇒ 注释已按实测订正（`lua/plugins/dap/init.lua:87-90`）。

**(b) ❓ 探针 `session:request("threads")` 拿空数组：根因查明并纠正**：
- 不是适配器回空数组，而是**回调根本没触发**：`session:request("threads", {}, cb)` 的空表被 `vim.json.encode` 编成 **JSON 数组 `[]`**，java-debug 用 Gson 解析 `$.arguments` 抛 `JsonSyntaxException` 后**静默丢弃该请求、永不回应**；
- 正确写法 `session:request("threads", nil, cb)`（无参数传 nil；要空对象用 `vim.empty_dict()`）。三段闭环：DAP TRACE 里 `seq=23` 无任何响应 vs `seq=24`（arguments 缺省）立刻回 6 个线程；`vim.json.encode({}) == "[]"` 实测；适配器侧 `.metadata/.log` 每个 `{}` 请求恰好一条 `Expected a com.google.gson.JsonObject but was com.google.gson.JsonArray`；
- 为什么 dapui 正常：nvim-dap 自己就是 `self:request('threads', nil, on_threads)`（`lua/dap/session.lua:685`），dapui 只监听响应不自己发；旧探针的**第二个** bug 是把 `stackFrames` 读成 `frames`，所以即使响应正常也永远打印 0；
- 两条教训已写进 DSH 技能 `nvim-troubleshooting` 的 §18（连同 pty 探针 `nvim -n` / E325 陷阱、`~/tmp` 与 `/tmp` 混用陷阱）。

### 27.5 顺手修掉一处 Neovide 死配置（来自 §11.5 的“Neovide”待确认项）

`lua/neovide.lua` 里的 `vim.g.neovide_corner_style = "round"` **不是 Neovide 的选项**，属静默无效的死配置。官方 `configuration.html`（本机 Neovide 0.16.2）里 0.16.0+ 的正确名字是 `neovide_corner_preference`（取值 default/round/round_small/do_not_round），且标注 **Currently Windows only** ⇒ Linux/Wayland 下窗口圆角本来由合成器决定。已改为正确名字并加注释（`lua/neovide.lua:32-36`）；其余选项（scale_factor / opacity / cursor_vfx_mode / refresh_rate / cursor_short_animation_length / guifont）逐个对照官方文档**均存在**，模拟 `g:neovide=1` 加载无报错、3 个缩放键位都注册。

### 27.6 ③ neo-tree 80 列「分隔符 1 列错位」：窗口分隔符**没有**错位，真正的 1 列偏差在**标签栏 offset**（task-5，uirepro 交付 + Lead 复验）

**结论**：窗口分隔符**未复现错位**。27 样本/档 × 四档列宽（79/80/81/120）实测：屏幕竖线所在列 = 树窗 `wincol + width` ——80 列=33、79=32、81=33、120=36，与几何期望**逐一吻合**；PNG 像素反查也一致（竖线墨迹落在 33.36–33.48 列 = 字符格 33）。原线报的「80 列分隔符 1 列错位」按现有配置**不成立**。

**三类嫌疑已 A/B 排除**（都在 XDG_CONFIG_HOME 副本里做，真实仓库零改动）：关掉 bufferline → 分隔符仍 33；`statuscolumn="%s%=%l "`（树窗 textoff 0→1）→ 分隔符仍 33；写死树宽 35 → 分隔符 36 仍对齐 ⇒ 与 bufferline / statuscolumn / 宽度取值都无关。

**唯一真实的「差 1 列」在标签栏**：bufferline 的 offset 宽 = 树窗宽、**不含分隔符那 1 列**（上游 `bufferline/offset.lua:162` 直接用 `nvim_win_get_width`）⇒ 第一个标签从**分隔符列**开始，比编辑窗首列早 1 列；79/80/81/120 **全都差 1**，与终端宽度无关。**修复已落地**：`offsets` 项加 `padding = 1`（`lua/plugins/bufferline.lua:113-127`，带注释说明上游算法），真 pty 复验 120 列下 `▎` 指示条 35 → **36 列**（= 编辑窗首列）、80 列 33 → 34，竖线列不变；`stylua --check .` 41/41。

**为什么上一轮写「未复现到稳定结论」**：标签栏可见性取决于 `always_show_bufferline` 与缓冲区数——本轮 13:07 我加的 `always_show_bufferline = false` 让**单缓冲区时整条标签栏不画**，于是同一列宽在改前/改后/单双缓冲区下「有时差 1 列、有时根本看不到标签栏」，看起来像随机 bug。

**探针坑（已固化进技能 §18）**：pyte 不回答终端查询 → E1568；`cmdheight=0` 时 hit-enter 会**静默吃掉**注入的 `<leader>e`（uirepro 写了主动应答终端查询的 pty_size_ans.py）；多文件启动的「2 files to edit」同样触发 hit-enter（探针里补 <CR>）；一律 `nvim -n`。

**未测**：打开树之后再 resize；160 列单/双缓冲区两版。


### 27.7 ② 大文件 / 大仓库 / jdtls 索引性能压测（task-7，perf 交付 + Lead 独立聚合复核）

**素材（全部是复制品，测完清理）**：`feed-java-copy`（真实 Maven 工程副本 3.6M / 436 文件 / 128 个 .java / 6015 行）、`dsh-copy`（162M / 6536 文件，用于 grep）、合成 `Big5000.java`(169KB) / `Big20000.java`(666KB) / `oneline-1mb.json`（1MB 单行 / 39560 键）。

**判定：没有发现 >500ms 的可感知停顿**——交互路径（开文件、跳转、滚屏、搜索出结果）全在 0.05–31ms 量级。

| 指标 | 数字（3 次中位） | 判定 |
|---|---|---|
| 启动（headless 自报） | 空会话 **51.4ms**（台账旧基线 50ms，无回归）；打开 .java 89.9–115.0ms | 正常；多出的 30–60ms 来自 java FileType 插件链（nvim-jdtls/nvim-dap/spring-boot） |
| tree-sitter（20k 行/666KB） | `edit!` 26.37ms、首屏 redraw 3.21ms、`G` 到底 0.14ms、滚 40 行 0.07ms | 正常 |
| 整篇强制解析 `parse(true)` | 20k 行 99ms、1MB 单行 139–146ms、**5MB 单行 736ms**（100k 行 502ms） | 非交互路径（首屏只解析可见区：20k 行 3.21ms、5MB 单行 10.62ms） |
| grep 大仓库（162M/6536 文件，snacks picker 端到端） | 首键→出结果 **7.4–9.3ms**（rg CLI 同参基线 4–6ms）；picker 窗口可用 27–34ms | 正常 |
| jdtls 首次索引（副本 + 全新 `-data`） | LspAttach 冷 4.35s / 热 3.79s；到 `documentSymbol` 非空 **冷 7.16s / 热 7.28s**（冷热几乎相同：瓶颈是 JVM 启动 3.8–4.3s + 首个请求等待，不是索引本身）；JVM 峰值 RSS 冷 1658MB / 热 888MB，最大 CPU 1209% / 1074%，累计 CPU 72s / 40s（热启动省 44%） | 正常（同期 UI redraw 仍 1–3ms，编辑器不卡） |
| 病态文件 1MB 单行 JSON | 打开 13.4ms、首屏 4.95ms、`$` 行尾 9.31ms、`0` 回行首 6.37ms | 正常 |
| 病态文件 5MB 单行 JSON（悬崖样本） | 打开 37.08ms、首屏 10.62ms、`$` 行尾 44.87ms、`0` 29.56ms | 正常 |
| ⚠ `picker.lines()`（缓冲区行搜索，同步 finder） | 1MB 单行 **4823.6ms**、20k 行 574.1ms（调用本身阻塞） | **本轮唯一 >500ms**；但 `grep -rn "picker\.lines" lua/` **无命中** ⇒ 不是键位可达路径，登记为已知风险 |

**是否加大文件配置：不建议**。现配置里相关开关只有 `plugins/snacks.lua` 的 `bigfile = { enabled = false }`（显式关掉了 snacks 自带的大文件保护）；实测「把高亮全关」每次操作只省 **≤0.2ms**（1MB 单行 `$` 9.31→9.11ms、`0` 6.37→6.24ms、20k 行 `G` 0.14→0.12ms、100k 行 0.16→0.15ms），启用 bigfile 反而改变行为（禁 TS/undo/通知）。若只是「防御未来 5MB+ 文件」想加，最省的是**一条 `BufReadPost` autocmd**（size > 2MB 时 `vim.treesitter.stop` + `syntax off` + 通知，成本≈0），但要知悉它**不会改善本次测到的任何交互指标**（唯一超 500ms 的两条路径是全量 `parse(true)` 与未绑定的 `picker.lines()`，关高亮对前者无意义、对后者不生效）——故本轮**不改配置**，仅登记为可选防御。**更高优先级的优化点**（perf 提出、留给下一轮决策）：把 DAP 相关 spec 从 `ft = "java"` 收窄成「真正要调试时再加载」——打开任意 .java 都会同步加载 nvim-jdtls + nvim-dap + spring-boot（headless +30–60ms）。

**测量条件（不可移除的背景负载，Lead 裁决不许 kill）**：用户自己的 Neovide 会话（`neovide 911080` → `nvim --embed 911103`）常驻 `jdtls 1314657`（`-data …/feed-java-f631125a78`，RSS 1.3G）+ spring-boot LS(447M) + lua-language-server；三次机器快照 loadavg 2.9–4.4、MemAvailable 6.2–7.8GB（原始 `logs/machine-state.log`）。因此 jdtls/启动类数字按「**上界**」口径；隔离的 TS/病态文件项基本不受影响。perf 自己的每轮 pty 探针全程串行、同一时刻最多 1 个他自己起的 jdtls（脚本 `wait_no_jdtls` + `cleanup_my_jdtls` 双保险）。**Lead 独立复核**：另写脚本对 `results/*.jsonl` 重算中位数，与报告 `tables.md` 逐项一致。

**残留不确定**：① 真 pty 下空 .java 启动（264ms）反而比 20k 行 .java（215ms）慢，两轮复现、headless 顺序正常，未定位（不影响判定）；② `language/status == ServiceReady` 在 6 次运行里**一次都没收到**（`$/progress` 正常 30+ 条）⇒ 就绪判据改用 `documentSymbol` 非空（与技能 §14.1 一致）；③ 未测 go/rust 语言链与 GUI(neovide) 路径。


### 27.8 §19.3 #12 / §11.3 / §11.5 的真机面：pick_many 多选 + 三条边界 + `<Tab>` 归属 + `:JavaSetRuntime` 缺陷（task-10，uirepro 交付）

| 项 | 结论 | 证据 |
|---|---|---|
| ① pick_many 多选 | ✅ **弹窗 / 勾选 / 多动作全正常** | picker `source=jdtls-pick-many`、标题 "Include field to initialize by constructor(s):"、`n_items=2`；Tab → sel 0→1→2，屏幕 `○○→●○→●●`、右上计数 `(2) 2/2`；CR 后 `toString()` 生成 `return "UicheckPick [alpha=" + alpha + ", beta=" + beta + "]";`、构造器 `public UicheckCtor(int alpha, String beta)` —— 两个字段都在，不是只执行一个 |
| ②a 预勾选后 Tab 追加 | ✅ 时序没问题；**但本机 jdtls 不给任何项标 `isSelected`** | 插桩副本（`ab/java-instr`）：`mark call tries=1 items=2` → `pre=0`（items 已就绪、is_selected 全 false）⇒ 看不到 ● 预置**不是**配置那个 500ms 重试窗口没命中，是上游就没标 |
| ②b `<Space>` 只在列表窗勾选 | ✅ 符合设计（键位挂在 `win.list.keys` 的窗口作用域），**判不算缺陷**；输入窗按 Space 只会输入空格 | `<A-w>` 切到列表窗后 Space：sel 0→1（屏幕 ●、计数 `(1) 5/5`）→ 再按 1→0 |
| ②c 「真取消」 | ✅ **确认是上游限制** | 上游 `jdtls.lua` 六处 pick_many 只有 123/184/777 检查空返回，97/138/225 三处 **fields 不检查** ⇒ 真机复现：fields 弹窗按 Esc 取消后**仍生成空字段** `return "UicheckCtor []";`。本机已按上游契约返回空表（`java.lua:287/300`），能做的防护做满了 |
| ③ `<Tab>` 补全归属（java 半边） | ✅ 与 Lua 半边机制一致 | java 缓冲 `sw=ts=4`（`autocmds.lua:20-27`，Lua 是 2）；buffer-local `<Tab>` 同样是 blink 的 Accept/Snippet Forward（压过 neotab 的全局 `<Plug>(neotab-out)`）；无菜单 Tab 插 **4 空格**；`fori` → `blink_menu=True` → Tab 接受片段、Tab 跳 `${2:max}`、S-Tab 回 `${1:i}` |
| ④ `:JavaSetRuntime` | ⚠ **发现真缺陷并已修复** | 不带参数时只报 `Provided runtime `` not found in config.settings.java.configuration.runtimes`、**不弹列表**：根因是命令 `nargs="?"`，无参数时 `p.args=""`，而 Lua 里 `""` 为真 ⇒ 上游 `set_runtime` 的 `if runtime then` 走了「按名匹配」分支。修法一行：`jdtls.set_runtime(p.args ~= "" and p.args or nil)`（`lua/plugins/lang/java.lua:581-586`，带注释；备份 `~/backups/nvim-config-uicheck-20260925-135705/`，其 before md5 = HEAD md5 = `d72fd682…`，可回滚）。修复后 `:JavaSetRuntime` 弹出 `Runtime>` 列表，`JavaSE-21`(default) 与 `JavaSE-1.8` 都在 |

- 探针纪律：全程**副本工程** `feed-java-uicheck` + 全新 `-data`（与用户会话的 `feed-java-f631125a78` 完全隔离）；每轮 `stop_client` + 清 modified + `qa!`，`ps` 复核无残留 JVM。
- 新探针坑（已进技能 §18.7）：`pk.input.win` **不是** win 号（`Invalid win` 被 pcall 吞掉 → 表现成「picker 看不见」），可靠做法是按 filetype 读 `snacks_picker_input` / `snacks_picker_list` 缓冲区；包装 `Snacks.picker.pick` 必须等 snacks 加载之后再包；pty 驱动新增 `P:<file>` 逐键快照与 `W<秒>:regex` 长等待。


### 27.9 本轮收尾：验收、提交、清理（Lead 执行，task-9）

**验收（全部本地实跑）**：

| 项 | 结果 |
|---|---|
| `stylua --check .` | **41/41，exit 0**（41 个 .lua 文件） |
| `nvim --headless '+qa'` | exit 0（启动零报错） |
| `nvim --headless '+checkhealth' …` | exit 0；11 条 ERROR **全是外部可选工具缺失**（magick/gs/tectonic/mmdc），历史已核实为良性噪音 |
| 插件数 | 35（`ls -d ~/.local/share/nvim/lazy/*/`） |
| 真实项目历史文件 | **只增不减**：自助副本 19 → 21 行、插件历史 17 → 19 行（`diff` 确认新增的正是本轮两个探针副本目录，**零丢失**）。两条探针目录已随清理删除 ⇒ `:Projects` 会被读取端 `dir_exists` 过滤掉；文件里保留是**已知语义代价 H**，不手工删以免破坏「只追加」设计 |
| `:Projects` 功能回归 | 真 pty：弹窗显示 `项目 17/17`，Esc 关闭、`:qa!` 退出后两个真实历史文件 **sha256 不变** |
| 观感回归 | neo-tree 展开时 `offsets` 的「文件树」仍在标签栏左侧；bufferline **54/54** 条目有实底；alpha 单元格 bg 直方图保持 `{default:3000}`（顶部无空横条） |
| 项目历史写守卫 | Lead 独立复跑 hist harness：`victim_destroyed_plug=false`、`permanent_loss=false`、`REAL FILES UNTOUCHED: True` |

**提交**：
- `~/.config/nvim`：`3d9f907 fix(ui/java/dap): 统一 bufferline/alpha 调色 + 项目历史写守卫 + 两处死配置订正`（6 个 lua 文件）；台账本文件的收口是紧随其后的第二个提交。
- `~/md`：`71710aa docs(nvim): 同步第十一轮配置改动…`（**只**提交 `nvim/nvim插件介绍.md` 与 `nvim/nvim配置架构.md`；他另外 17 处未提交改动一律没碰）。

**清理（已执行，用户：「工作完成后清理掉即可」）**：
- 删除 `~/tmp/nvim-audit/`（**243M**：perf 的 feed-java-copy / dsh-copy / 合成大文件、hist 的隔离 XDG 沙箱、dap/uicheck 的 Java 副本与探针、lead 的抓屏与 A/B 配置副本）与 `/tmp` 里的临时文件。
- 删除本轮新建的 jdtls workspace：`java-demo-397dee7e2f`（dapdev）、`feed-java-copy-de7c54bd2b`（perf）、`feed-java-uicheck-277eec247e`（uirepro）、`perf-9da1124ad7`（perf 的工作目录被识别成项目）。
- **保留**：`…/jdtls-workspace/feed-java-f631125a78`（**用户会话正在用**，绝不能删）、其余历史 workspace（352M，等用户点头再删）、`/tmp/termvenv`（pyte）、`~/backups/nvim-config-round12-20260925-131000/`（`palette/` 6 张截图 + `evidence/` 27 个归档件）、`~/backups/nvim-config-hist-stress-20260925-13{0658,1002}/`（真实历史备份 + 补丁前后的配置）。
- 残留进程：无（只剩用户自己的 `neovide 911080` / `nvim --embed 911103` / `jdtls 1314657`，全程未受影响）。

**Agent Teams 分工与产物**：task-4 hist-stress（→ §27.3）、task-5+task-10 uirepro（→ §27.6 / §27.8）、task-6 dapdev（→ §27.4）、task-7 perf（→ §27.7）、task-8/9 Lead（→ §27.1 / §27.9）。所有 teammate 报告在删除前已归档进 `~/backups/nvim-config-round12-*/evidence/`。

