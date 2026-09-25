# Neovim 配置全面审查报告

> 审查日期：2026-09-25（本机时间）  
> 审查对象：当前工作树及本机实际安装的插件；Neovim **0.12.5**  
> 性质：**只审查，不修复配置**。使用 3 个 Agent Team 审查分支，由主审交叉核验并汇总。  
> 范围：结构、模块边界、UI 设计、配置正确性、加载与异步逻辑、操作语义、数据/进程安全、文档一致性、维护成本。

## 1. 执行摘要

### 总体判断

这不是一份随意堆插件的配置，而是一套**围绕中文交互、Java/Spring 开发、项目切换和 AI CLI 工作流定制的个人 IDE**。入口清晰、UI 职责划分有意识、快捷键有自己的语法，对过去故障也保留了大量原因说明。

**主要问题不在“插件太多”或“基础语法不对”，而在自定义兼容层逐渐承担了持久化、生命周期和协议适配职责，却缺少足够的边界测试。** 正常启动与常用路径已经比较成熟；多项目、异常返回、强制退出、窄屏、插件初始化顺序等交界处仍存在可定位问题。

建议保留整体设计，先修边界，再拆模块；**不建议为了形式上的简洁重写整套配置，也不建议把所有 UI 都迁到一个插件。**

| 维度 | 评价 | 主要依据 |
|---|---|---|
| 基础结构 | 良好 | 入口、core、插件、语言扩展分层明确 |
| 实现正确性 | 基础通过，局部有实质缺陷 | 43 个 Lua 文件语法/格式通过；Java 生命周期、命令范围等隔离实验失败 |
| 模块边界 | 中等，业务向核心层聚集 | 项目历史、选择器渲染、Java 运行混在命令模块；向导混合流程、UI、进程 |
| UI 设计 | 有统一语言，响应式实现不完全 | 透明编辑区与实底卡片一致；真正 TUI 中通用选择框窄屏越界 |
| 操作语义 | 个性化合理，局部承诺失真 | J/K、gh 等是明确偏好；强制退出、F5、当前会话、最近项目的语义需修正 |
| 数据与进程边界 | 优先加固 | 自动保存覆盖放弃语义、单行转换越界、历史竞态、AI 重启目标不稳定 |
| 文档与维护 | 信息丰富，但已出现漂移 | 同一主题在实现、速查、文档、历史说明中存在多个版本 |

### 优先处理的五类风险

1. **放弃/范围边界**：`:q!` 仍会尝试保存；`:2CJKPunctFix` 实际转换全文。
2. **进程目标边界**：从编辑窗口触发 AI 重启时，“当前会话”可能是任意一个会话。
3. **持久化边界**：项目历史的读后检查并不能封闭并发截断窗口。
4. **项目隔离边界**：Java 重附加可能选择另一个项目的 jdtls，客户端消失后又不重启。
5. **调试生命周期**：Java F5 在已有会话时不是继续；自动热替换和 DAP 延迟加载的实际行为也与注释不一致。

### 分级口径

- **P0**：当前环境普遍无法启动或灾难性故障。本轮未发现。
- **P1**：有机会写错范围、中断错误对象、丢失状态或跨项目串用；应优先处理。**不代表每次启动必现。**
- **P2**：具体功能、生命周期、异常分支或布局存在可定位偏差。
- **P3**：说明、组织与维护性问题。

本报告登记 **17 项：P1 5 项、P2 11 项、P3 1 组**。其中包含“需要明确设计决策”的风险，不把所有个性化取舍称为 bug。

证据标记：**运行**＝本机隔离执行实际配置；**替身**＝执行真实函数/闭包，但以 stub 截获服务、进程或磁盘操作；**源码**＝配置与当前安装版上游契约交叉核对；**条件**＝仅特定输入、并发时序或异常分支触发。

## 2. 审查基线、方法与限制

### 2.1 配置快照

- 工作目录：`/home/pang/.config/nvim`。
- 复查时 Git HEAD：`53d101535aaaf828da27dc7ccd3ce42eab21ae7d`。
- 主体测试采样为 **43 个 Lua 文件，共 5,910 行**（含注释与空行）；交付前外部修改使总行数变为 **5,946 行**；[插件锁文件](<lazy-lock.json>)记录 **36 个插件条目**。
- 最大三个模块：[Spring 向导](<lua/core/spring_wizard.lua>) 1,171 行、[Java](<lua/plugins/lang/java.lua>) 674 行、[命令模块](<lua/core/commands.lua>) 483 行，合计约 **39.4%** 的 Lua 行数。行数不是质量分，但说明复杂性集中在哪里。
- 开始时观察到 [速查表](<lua/core/cheatsheet.lua>)、[Sidekick 配置](<lua/plugins/sidekick.lua>)有未提交修改，随后工作树变为干净；交付前又观察到 Sidekick 外部新增 36 行滚轮/PTY 转发逻辑。已重新读取并校正报告行号，F03/F16 涉及的逻辑没有变化，其他 42 个 Lua 文件与主体测试采样内容一致。本轮没有提交、还原或覆盖这些配置文件；新加滚轮行为只做静态复核及语法/格式检查，未启动 AI CLI 验收。
- 已加载本机 nvim-config / nvim-troubleshooting 审查规范；规范中的历史结论只作为线索，遇到冲突以当前配置和本机插件/runtime 为准。

### 2.2 验证纪律

- 健康检查和 TUI 使用临时 XDG data/state/cache；仅引用现有 lazy、Mason、parser 等安装产物，项目历史写入临时位置。
- 使用 `-n -i NONE` 禁用 swap/持久 ShaDa；审计会话关闭自动保存，关闭 Mason 自动安装检查，并用临时时间戳抑制 Treesitter 自动下载。
- 没有更新/安装插件，没有启动真实 Java/Spring LSP、调试目标、AI CLI 或新的 tmux 会话，没有对用户项目做编译、重构或保存。
- 涉及历史截断、退出写盘和 Java 生命周期的危险验证采用内存替身/写调用截获，不对用户数据执行破坏动作。
- **这些控制会改变自动安装和启动性能路径，因此本轮不能证明真实默认启动绝不联网，也不能把启动数字当生产性能基准。**

### 2.3 已执行结果

| 检查 | 结果 | 解读 |
|---|---|---|
| 全部 Lua 的 loadfile 编译检查 | **43/43 通过** | 证明语法正确，不证明所有分支运行正确 |
| StyLua --check | **退出码 0** | 使用现有[格式规范](<stylua.toml>)，没有自动改格式 |
| 隔离完整配置 checkhealth | **退出码 0，报告生成** | 有告警/错误，见第 6 节分类；退出 0 不等于全功能通过 |
| 真 PTY TUI，120×40 / 80×24 / 40×16 | **三个进程均退出 0** | UIEnter 确实触发，均检测到 1 个 UI |
| vim.ui.input 所有者 | **Snacks.input** | headless 中的未接管错误不能直接当真实 UI 故障 |
| vim.ui.select | **配置 wrapper → Snacks** | 身份比较不等于原函数，但能打开选择器且关闭回调得到取消 |
| 冷启动 :Sidekick 是否存在 | **0，不存在** | 已证实文档命令入口缺少懒加载桩，见 F16 |
| 普通模式 3J / 不可修改缓冲区 J | **通过** | 数字前缀移动正常，非可修改缓冲区不会硬报错 |
| 字符/块/Select 模式 J | **移动行正确，选择状态不保真** | 见 F10 |
| 单地址 CJKPunctFix | **越过指定范围修改全文** | 见 F02 |

三个空白 TUI 会话的 lazy 统计分别约 **103.6 / 88.5 / 94.3 ms CPU startup**，均为 **36 总数 / 21 已加载**，DAP 未加载。它们不是墙钟总就绪时间，也不包含 Java 服务初始化；尤其不能据此证明“打开 Java 后 DAP 仍未加载”。

## 3. 结构、职责与设计意图

### 3.1 当前结构的优点

[入口](<init.lua#L6-L21>)先设置 leader，再加载 [core](<lua/core/init.lua#L6-L11>)，随后启动 [lazy](<lua/core/lazy.lua#L28-L68>)，最后按条件加载 [Neovide](<lua/neovide.lua>)，顺序清楚。

逻辑分层可概括为：

```text
入口
 ├─ core：编辑器规则、键位、命令、自动命令
 ├─ lazy：插件规格与生命周期
 │   ├─ 通用服务：LSP / DAP / 格式化 / 补全 / Treesitter
 │   ├─ 语言扩展：C/C++ / Java / Go / Rust / Spring
 │   └─ UI：主题 / 选择器 / 消息 / 文件树 / 终端
 └─ Neovide：GUI 专属行为
```

以下职责分配值得保留：

| 能力 | 当前主要所有者 | 判断 |
|---|---|---|
| 搜索、选项选择、文本输入 | [Snacks](<lua/plugins/snacks.lua>) | 收敛选择器是合理的；不是全机所有 UI 都归 Snacks |
| 命令行、消息路由/历史 | [Noice](<lua/plugins/noice.lua>)，配套通知渲染 | 与选择器职责不同，不是简单重复插件 |
| 欢迎页 | [Alpha](<lua/plugins/dashboard.lua>) | 带文件启动不抢首屏；命令入口仍保留 |
| 文件树 | [Neo-tree](<lua/plugins/filetree.lua>) | 与项目根联动明确 |
| 常规终端 / AI CLI | [Toggleterm](<lua/plugins/terminal.lua>) / [Sidekick](<lua/plugins/sidekick.lua>) | 不同生命周期，不能把“关窗口”统一解释成“终止进程” |
| 通用 LSP / Java LSP | [LSP 汇总](<lua/plugins/lsp/init.lua>) / [nvim-jdtls](<lua/plugins/lang/java.lua>) | 安装与启动分离，Java 特殊所有权正确 |
| 保存格式化 | [Conform](<lua/plugins/format.lua>) | Java 有意手动格式化，其他文件明确工具优先、LSP fallback |

### 3.2 边界正在变模糊的位置

1. **命令注册层承担业务实现。** [命令模块](<lua/core/commands.lua#L66-L483>)同时负责项目存储合并、最近顺序、选择器布局、项目切换、Java 单文件编译运行。UI 与持久化很难单测分开。
2. **向导成为微型应用。** [Spring 向导](<lua/core/spring_wizard.lua>)内混有元数据获取、版本分类、校验、协程桥接、动画、高亮、上游 List 补丁和子进程管理。问题不是长文件本身，而是取消/成功/异常无法共享一个可靠收尾边界。
3. **高亮所有权存在逆向依赖。** [Snacks 皮肤](<lua/plugins/snacks.lua#L45-L154>)不仅修改自身，还写全局 FloatBorder/NormalFloat、Noice 和向导高亮，并用延迟覆盖确保最终颜色。观感统一，但主题层不再是唯一事实源。
4. **兼容补丁接触上游内部结构。** [项目插件补丁](<lua/plugins/project.lua#L35-L165>)、[向导 List.render 补丁](<lua/core/spring_wizard.lua#L1108-L1122>)、[选择器高度 wrapper](<lua/plugins/snacks.lua#L219-L258>)都依赖非稳定内部契约。锁版本能提高可复现性，但不能替代更新后的契约测试。
5. **“幂等”标志不总代表真实状态。** Java 的 started_bufs 和 java_dap_wired 标识“曾调用过”，不是“对应资源仍健康”。这是本轮多个生命周期问题的共同原因。

建议逐步抽出项目历史服务、向导纯规则与流程控制器、统一 UI palette；保留现有入口和插件文件，不做大爆炸重构。

## 4. 发现清单

### F01 · P1 · 强制退出仍尝试保存，放弃修改的语义被覆盖

**证据：运行/替身；有意自动保存策略引出的设计风险。**

位置：[自动保存过滤与写入](<lua/core/autocmds.lua#L47-L95>)、[退出事件](<lua/core/autocmds.lua#L103-L107>)。

- **触发**：有名、可写且修改过的普通缓冲区执行 `:q!` / `:qa!`；QuitPre/VimLeavePre 不区分“正常结束”和“放弃”。
- **实证**：隔离执行真实 `q!`，截获写函数，退出链两次到达 write_current。没有向真实文件写入。
- **影响**：用户以为丢弃的改动可能落盘；关闭一个窗口也可能保存其他已修改缓冲区。confirm=true 不能保护已经被自动保存的内容。
- **建议**：先明确产品语义：保留自动保存，但提供真正的 discard 路径并明确提示。临时可以先设 `vim.g.core_autosave = false` 再放弃；这不能撤销此前已发生的自动保存。另应汇总写失败，不用 silent! 让用户误以为保存成功。

这里**不是要求取消所有自动保存**。过滤普通文件、排除只读/终端、重入保护、不在 CursorHold 保存，都是合理措施。

### F02 · P1 · CJKPunctFix 的单地址范围变成全文

**证据：运行，确定复现。**

位置：[范围判定](<lua/core/cjk_punct.lua#L86-L106>)。

初始三行与结果：

```text
初始                   :2CJKPunctFix         :2,2CJKPunctFix
甲，                   甲,                   甲，
乙。                   乙.                   乙.
丙！                   丙!                   丙！
```

- 原因：只在 cmd.range == 2 时使用 line1/line2；单地址的 range == 1 落入“全文”分支。
- 影响：明确指定一行却改了整个文件；若随后切换缓冲区，自动保存会把超范围改动写盘。
- 建议：区分“无显式范围”与“有范围”，接受单地址和双地址；为无范围、单地址、双地址、可视范围加入回归测试。

### F03 · P1 · AI 重启没有稳定绑定同一个会话

**证据：源码、条件；没有执行真实 kill。**

位置：[目标选择](<lua/plugins/sidekick.lua#L126-L134>)、[重启操作](<lua/plugins/sidekick.lua#L136-L155>)；上游 [close 的实现](</home/pang/.local/share/nvim/lazy/sidekick.nvim/lua/sidekick/cli/init.lua#L154-L159>)。

- **触发**：存在多个 AI CLI / 多个项目会话，从普通编辑窗口按 `<leader>aR`。
- **问题链**：没有面板 session id 时 pairs(terminals) 任取一项 → kill-session 未确认、未检查退出码 → close() 又不指定该对象 → 150 ms 后仅按 tool 重开 → 立即通知“已重启”。
- **影响**：可能中断非预期任务；杀掉、detach、重新 show 三步的目标不一定一致，cwd 也未被锁定；失败仍可能显示成功。
- **建议**：明确选择和确认目标，捕获 session id/cwd/tool，以同一个对象完成全链；检查终止结果后才重建并报成功。未聚焦且多会话时不能“随便取一个”。

持久 tmux、关闭面板仅 detach、AI CLI 自己管理滚动，均是合理设计，不是本项问题。

### F04 · P1 · 项目历史写守卫仍存在检查后截断的竞态窗口

**证据：真实 wrapper + 上游 writer 的内存替身定序实验；并发条件。**

位置：[写守卫](<lua/plugins/project.lua#L118-L164>)；上游 [截断写实现](</home/pang/.local/share/nvim/lazy/project.nvim/lua/project_nvim/utils/history.lua#L145-L174>)。

```text
A 读取磁盘 {项目A}，本次计划也是 {项目A}
B 在间隙追加 项目B
A 判断“不会丢条目”，调用 original_write() 的 w 模式
最终仅剩 项目A
```

- 检查与写入之间没有跨实例锁；“计划覆盖刚才读到的集合”不等于覆盖写入时的磁盘集合。
- [镜像与回填](<lua/core/commands.lua#L125-L163>)显著降低了损害：**已经镜像的记录可以恢复，不能说历史必然永久丢失**。但未镜像记录仍有窗口；[镜像标记列表](<lua/core/commands.lua#L170-L182>)也没有覆盖[检测列表](<lua/plugins/project.lua#L16-L30>)中的所有项目类型。
- 异常时又回退 original_write 的行为与“守卫失败也不破坏数据”的目标不一致。
- **建议**：将 append-only 作为正常事实来源；压缩/去重时使用跨实例锁与原子替换。单独使用原子 rename 不能解决读改写的丢更新问题。守卫失败应保守停止/追加，不回退破坏性截断。

### F05 · P1 · Java 重附加会跨项目取客户端，失败后也不再重试

**证据：实际配置闭包 + 客户端替身，确定复现。**

位置：[Java 启动/去重逻辑](<lua/plugins/lang/java.lua#L593-L653>)。

- **触发一**：一个 Neovim 中打开 A/B 两个 Java 项目，再触发 B 的 FileType，例如重载。
- **实证**：初次启动 A/B 的计数为 2；B 重入时附加到 A 的 client 101，而 B 自己的 client 是 202。判断只取全局 jdtls 列表第一项，未比较 root，也未先确认 B 已挂到正确客户端。
- **触发二**：客户端全部退出，或第一次启动失败后重试；started_bufs 已为 true，仍直接 return。替身实验中 clients 清空后启动计数保持 2。
- **影响**：跨项目或双客户端响应，停止/失败后无法自动恢复；这与“每项目独立 workspace”的设计承诺冲突。
- **建议**：使用 root-aware 的 start_or_attach 复用逻辑，或缓存并校验 client id/root/存活状态。失败不记为启动成功，没有匹配的存活客户端就重新启动。异步回调捕获明确 bufnr，避免重新解释“当前缓冲区”。

### F06 · P2 · Java F5 在断点处是重新运行，不是继续

**证据：映射替身 + 当前 DAP 源码。**

位置：[调试入口](<lua/plugins/lang/java.lua#L364-L388>)、[缓冲区 F5](<lua/plugins/lang/java.lua#L487>)；对照[全局 F5](<lua/plugins/dap/init.lua#L108>)。

- debug_java 不检查 dap.session()，而是选配置后 dap.run()。
- 活跃会话替身得到 **run=1、continue=0**；上游 [dap.run](</home/pang/.local/share/nvim/lazy/nvim-dap/lua/dap.lua#L614-L622>)对同名活动配置明确执行 restart。
- 因而断点处再按 F5 会重启/再选主类，而不是继续，丢失当前调试状态。
- **建议**：有对应活动会话时优先 continue；没有会话才扫描并启动。顺便把全局 Java configurations 缓存按项目过滤，避免当前项目沿用另一项目主类。

### F07 · P2 · Java 的 DAP 延迟加载与自动热替换被上游初始化顺序绕过

**证据：实际上游 _on_attach + DAP 替身。**

位置：[本地按需接线](<lua/plugins/lang/java.lua#L137-L152>)；上游 [attach 时主动 require DAP](</home/pang/.local/share/nvim/lazy/nvim-jdtls/lua/jdtls/setup.lua#L212-L220>)、[已有适配器就早退](</home/pang/.local/share/nvim/lazy/nvim-jdtls/lua/jdtls/dap.lua#L709-L733>)。

- 本地延后 require 并不能阻止上游 LspAttach 路径拉起 DAP；服务器声明调试命令时，上游先用默认参数注册 Java adapter。
- 后续 ensure_java_dap 传 hotcodereplace="auto"，会因 adapter 已存在而返回，先前 listener 不变。
- 实验：attach 触发 DAP 加载 **1 次**；再次 auto setup 后 listener 相同；模拟 BUILD_COMPLETE 得到 **0 次 redefineClasses 请求**。
- **建议**：选择一个明确初始化所有者。可以接受 attach 初始化并提前正确传入热替换配置，也可以真正控制上游 attach 行为；不能只挪动本地 require 就宣称已经按需加载。
- **重要反证**：不能直接把 Jg/JG 未调 ensure_java_dap 判为“缺适配器”。当前正常 attach 路径已经由上游注册，它们不是本轮确认的缺陷。

### F08 · P2 · Java 客户端命令异常被当作成功结果返回

**证据：源码契约；未抓取真实服务端报文。**

位置：[异常分支](<lua/plugins/lang/java.lua#L612-L633>)；runtime [错误表构造器](</usr/share/nvim/runtime/lua/vim/lsp/rpc.lua#L128-L146>)、[result/error 双返回值派发](</usr/share/nvim/runtime/lua/vim/lsp/rpc.lua#L389-L424>)。

当 client/global command 回调抛异常时，当前代码把 rpc_response_error 表放在第一个返回值。该 helper 只构造表，不会自动切换 RPC error 通道；因此会被当作成功 result。

**建议**：异常返回 `nil, error_table`；成功的空值仍显式返回 vim.NIL，reloadBundles 的空数组分支保留。必须区分“裸 return nil 导致没有响应”与“return nil, error 是正确错误响应”，不能把历史规则简化成任何情况下都不许返回 nil。

### F09 · P2 · 通用选择框没有采用紧凑预设，窄屏越界，少量条目也不收缩

**证据：真正 PTY TUI 窗口几何 + 上游合并顺序。**

位置：[全局预设](<lua/plugins/snacks.lua#L295-L298>)、[ui.select wrapper](<lua/plugins/snacks.lua#L219-L258>)；上游 [select source 专属预设](</home/pang/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/config/sources.lua#L991-L995>)、[条目高度逻辑与覆盖合并](</home/pang/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/select.lua#L41-L75>)。

对相同的三个选项调用 vim.ui.select：

| TUI 尺寸 | box width | box col | list height | 观察 |
|---|---:|---:|---:|---|
| 120×40 | 80 | 19 | 12 | 三项仍撑起较高列表，未按条目收缩 |
| 80×24 | 80 | **-3** | 5 | 左侧越过编辑器边界 |
| 40×16 | 40 | **-3** | 2 | 左侧同样越界，列表需要滚动 |

两个独立根因：

1. source="select" 自带 preset="select"，合并时覆盖全局 picker_compact；wrapper 没有重新指定 preset。于是采用上游最小宽度 80 的布局，而不是本地紧凑宽度。
2. wrapper 保存的是“调用方传入的 config”，不是上游按 items 数量设置高度的回调；后续合并替掉了上游回调。新回调只缩减已有数字高度，遇到未设高度的 list 无效，列表继续弹性填满。

**建议**：对 select 源显式指定布局，留足边框余量；保留或重新实现基于条目数量的高度计算。**只补 preset 不足以同时修复高度问题。** 本项是实际窗口/API 几何证据，不是假称已完成截图视觉验收。

### F10 · P2 · J/K 移动后选区列与 Select 子模式丢失

**证据：运行，确定复现。**

位置：[重建选区](<lua/core/keymaps.lua#L152-L178>)。

- 字符选择、Ctrl-v 块选择从第 3～4 列跨两行，J 后两端都变成第 1 列。
- Select 模式执行后变为 Visual 模式。
- 行的位置正确，问题是恢复时把两个 mark 的列固定为 1，再 gv，未保存列、方向和子模式。
- **建议**：保存 anchor/cursor 的列、方向与原模式后恢复；或明确只支持整行选择。无需撤销用户有意设置的 J/K 移行。

### F11 · P2 · 项目列表完整性优先去重，破坏了最近访问顺序

**证据：真实 Projects 路径 + 内存历史替身。**

位置：[历史合并](<lua/core/commands.lua#L125-L152>)、[反转/置顶](<lua/core/commands.lua#L219-L235>)。

副本顺序 A,B,C；插件最新历史 B,C,A；会话 A。合并先将副本放入 seen，后面的 A 无法更新位置；最终得到 C,B,A，而预期最近顺序应为 A,C,B。当前 cwd 置顶只会掩盖“当前项目”的偏差，离开后仍失真。

**建议**：把“哪些项目存在”和“最近访问顺序”分成两种信息。合并时使用最后出现者更新顺序，或独立存 last_seen 时间，不牺牲副本完整性。

### F12 · P2 · 向导的防御分支本身会让协程无法结束

**证据：替身、条件；当前上游正常 selected 数组不触发。**

位置：[确认分支](<lua/core/spring_wizard.lua#L774-L807>)、[关闭分支](<lua/core/spring_wizard.lua#L810-L818>)。

selected 不是数组时，代码已设 completed=true，却调用未定义的全局 finish({})。实验报 `attempt to call global 'finish' (a nil value)`；此后 on_close 因 completed 返回，done 不被调用，协程仍 suspended，_running 不能正常清理。

**建议**：以一个一次性收尾函数统一成功、取消、契约错误：停止 timer、关闭 UI、恢复协程、清运行状态。契约错误应中止，而不是返回“零依赖成功”。测试 selected 为数组/map、缺 list、重复关闭和回调异常。

### F13 · P2 · 向导接受相对父目录，切换 cwd 后主类查找重复解释路径

**证据：源码 + 本机隔离目录解析实验。**

位置：[父目录输入](<lua/core/spring_wizard.lua#L978-L999>)、[主类查找](<lua/core/spring_wizard.lua#L832-L844>)、[创建完成](<lua/core/spring_wizard.lua#L1089-L1094>)。

expand(".") 仍是相对路径。创建完成先 chdir(parent/name)，然后 find_main_class(dir) 又相对于新 cwd 解释同一相对 dir，实际查找重复路径。创建可以成功，但主类不会自动打开；等待子进程期间再切 cwd 也会放大问题。

**建议**：确认父目录时立刻转为规范绝对路径；异步流程只传捕获的绝对 parent/dir，不再从全局当前目录重解释。

### F14 · P2 · RC 版本可能被标成“最新正式版”

**证据：纯函数替身、条件。**

位置：[预发布识别与排序](<lua/core/spring_wizard.lua#L76-L133>)、[展示选择](<lua/core/spring_wizard.lua#L898-L905>)。

模式只识别 M1/R1 一类后缀，不识别 RC1。实验 `4.1.0-RC1` 得到 pre=false，并排在 `4.0.9.RELEASE` 之前。这里不声称当前远端一定提供这个版本，只证明这种输入会被错误分类。

**建议**：使用明确的 RC/M/SNAPSHOT 分类，覆盖点/横线形式；为稳定版、里程碑、RC、快照建立表驱动测试。

### F15 · P2 · “启动不联网”没有覆盖 Mason 的注册表刷新

**证据：当前安装版本的源码调用链；没有主动联网验证。**

位置：[Mason 工具安装器配置](<lua/plugins/mason-tool-installer.lua#L15-L29>)；对照 [lazy 检查器关闭](<lua/core/lazy.lua#L44-L50>)。

上游安装器默认 run_on_start=true、start_delay=0、debounce_hours=nil，VimEnter 后 check_install 会调用 registry.refresh。当前 Mason 注册表默认缓存期为 24 小时；过期会 update。**工具全部安装完成、auto_update=false，也不意味着不刷新注册表。**

上游证据：[安装器默认值](</home/pang/.local/share/nvim/lazy/mason-tool-installer.nvim/lua/mason-tool-installer/init.lua#L33-L43>)、[refresh 调用](</home/pang/.local/share/nvim/lazy/mason-tool-installer.nvim/lua/mason-tool-installer/init.lua#L344-L345>)、[注册表过期刷新](</home/pang/.local/share/nvim/lazy/mason.nvim/lua/mason-registry/init.lua#L178-L209>)。

**建议**：若目标是严格离线启动，关闭启动安装检查，改手动命令。若允许补齐工具或周期刷新，就把“启动不联网”改成准确的例外策略。Treesitter 缺解析器每六小时尝试、lazy 缺管理器引导下载本就有代码说明，不应隐瞒这些例外。

### F16 · P2 · 文档中的 Sidekick 命令冷启动不可达

**证据：运行 + 源码。**

位置：[仅 keys 懒加载](<lua/plugins/sidekick.lua#L26-L35>)、[用户命令说明](</home/pang/md/nvim/nvim命令.md#L82-L90>)。

- 冷启动实测 exists(":Sidekick") = **0**；上游命令在 setup 后才注册。本地没有 cmd 桩。
- 因而按文档直接执行 Sidekick cli show/select/close 会遇到命令不存在，按一次 AI 键或手动加载后才可用。
- 命令 select 的“只列已安装”描述也不准确：该过滤明确写在[本地快捷键](<lua/plugins/sidekick.lua#L112-L114>)，不是裸命令的默认参数。
- **建议**：补 cmd="Sidekick" 懒加载入口，或统一写清命令的先加载条件，并区分裸命令与包装快捷键的过滤行为。

### F17 · P3 · 在线说明与用户文档出现多处漂移

**证据：源码/文档交叉核对。**

| 位置 | 当前描述偏差 | 应如何处理 |
|---|---|---|
| [which-key 提示](<lua/plugins/whichkey.lua#L78-L88>) | g0/g^/g$/gj/gk 写“忽略折行”；gD 写“局部定义” | 前者是显示/屏幕行语义；gD 是文件内全局声明。只改说明，不改实际键位 |
| [速查表](<lua/core/cheatsheet.lua#L84>) | C-j/C-k 写“上/下” | 与[实际下/上](<lua/plugins/snacks.lua#L27-L30>)顺序相反 |
| [插件介绍的 Alpha](</home/pang/md/nvim/nvim插件介绍.md#L200>) | 声称已有 AlphaDash* 专属组和重应用 hook | [当前实现](<lua/plugins/dashboard.lua#L47-L53>)仍用 Type/Label/Keyword；不能把设想写为已完成 |
| [插件介绍的分组](</home/pang/md/nvim/nvim插件介绍.md#L209>) | s 仍包含窗口，遗漏 a/v | 实际 s=Spring、v=窗口、a=AI |
| [插件介绍的 picker](</home/pang/md/nvim/nvim插件介绍.md#L216-L217>) | 宽度仍为 0.5/max100，且声称 ui.select 已统一 | [当前紧凑预设](<lua/plugins/snacks.lua#L198-L205>)是 0.55/max110；select 例外见 F09 |
| [架构文档](</home/pang/md/nvim/nvim配置架构.md#L153>) | 项目 source 仍写 projects | 与[同文警告](</home/pang/md/nvim/nvim配置架构.md#L129>)及[当前实现](<lua/core/commands.lua#L342>)冲突，照抄可能引回旧故障 |
| [Spring 指南主体](</home/pang/md/nvim/构建SpringBoot项目实操指南.md#L108-L134>) | 默认仍描述为粉色透明 | 与[末尾 soft 说明](</home/pang/md/nvim/构建SpringBoot项目实操指南.md#L641-L644>)不一致；旧样式应标 pink/历史方案 |

建议建立“实际映射/命令 → 可生成说明 → 用户文档”的单一数据来源。历史记录保留原因，但应标明版本、已回退、被后续结论修正，不能继续充当不经核验的当前契约。

## 5. UI、交互与“意味”的综合评价

### 5.1 视觉语言是成立的

当前默认不是“所有地方都透明”，而是**透明的编辑画布 + 实底的信息卡片 + 相对稳定的上下栏**。这能区分持续工作区与临时决策区，是有意义的视觉层次。

真实 TUI 高亮读取确认：

| 语义 | 实际值 | 评价 |
|---|---|---|
| 主编辑区 Normal | 前景 #cdd6f4，未显式设置背景 | 保留终端透明背景 |
| 通用浮窗 NormalFloat | 背景 #1e1e2e | 信息卡可读性优先 |
| FloatBorder | #7f849c | 弱化结构边框 |
| FloatTitle | #89b4fa，bold | 用蓝色标记标题/操作层次 |
| 选择行 | #313244，bold | 使用底色和字重，而不是仅靠文字颜色 |

这与[主题](<lua/plugins/theme.lua#L14-L16>)和[皮肤实现](<lua/plugins/snacks.lua#L66-L90>)一致。不能因透明偏好不符合审查者习惯，就要求全部改成实底。

**仍有改善空间**：高亮颜色散落在多个配置文件；全局颜色由 picker 文件写入使职责反向。应把颜色语义提取为 palette，例如 background/card/border/accent/muted/error，而不是让多个模块重复十六进制值与覆盖顺序。

### 5.2 信息密度与响应式

- 紧凑 picker 减少视觉跳跃，适合反复选文件/项目，但隐藏预览降低了 grep 长行、相似路径、LSP 候选的辨认能力。建议按任务提供紧凑与带预览两种入口，而不是让所有任务永远共用同一宽度。
- [速查窗口](<lua/core/cheatsheet.lua#L279-L362>)限制了窗口尺寸，却使用单行 key+中文说明和 nowrap；“窗口没有越界”不等于“内容完整可读”。建议窄屏把 key/说明分两行，增加搜索/按 filetype 过滤。
- [诊断换行](<lua/core/options.lua#L139-L146>)选取该 buffer 的第一个窗口计算宽度。同一文件在宽窄两个窗口中显示时，这不是每窗口独立布局；20 列下限也可能超出极窄文本区。属于静态边界风险，本轮未做多窗口诊断重排实测，不计为额外已复现缺陷。
- 欢迎页的 logo/页脚依据初始化时宽度选取；后续 resize 的动态适应应补测。Neovide、Kitty 背景合成、字体/CJK 字宽、光标动画没有截图验收。

### 5.3 键位的语法与认知负担

合理的部分：

- f=查找、a=AI、t=终端、v=窗口、s=Spring，具有记忆规则。
- J/K 移行、gh 悬浮、leader+j 合并是明确的个性化，不应恢复成原生键后声称“修复”。
- 文件树 r/m、普通编辑窗口与 picker 的不同键位所有权是上下文设计，不是有同名键就算冲突。
- which-key 显式触发范围与内置 gc/gcc 的选择总体清楚。

负担主要来自**同一个键跨上下文改变意味**：C-j/k 在编辑窗是切窗，在 picker 是选项移动；Tab 涉及补全、snippet、括号跳出、多选；jk 在终端可能与 CLI 原始输入冲突；AI CLI 还区分 native_scroll 与 scrollback。

建议通过上下文提示和精确说明解决，不一律消除复用。补全 Tab 的最终菜单交互本轮未做矩阵测试，不能仅依据旧文档“neotab 抢键”判定冲突；必须查看 InsertEnter 后的 buffer-local 映射及菜单状态。

### 5.4 更深层的设计意味

这套配置的价值取向是：**替用户推断上下文，减少重复确认，保留连续工作流。** 自动保存、自动识别项目、自动选择主类、自动保持 AI 会话，都服务于这一目标。

但便利性的另一面是：当对象或意图不唯一时，系统仍在自动行动。本轮问题恰好集中于：

- “当前”究竟是当前窗口、当前 buffer、当前 root，还是任意活动会话？
- “继续”究竟是恢复当前调试，还是重新启动？
- “最近”究竟是首次加入副本顺序，还是最后访问时间？
- “取消/放弃”究竟只关闭 UI，还是保证不再产生持久副作用？
- “成功”是已调用操作，还是已观察到期望状态？

**下一阶段应把这些词变成代码中的不变量。** 例如 destructive action 必须有明确 target；取消必须完成清理且不可再推进流程；success 只能在返回码/资源状态确认后显示。这样比继续添加零散保护 if 更能提高一致性。

## 6. 配置正确性、健康检查与反误报

### 6.1 已确认合理的配置

| 检查项 | 结论与证据 |
|---|---|
| root_dir API | [C/C++](<lua/plugins/lang/cpp.lua#L23-L31>)使用 bufnr/on_dir；[Java](<lua/plugins/lang/java.lua#L598-L604>)预求值字符串。二者属于不同调用层，不能套同一个签名规则 |
| LSP 启动所有权 | [Mason 自动 enable 被关闭](<lua/plugins/lsp/init.lua#L35>)；[jdtls 明确跳过通用管理](<lua/plugins/lsp/init.lua#L84-L86>) |
| Rust 工具缺失 | [rustc/cargo 守卫](<lua/plugins/lsp/init.lua#L87-L99>)避免无工具链时盲启；不等于本轮验证了 clippy/rustfmt 所有行为 |
| Mason 初始化 | 当前 health 没有“mason has not been set up”，安装和服务启动职责基本分开 |
| 保存格式化 | [BufWritePre 与 keys 入口](<lua/plugins/format.lua#L7-L55>)存在；Java 保存返回 nil，手动格式化可用；2000 ms 与显式 fallback 合理 |
| 格式化 fallback 意义 | 工具不可用时可选 LSP；不是保证外部工具执行失败后一定再尝试 LSP |
| 诊断跳转 | [当前实现](<lua/core/lsp_on_attach.lua#L42-L48>)用 jump/on_jump，未沿用旧 goto API |
| 旧 API 检索 | 本体未命中本轮检索的旧 option API、get_active_clients、start_client、diagnostic.goto_* 等。静态未命中不覆盖所有动态插件路径 |
| Noice override | 配置中出现 stylize_markdown 开关，不等于实际调用已废弃实现；不能仅按字符串报警 |
| 项目 UI 入口 | Projects 命令启动即存在；[source/project_dir](<lua/core/commands.lua#L339-L387>)避免已知内置源/字段冲突 |
| 项目与文件树 | [bind_to_cwd](<lua/plugins/filetree.lua#L36>)及 Lua API 导航规避了空格路径的字符串解析问题 |
| Treesitter | CLI/parser ABI、当前要求的安装项 health 通过；存在 CLI 路径兜底和安装节流 |
| DAP 条件/日志断点 | [空输入处理](<lua/plugins/dap/init.lua#L91-L105>)有守卫，固定 listener key 避免简单重复堆积 |
| 模型/脚本边界 | modeline 被禁用；[向导进程](<lua/core/spring_wizard.lua#L1073-L1079>)使用 argv，不做 shell 字符串拼接 |

### 6.2 健康报告的正确解释

不能把 checkhealth 的红字数直接当成配置缺陷数。本轮主要告警如下：

| 项目 | 原因/分类 | 是否要求安装或修改 |
|---|---|---|
| Snacks.input 未接管 | headless 未触发 UIEnter；真实 TUI input_owned=true | **不作为配置故障** |
| Snacks.picker select 身份比较失败 | 本地 wrapper 改变函数身份；真实选择器能打开并回调取消 | **身份错误为已知假阳性**；但 F09 的几何问题是真问题，两者分开 |
| Snacks.image 的 magick/gs/LaTeX/Mermaid/kitty graphics 错误 | image 模块未启用，且 headless TERM=dumb | 无需为消红盲装依赖 |
| Snacks.notifier not ready | notifier 明确关闭，通知由其他栈负责 | 不作为所需功能故障 |
| lazygit 未安装 | 当前没有要求使用该工作流 | 可选依赖，不必为本配置修复而安装 |
| Mason 缺 luarocks/Ruby/RubyGem/Composer/PHP/Julia/pip | 面向广泛工具生态的可选检查 | 按将要安装的工具决定；不等于现有 Java/C++/Go/Rust 服务失效 |
| Blink disabled-provider 提示 | 插件自己提示部分 source 动态启用 | 不是补全整体禁用 |
| lazy/vim.pack 提示已有 pack 目录却无锁文件 | 实查只有空 core/opt 目录，无包文件 | 历史空目录提示，未见第二套管理器实际加载插件；不要为消警告新启用 vim.pack |
| vim.lsp 没有 active client | 审计会话未打开语言项目 | 预期，不证明 LSP 已端到端通过 |
| vim.deprecated / vim.health configuration | 本次执行路径未发现问题 | 不代表未触发分支或所有插件都无废弃 API |

### 6.3 需要明示但不是硬 bug 的边界

- **:R 不是完整热重载。** [实现](<lua/core/commands.lua#L8-L14>)执行当前磁盘 Lua，不保存未提交 buffer、不清 package.loaded、不将 return 出来的 spec 重新交给 lazy。隔离验证插件 spec 不触发 setup，已缓存入口模块不会重跑。其当前 desc 基本准确；文档应明确插件结构变更优先重启，而不是盲目清缓存。
- **JavaRun 是轻量单文件入口。** [实现](<lua/core/commands.lua#L426-L483>)不是 Maven/Gradle classpath 感知运行器；无 package 与有 package 两条分支有不同能力。应提示未保存内容、外部依赖、无 main 类的边界，不承诺替代 IDE 项目运行。
- **中文标点转换是文本策略，不是语法感知。** [排除表](<lua/core/cjk_punct.lua#L47-L56>)不含 markdown.mdx；代码中的中文字符串/注释仍可能转换。是否细分上下文属于用户偏好，应明确规则；单行范围越界则是 F02 的真实错误。
- **缺 bootstrap 管理器时会联网且缺少友好失败出口。** [引导实现](<lua/core/lazy.lua#L6-L25>)检查入口完整性是好事；clone 返回码/失败说明还可增强。当前已安装路径没有触发该故障。
- **包名与子进程收尾可加强。** 向导通用名称校验并非 Java/Kotlin 分段标识符校验；子进程未暴露总超时/取消句柄。未联网验证服务端是否会再次规范化输入，不断言必生成非法项目。
- **日志与大文件策略**：[LSP 日志轮转](<lua/core/options.lua#L64-L74>)限制增长有价值；多实例下不是集中式日志管理。Snacks bigfile 被禁用，也没有统一大文件降级预算；建议先测真实大文件再决定，不直接判“启动慢”。

## 7. 建议的实施顺序与验收标准

### 第一阶段：先守住对象与副作用

对应 F01～F05。每个问题单独改、单独验证，不与换主题/升级插件混在同一批。

| 事项 | 最小验收 |
|---|---|
| 放弃修改路径 | 修改两个缓冲区，验证保存退出与明确丢弃退出分别符合契约；失败写盘可见 |
| CJK 范围 | 无范围、单地址、同地址双范围、多行和可视范围都仅修改预期行 |
| AI 重启 | 两工具×两项目，编辑窗/面板两种入口均明确目标；取消不终止；失败不报成功 |
| 项目历史 | 并发读写、检查后追加、空历史、损坏数据、未镜像条目均不丢更新 |
| Java 隔离 | A/B 项目、重载、停止客户端、启动失败重试；每个 buffer 只归正确 root |

### 第二阶段：统一生命周期与 UI 契约

- Java：F5 首次启动/断点继续/重新运行区分；main 配置按项目；热替换在实际 BUILD_COMPLETE 验证；异常 RPC 验证 error 而不是 result。
- UI：三个尺寸检查所有边框在屏内；3/30 个选项验证高度与滚动；字符/块/Select 模式移动后保留范围。
- 向导：成功、Esc、上游类型变化、相对路径、网络失败/超时都回到可再次启动状态。
- 安装：断网与缓存过期测试，核对“启动联网策略”而不是仅 checker.enabled。

### 第三阶段：降低维护成本，不改变个人偏好

建议的目标结构（名称仅示意，不是本轮创建的文件）：

```text
core/
  commands              仅命令入口、参数与服务调用
  project_history       append/merge/order 的独立服务
  java_lifecycle        client/root 与 DAP 初始化所有权
  spring/
    metadata            获取与缓存
    rules               版本、名称、路径等纯函数
    flow                状态机、一次性收尾、取消
    ui                  picker/input/highlights
  ui_palette            共享语义色
  keymap_catalog        映射/说明的可核验事实源
```

对 monkey-patch 单独登记：依赖的上游版本、函数形状、正常/错误/取消用例、何时可以删除。插件更新前跑这些契约测试，不将“本次没有报错”替代“补丁仍正确”。

用户文档更新时应同步[速查表](<lua/core/cheatsheet.lua>)、[which-key](<lua/plugins/whichkey.lua>)和相应的[快捷键说明](</home/pang/md/nvim/nvim快捷键.md>)、[命令说明](</home/pang/md/nvim/nvim命令.md>)、[架构说明](</home/pang/md/nvim/nvim配置架构.md>)。**本轮没有修复配置，因此没有把尚未实施的建议写成“已完成”的用户文档。**

## 8. 审查覆盖与复查入口

### 8.1 文件覆盖

- 核心：已覆盖[入口](<init.lua>)、[core 加载](<lua/core/init.lua>)、[选项](<lua/core/options.lua>)、[文件类型](<lua/core/filetypes.lua>)、[键位](<lua/core/keymaps.lua>)、[命令](<lua/core/commands.lua>)、[自动命令](<lua/core/autocmds.lua>)、[CJK](<lua/core/cjk_punct.lua>)、[速查](<lua/core/cheatsheet.lua>)、[LSP attach](<lua/core/lsp_on_attach.lua>)、[向导](<lua/core/spring_wizard.lua>)、[lazy](<lua/core/lazy.lua>)。
- 语言/服务：已覆盖[LSP](<lua/plugins/lsp/init.lua>)、[语言聚合](<lua/plugins/lang/init.lua>)、[C/C++](<lua/plugins/lang/cpp.lua>)、[Java](<lua/plugins/lang/java.lua>)、[Go](<lua/plugins/lang/go.lua>)、[Rust](<lua/plugins/lang/rust.lua>)、[Spring](<lua/plugins/lang/springboot.lua>)、[DAP](<lua/plugins/dap/init.lua>)、[格式化](<lua/plugins/format.lua>)、[补全](<lua/plugins/completion.lua>)、[Treesitter](<lua/plugins/treesitter.lua>)、[Mason](<lua/plugins/mason.lua>)、[工具安装器](<lua/plugins/mason-tool-installer.lua>)、[项目管理](<lua/plugins/project.lua>)。
- UI/编辑辅助：已覆盖[主题](<lua/plugins/theme.lua>)、[Snacks](<lua/plugins/snacks.lua>)、[Noice](<lua/plugins/noice.lua>)、[状态栏](<lua/plugins/statusline.lua>)、[缓冲栏](<lua/plugins/bufferline.lua>)、[启动页](<lua/plugins/dashboard.lua>)、[文件树](<lua/plugins/filetree.lua>)、[which-key](<lua/plugins/whichkey.lua>)、[终端](<lua/plugins/terminal.lua>)、[Sidekick](<lua/plugins/sidekick.lua>)、[图标](<lua/plugins/devicons.lua>)、[Neovide](<lua/neovide.lua>)、[自动配对](<lua/plugins/autopairs.lua>)、[退出插入](<lua/plugins/betterescape.lua>)、[Flash](<lua/plugins/flash.lua>)、[缩进线](<lua/plugins/indentline.lua>)、[Neotab](<lua/plugins/neotab.lua>)。

覆盖指阅读/静态审查与语法格式检查，不表示逐插件所有功能端到端通过。

### 8.2 可复查命令与最小案例

格式检查（只读）：

```bash
~/.local/share/nvim/mason/bin/stylua --check --config-path stylua.toml init.lua lua
```

命令范围案例（仅 scratch buffer，不加载用户完整配置，不写文件）：

```bash
nvim -n -i NONE -u NONE --headless \
  '+lua dofile("/home/pang/.config/nvim/lua/core/cjk_punct.lua")' \
  '+lua vim.api.nvim_buf_set_lines(0,0,-1,false,{"甲，","乙。","丙！"})' \
  '+2CJKPunctFix' \
  '+lua print(vim.inspect(vim.api.nvim_buf_get_lines(0,0,-1,false)))' \
  '+qa!'
```

报告内已保留关键输出。完整临时取证位于本次审计目录：

- [健康检查原文](</tmp/nvim-audit-DW0K7IPQ/health.txt>)。
- [核心隔离实验脚本](</tmp/nvim-audit-DW0K7IPQ/core-probes.lua>)与[结果](</tmp/nvim-audit-DW0K7IPQ/core-probes.json>)。
- [TUI 驱动](</tmp/nvim-audit-DW0K7IPQ/tui-driver.py>)、[TUI 探针](</tmp/nvim-audit-DW0K7IPQ/tui-probe.lua>)、[隔离前置设置](</tmp/nvim-audit-DW0K7IPQ/preflight.lua>)。
- [120 列结果](</tmp/nvim-audit-DW0K7IPQ/tui-120.json>)、[80 列结果](</tmp/nvim-audit-DW0K7IPQ/tui-80.json>)、[40 列结果](</tmp/nvim-audit-DW0K7IPQ/tui-40.json>)、[源文件观测清单](</tmp/nvim-audit-DW0K7IPQ/source-manifest.json>)。

临时目录可能被系统清理；本报告本身不依赖这些文件才能理解结论。团队的部分替身实验通过标准输入执行，没有保存为永久测试套件，应在实施修复时将关键案例正式纳入仓库。

### 8.3 尚未验收的边界

没有对真实 Maven/Gradle 多模块项目、Spring classpath 握手、Java 测试/热替换、Codelldb/Delve、真实 formatter 调用、长时间多实例历史压测、IME 多字节输入、Kitty/Neovide 合成视觉、AI 服务进程恢复做端到端验收。也没有验证所有插件的最新上游版本；本报告面向当前锁文件与本机安装版本。

因此最终结论是：**架构方向和个人交互风格值得保留；基础启动与语法质量不错，但自定义兼容层的目标绑定、取消/失败收尾、跨实例持久化、跨项目生命周期需要系统加固。先修这些契约，比继续微调视觉或减少插件数量更有收益。**
