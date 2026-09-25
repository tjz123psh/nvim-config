# 动手前评估：能力自查 · 真实性复核 · 备份（2026-09-24）

> 对象：`nvim-config-audit-20260924.md` 里的待修项（第一轮 8×P1 + 13×P2 + 9 建议，第二轮 3 条深挖 + 5 条硬伤）
> 结论：**报告可信**——30+ 条关键结论里我亲手复现 24 条、源码/API 级复核 4 条、仍有 6 条只有队友证据（已在 §2.3 单列并给出处理方式）；**0 条被证伪**，**2 处引用不准确已订正**。
> **备份已完成并逐字节校验**（§3）。可以开工，但 §4 有 5 件事需要你先拍板。
>
> ⚠ **本文件是「动手前」的评估**（2026-09-24 傍晚）。实施结果、已解决/未解决清单、事故复盘与验收命令，全部在 **`nvim-config-audit-20260924.md` 的 §19「最终状态与交接」（第一轮）与 §20「第九批：按 §19.8 继续收尾」（第二轮，最新）**；本文件 §1 的能力自查与 §3 的回滚命令仍然有效。

---

## 一、能力自查：这些修复我能不能做

### 1.1 我能改、且能自证（11 项，建议第一批做）

| # | 改动 | 我的自证手段 | 风险 |
|---|---|---|---|
| 1 | `theme.lua:25` `lualine = { enabled = true }` | 探针读 `get_config().options.theme` 必须是 `catppuccin-mocha`，且 `lualine_a_normal.bg = #89b4fa`（现在是 `auto` + `c_normal.bg = #000000`） | 极低（一行） |
| 2 | `options.lua` 诊断块（`severity_sort` + WARN/ERROR 分流 + `float.suffix`） | 配置探针 + **屏幕单元读取**（`screenstring` 实测可用）+ 合成"同行 ERROR+WARN"用例，检查 virt_text 取到的是哪条 | 低（官方文档字段；0.12.5 支持 `virtual_lines`） |
| 3 | `completion.lua` blink 三键补 `fallback` | 已有对照实验：`A<C-u><Esc>` 后 buffer 是否变化（现在逐字不变 = 被吞） | 极低 |
| 4 | `terminal.lua` 每个方向独立 terminal id | 窗口列表实测（我已验证 `toggle(id,…)` 可共存；现在 `direction=` 会把终端关掉） | 低 |
| 5 | `whichkey.lua`：补 5 个分组 + `triggers` 收敛 + spec 瘦身 + `<leader>s` 拆分 | 前缀枚举（我已有脚本）+ 打印 trigger 列表 + 逐条核对 desc 与真实映射 | 低（只影响提示） |
| 6 | `noice.lua`：`cmdline.format.input.title`、`views.cmdline_*.size.width = 74`、错误视图改 `split` | dump 解析后的 config + float 几何（现在 82 列 > 80 列） | 低 |
| 7 | 清理 `~/.local/state/nvim/lsp.log`（27 MB） | 清理前先 gzip 备份到备份目录；清理后看文件大小 | 低（但属"删东西"，见 §4.4） |
| 8 | 删空目录 `~/.local/share/nvim/site/pack/core/opt` | 目录消失 + `:checkhealth vim.pack` 警告消失 | 极低（0 字节） |
| 9 | `java.lua` 首个 Java buffer 的双 attach 守卫 | `vim.lsp.start` 计数器（我已用过：现在 `LSP_START_CALLS=4`，改后应为 2） | 低 |
| 10 | `application.properties` / `*.gotmpl` 补 devicon | `get_icon` 回读 + **用 `screenstring` 看 neo-tree/状态栏是否渲染成方块**（这一步以前做不到，现在可以） | 中（字形要在你的 Nerd Font 里存在） |
| 11 | `~/md/nvim` 用户文档同步 + cheatsheet 文案（`<Tab>` 说明、Java 保存不格式化、`<leader>sp`、插件表补 4 个文件/总数 38） | diff 回读 + 与你实际配置逐条比对 | 低（纯文档） |

### 1.2 我能改，但**只能静态证明**，需要你实机点一下（5 项）

| # | 改动 | 为什么不能自证 | 我会怎么降低风险 |
|---|---|---|---|
| 1 | `pick_many` override（代码操作多选 + Esc 取消） | 真 Java 工程里的 jdtls 链路、`is_selected` 预勾选 + Tab 追加的时序异常，headless 复现不了 | 保留**失败回退**到上游 `input()` 版；先用一个假 items 数组自证键位；再请你在真项目点一次 |
| 2 | `spring_wizard.lua:876` 创建步骤异步化 | 向导要 dressing 交互输入，headless 走不完 | 只改这一个 `:wait()`，用 `bridge` 同款写法；改完请你走一遍向导 |
| 3 | `<Tab>` 归 neotab 还是 blink | 谁先赢取决于补全菜单展开时的时序 | 先只改**文档**（零风险）或改键位，你实机按一次再定 |
| 4 | Java 里 `gU`、LSP 里 `gr` 让位给内置键 | 涉及你的肌肉记忆与新键位选择 | 等你拍板新键位再动；不动也行，只改 which-key 描述 |
| 5 | `stylua --check` 全树格式化 | 会格式化 **2 个你未提交的文件**（`cheatsheet.lua`/`java.lua`），产生与你 WIP 混在一起的大 diff | 建议你先 commit/stash，或只格式化与本次修改无关的 3 个文件 |

### 1.3 我不该动（需要你先决策）

- **停维护插件的替换**（`project.nvim` → `vim.fs.root()` 自研、`dressing` → snacks、`Comment` → mini.comment）：这是**需求变更 + 行为重构**，不是修 bug，我不会擅自做。
- **`~/.config/kitty/kitty.conf`**、系统包、上游 issue/PR：超出"nvim 配置"范围，只给建议。
- **你的 6 个未提交改动**：我不会 commit、不会 stash、不会 reset——它们原样保留在工作树里。

### 1.4 我的取证能力边界（诚实说明）

- **能做**：headless 真执行、**屏幕单元级读取**（`screenstring` 实测返回 `"H"`）、配置/高亮取值、映射枚举、真实文件 + 真实 jdtls 复现、上游 API 查询。
- **不能做**：真 TTY 的按键体感与延迟、GUI（Neovide）观感、你机器上真 Java 工程的完整交互、外部网络状态。
- **已知陷阱**（都会避开）：`-c` 在 VimEnter 之前执行（会测到 noice 还没 setup 的假状态）；`which-key.show()` 是交互式的会挂住；`vim.wait` 期间按键不被处理。

---

## 二、真实性复核

### 2.1 总账

| 等级 | 条数 | 说明 |
|---|---|---|
| **Lead 亲手复现** | 24 | 含本轮新增的 10 条（见 2.2） |
| **源码/上游 API 级复核** | 4 | diagnostic.lua 取值、noice 宽度夹取条件、lazy 扫描深度、GitHub API 的 archived/pushed_at |
| **仍有队友证据、我未独立复现** | 6 | 全部列在 2.3，且都写了处理方式 |
| **被证伪** | **0** | — |
| **引用/表述需订正** | 2 | 已改，见 2.4 |

### 2.2 本轮新增的独立复现（最关键的几条）

| 结论 | 我的复核方式 | 结果 |
|---|---|---|
| `pick_many`：空回车/输入/Esc 语义 + 越界崩溃 | **直接执行真函数**（把 `vim.fn.input` 换成桩） | 空回车→`{}`；`1`→`{"a"}`；`1,3`→`{"a","c"}`；**`9`→ 真报错** `ui.lua:50: bad argument #1 to 'find' (string expected, got nil)`；`abc`→静默返回 `{}` ✔ 全部与报告一致 |
| Esc 与空回车不可区分 | 之前已实测（`input()` 返回 `""`），A 线用 pty 真按键复现 | 成立 |
| `severity_sort` 缺省 false，virt_text 只显示**最后一条** message | 读运行时源码 `diagnostic.lua:401`（默认 false）、`:814`（sign 优先级）、`:2277`（`local last = line_diags[#line_diags]` 且只取 `last.message`） | 成立（机制比我原以为的更明确） |
| noice 接管 `vim.notify` 后错误查不到 | VimEnter 后实测：`vim.notify(ERROR)` → `:messages` **不含**；`echomsg` → **含**；键位回调 `error()` → **含**；`vim.notify` 实现来源 = `noice/source/notify.lua` | **成立**（这条是"错误显示"的头条结论，已亲自坐实） |
| noice 浮窗 82 列 > 80 列 | 读 `noice/util/nui.lua:171-179`：`max_width` 只在 `size.width == "auto"` 时才夹；本机写死 78 ⇒ 82 列 | 成立 |
| devicon 缺 `properties`/`gotmpl` | `get_icon(...)` 回读：两者 `nil`，对照 `build.gradle` 有图标 | 成立 |
| `gr` 覆盖 0.12 内置前缀 | `nvim --clean` 枚举：`gra/gri/grn/grr/grt/grx` 六个内置键存在 | 成立 |
| neo-tree `p` 抢粘贴 | 上游默认表 `defaults.lua:482 ["p"]=paste_from_clipboard`、`:499 ["H"]=toggle_hidden`；本机 `filetree.lua:40` 覆盖成 toggle_hidden | 成立 |
| Lua 缩进 2 格 vs 文档 4 格 | `stylua.toml: indent_width = 2`、`autocmds.lua:14-15` 设 `sw=ts=2`；技能文档第 **167** 行写"stylua（默认 4 格）…全部统一为 4 格" | 成立（行号订正） |
| `lang/init.lua` 是 `lang/*.lua` 的唯一入口（吞错=整门语言消失） | 读 lazy 源码 `util.lua:310-335`：只扫 `plugins/` 一层文件 + 子目录的 `init.lua` | 成立 |
| 上游停维护声明 | GitHub API：`dressing.nvim archived=true`（pushed_at 2025-02-12）、`project.nvim archived=false / pushed_at 2024-08-12 / open_issues=96` | 成立（表述已补细节） |

### 2.3 仍只有队友证据、我**没有**独立复现的 6 条（不是不成立，是"我还没亲手验"）

| # | 条目 | 来源 | 我的处理 |
|---|---|---|---|
| 1 | which-key 弹窗渲染计数（z=33 项/20 行、g=42 项/24 行）与 `triggers` 收敛后的实际效果 | C 线（渲染 harness 实测） | 我复现了"缺分组/缺组标题"（前缀枚举）；**改 `triggers` 前我会先复现一次**，确认 `gg`/`zz` 不再弹 |
| 2 | `pick_many` override 端到端（pty 真按键：Tab×3+CR / Esc→nil） | A 线 | 我已验证它用到的 snacks API 形状可用（`win.input.keys`/`formatters.selected`/`toggle_item`）且 `multi=true` 确实抛错；**真 Java 交互留给你实机** |
| 3 | `virtual_lines` 的屏幕效果与"超宽 trunc"上限 | B 线（screenstring dump） | 我已有 screenstring 能力，**实施批次 2 时自己补验** |
| 4 | 自动保存对"后台被改 buffer"仍弹确认（`:qa`） | W1 线 | 影响小（属未提交 WIP 功能）；若要改，改前复现 |
| 5 | 文档同步链逐项清单（插件表缺 4 个文件、34 vs 38、`<leader>sp` 只在 Java 区） | W2 线 | **改文档前逐项复核**（`comm` 对比 + 文档通读） |
| 6 | 停维护清单里除 project.nvim/dressing 外的 3 项（Comment 2024-06、bufferline 2025-01、toggleterm 2025-03） | 调研子代理（commits.atom） | 只作为"中期替换"建议；真要替换前再核 |

### 2.4 已订正的 2 处（诚实记录）

1. §1.7 引用的文档行号 `architecture.md:130` → **:167**（该文件只有 167 行那一处"4 格"表述）。
2. §4.3 project.nvim 的时间表述：补上"GitHub API `pushed_at` 是 2024-08-12（任意分支的最后推送）"，避免与"默认分支 2023-04-03"看起来矛盾。

（更早两轮的订正已记录在报告附录 A：`lsp.log` 的"100 KB 轮转"机制、`Snacks.bufdelete` 误判、`defaults.lazy` 误判。）

---

## 三、备份（已完成并校验）

**位置**：`~/backups/nvim-config-preflight-20260924-185532`（指针：`~/backups/.last-nvim-config-backup`）

| 文件 | 内容 | 校验 |
|---|---|---|
| `nvim-config-full.tar.gz` | `~/.config/nvim` **全量含 `.git`**（426 条，420 KB） | 解包后 `diff -r` 与现场**逐字节一致** ✔ |
| `md-nvim-docs.tar.gz` | `~/md/nvim` 用户文档 | 解包 `diff -r` 一致 ✔ |
| `kitty.conf` | 终端配置副本（本轮只给建议、不改） | — |
| `uncommitted-changes.patch` | 你**6 个未提交改动**的完整 patch（247 行） | — |
| `git-head.txt` / `git-status.txt` | HEAD = `b482732` + 工作树状态 | — |
| `targets.sha256` | 11 个**计划改动文件**的指纹基线 | 改完用 `sha256sum -c` 可证明"只改了该改的" |
| `system-paths.txt` | `lsp.log` 27,385,498 B、空目录 `site/pack/core/opt` | — |

**回滚（三种粒度）**

```bash
# ① 单个文件回滚（最常用）
cp -a ~/backups/nvim-config-preflight-20260924-185532/解包路径/lua/core/options.lua ~/.config/nvim/lua/core/options.lua
# 或直接用 git： git -C ~/.config/nvim checkout -- lua/core/options.lua

# ② 全量回滚（连未提交改动一起还原）
rm -rf ~/.config/nvim && tar -xzf ~/backups/nvim-config-preflight-20260924-185532/nvim-config-full.tar.gz -C ~/.config

# ③ 只还原你改到一半的那 6 个文件
git -C ~/.config/nvim checkout -- . && git -C ~/.config/nvim apply ~/backups/nvim-config-preflight-20260924-185532/uncommitted-changes.patch
```

---

## 四、开工前需要你拍板的 5 件事

1. **诊断显示风格**：ERROR 是否改走 `virtual_lines`（在代码行下方单独占一行）？还是**只加 `severity_sort`**（零观感变化）？后者风险最小。
2. **`<Tab>` 归谁**：让 neotab 继续接管（改文档文案）还是让 blink 优先（改键位）？——我建议**先改文档**，你实机按一次再定。
3. **`gU`（Java 跳父类）与 `gr`（查找引用）**：是否让位给内置键？如果让，新键位用什么（我建议 `gA` 与删掉 `gr` 改用内置 `grr`）。
4. **两处"删东西"**：`lsp.log`（27 MB）清空还是保留（我会先 gzip 备份）？`site/pack/core/opt` 空目录删不删？
5. **用户文档 `~/md/nvim`** 要不要我一并同步（你自己的规矩是"必须同步"，但那是你的文档，我不擅自动）？另外 `stylua` 全树格式化会碰到你 2 个未提交文件，建议你先 commit/stash 或让我只格式化另外 3 个。

---

## 五、分批实施与验收计划（你点头后按此执行）

**批次 1（零风险、我可完全自证）**：#1.1 表格里的 1、3、4、5、6、9 项
验收：`nvim --headless +qa` 无 stderr → lualine 主题探针 → blink 对照实验 → toggleterm 窗口列表 → which-key 前缀枚举 → noice 几何 dump → `LSP_START_CALLS` 计数 → `sha256sum -c targets.sha256` 看 diff 是否只落在预期文件。

**批次 2（观感，需你同步看一眼）**：诊断显示（按你 §4.1 的选择）、devicon、`lsp.log` 与空目录、文档同步
验收：配置探针 + **screenstring 屏幕单元**（确认 virt_text/virtual_lines 布局与图标不是方块）+ `:checkhealth` 警告变化。

**批次 3（需要你参与）**：`pick_many` override（先加回退分支）→ 你在真 Java 工程点一次；向导异步化 → 你走一遍向导；`<Tab>`、`gU`/`gr` 按你的拍板落地；`stylua` 全树按你的时机。

**任何一批出问题**：先 `git -C ~/.config/nvim checkout -- <文件>` 单文件回滚；必要时按 §3 的全量回滚；每批结束我都会报告"改了哪些文件 + 验收输出 + 与基线的差异"。
