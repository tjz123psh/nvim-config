-- ============================================
-- 快捷键提示：which-key.nvim
-- 按 leader 键后弹出分类菜单，显示可用快捷键
-- ============================================

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    -- 只保留 leader / localleader 触发：默认的 <auto> 会把 g、z、[、]、<C-w> 也变成自动弹窗
    -- （实测 z 弹窗 33 项、g 弹窗 42 项），gg/gd/zz 之前先闪一屏很吵
    triggers = {
      -- 2026-09-25 专项复核（最小 init / 真配置+运行时注入 / 真配置副本+真 pty 三层实验）：
      -- 推翻了此前"上游不支持可视模式触发器"的结论（审查报告 §24 第 2 条已订正）。
      -- 真正原因是本表原先只写了 mode = "n"，x 模式没有任何触发器键映射；v/x 等价
      -- （which-key 内部把 v/V/C-V 统一归一成 "x"）。官方写法就是 { "<leader>", mode = { "n", "v" } }
      -- （doc/which-key.nvim.txt:357-362）。
      -- 注意：which-key 只在**当前 buffer 的 x 模式树里存在 <leader> 前缀映射**时才挂触发器，
      -- 所以实际只有 Java 缓冲区会弹（<leader>Rv/RV/Rc/Rm 是 java.lua 的 buffer-local x 键）。
      -- 别改成 { "<auto>", mode = "x" }：实测会给 g/z/[/]/<C-w>/<Space> 全建触发器，
      -- 把当初收窄触发器想避免的噪音又搬回来。
      { "<leader>", mode = { "n", "v" } },
      { "\\", mode = { "n", "v" } }, -- localleader 也弹出
      -- 2026-09-25 用户反馈：「按 g 想看一下定义和引用，按下去毫无反应」。
      -- 查证：g 的 spec 条目一直都有（gd/gh/gi/gR/gO/gr*…），但触发器只留了 <leader>，
      -- 所以按 g 什么都不会弹（gd 本身是好的 —— 真 pty 实测按 gd 能跳到定义）。
      -- 现在**显式**加 g（不是 { "<auto>" }：只加 g，z/[/]/<C-w> 仍然不弹，
      -- 不会把当初收窄触发器想避开的噪音全搬回来）。delay=300ms，
      -- 快速连打 gg/ge 不会闪，停下来才弹。
      { "g", mode = { "n", "v" } },
      -- 2026-09-25 复查（用户问「别的键位有没有类似的影响」）：同一类问题还有 z / [ / ] / <C-w> ——
      -- 它们的 spec 条目（z 33 条、[ 2 条、] 2 条、<C-w> 12 条）一直都在，但同样没进触发器，
      -- 按下去只会"什么都不弹"。既然 spec 是特意写的，就把这 4 个前缀也显式加上。
      -- 有意**不**加的（保持安静）：
      --   · 操作符后的 motion（spec 里 mode = "no" 的 w/b/e/0/$/gg/G…）—— 加了会让每次 d/y/c 都弹；
      --   · 文本对象 a/i（spec 里 mode = "xo"）—— 输入 aw / i( 这类序列时暂停会弹，容易打扰；
      --     需要时手动 :WhichKey a / :WhichKey i 看。
      { "z", mode = { "n", "v" } },
      { "[", mode = { "n", "v" } },
      { "]", mode = { "n", "v" } },
      { "<C-w>", mode = { "n" } },
    },
    delay = 300,
    spec = {
      -- leader 前缀分组
      { "<leader>b", group = "缓冲区操作" },
      { "<leader>c", group = "代码操作" },
      { "<leader>d", group = "调试（DAP）" },
      { "<leader>f", group = "搜索" },
      { "<leader>h", group = "快捷键速查" },
      { "<leader>r", group = "重命名/运行" },
      { "<leader>s", group = "Spring Boot" },
      { "<leader>t", group = "终端" },
      { "<leader>v", group = "窗口：切分" },
      { "<leader>w", group = "保存/退出" },
      { "<leader>G", group = "代码生成（Java）" },
      { "<leader>J", group = "Java 测试 / 调试" },
      { "<leader>m", group = "Maven / Gradle 构建" },
      { "<leader>o", group = "整理 import" },
      { "<leader>R", group = "重构：提取" },

      { "g", group = "g 前缀 —— 跳转、转换、文件" },
      -- Neovim 内置注释（descriptions 是英文的 "Toggle comment*"，这里覆盖成中文）
      { "gc", desc = "注释/取消注释（可视、可配 motion）" },
      { "gcc", desc = "注释/取消注释当前行" },
      { "ge", desc = "上一个单词末尾" },
      { "gE", desc = "上一个 WORD 末尾" },
      { "gf", desc = "打开光标下文件" },
      { "gF", desc = "打开文件并跳到指定行" },
      { "gh", desc = "悬停文档（LSP）" },
      { "gg", desc = "跳到文件开头" },
      { "g;", desc = "上一个修改位置" },
      { "g,", desc = "下一个修改位置" },
      { "gt", desc = "下一个标签页" },
      { "gT", desc = "上一个标签页" },
      { "gv", desc = "重新选择上次可视区域" },
      { "gu", desc = "小写转换（配合 motion）" },
      { "gU", desc = "大写转换（配合 motion）" },
      { "gA", desc = "跳转到父类/接口实现（Java）" },
      { "gr", group = "LSP：引用 / 重命名 / 代码操作（内置）" },
      -- gr* 是 Neovim 0.12 内置的 LSP 键（本配置故意不覆盖 gr 前缀），
      -- 内置 desc 是英文（vim.lsp.buf.references() 之类），这里覆盖成中文，弹窗才读得懂。
      { "grr", desc = "查找引用（LSP）" },
      { "grn", desc = "重命名符号（LSP）" },
      { "gra", desc = "代码操作（LSP）" },
      { "gri", desc = "跳转到实现（LSP）" },
      { "grt", desc = "跳转到类型定义（LSP）" },
      { "g~", desc = "切换大小写（配合 motion）" },
      { "gq", desc = "格式化选中文本" },
      { "gw", desc = "格式化（光标不动）" },
      { "gn", desc = "向前搜索并选中匹配" },
      { "gN", desc = "向后搜索并选中匹配" },
      { "g0", desc = "跳到行首（忽略折行）" },
      { "g^", desc = "跳到行首非空（忽略折行）" },
      { "gm", desc = "跳到行中间" },
      { "g$", desc = "跳到行尾（忽略折行）" },
      { "g_", desc = "跳到行尾非空字符" },
      { "gj", desc = "向下（忽略折行）" },
      { "gk", desc = "向上（忽略折行）" },
      { "gx", desc = "用系统程序打开文件/链接" },
      { "g%", desc = "跳转到行内匹配" },
      { "gI", desc = "在行首插入" },
      { "gD", desc = "跳到局部定义" },
      { "g*", desc = "向后搜索光标单词" },
      { "g#", desc = "向前搜索光标单词" },
      { "g]", desc = "跳转到标签定义" },
      { "g<", desc = "查看上次命令输出" },
      { "g8", desc = "显示 UTF-8 编码字节" },
      { "gd", desc = "跳转到定义（LSP）" },
      { "gi", desc = "跳转到实现（LSP）" },
      { "gR", desc = "跳转到类型定义（LSP）" },
      { "gO", desc = "本文档符号列表（LSP）" },

      -- （原顶层 t / tt / th / tv 条目已删：真实键位是 <leader>tt/th/tv，顶层 t 不触发弹窗）

      { "z", group = "z 前缀 —— 折叠/滚动" },
      { "za", desc = "切换折叠" },
      { "zA", desc = "递归切换折叠" },
      { "zc", desc = "关闭折叠" },
      { "zC", desc = "递归关闭折叠" },
      { "zo", desc = "打开折叠" },
      { "zO", desc = "递归打开折叠" },
      { "zm", desc = "折叠一层" },
      { "zM", desc = "关闭所有折叠" },
      { "zr", desc = "展开一层" },
      { "zR", desc = "展开所有折叠" },
      { "zd", desc = "删除折叠" },
      { "zD", desc = "递归删除折叠" },
      { "ze", desc = "滚动到光标右侧" },
      { "zs", desc = "滚动到光标左侧" },
      { "zz", desc = "滚动使光标居中" },
      { "zt", desc = "滚动使光标在顶部" },
      { "zb", desc = "滚动使光标在底部" },
      { "z.", desc = "居中光标（重绘）" },
      { "zi", desc = "切换折叠开关" },
      { "zv", desc = "显示光标所在的折叠" },
      { "zx", desc = "重新计算折叠（撤销手动折叠）" },
      { "zE", desc = "删除文件内所有折叠" },
      { "z<CR>", desc = "滚屏使光标在顶部（重绘）" },
      { "z-", desc = "滚屏使光标在底部（重绘）" },
      { "z=", desc = "拼写建议" },
      { "zg", desc = "将单词加入拼写词典" },
      { "zw", desc = "将单词标记为拼写错误" },
      { "zug", desc = "撤销单词拼写标记" },
      { "zuw", desc = "撤销单词拼写错误" },
      { "zh", desc = "向左滚动" },
      { "zl", desc = "向右滚动" },
      { "zH", desc = "向左滚动半屏" },
      { "zL", desc = "向右滚动半屏" },

      { "[", group = "[ 前缀 —— 上一个" },
      { "[d", desc = "上一个诊断" },
      { "[ ", desc = "在上一行前加空行" },

      { "]", group = "] 前缀 —— 下一个" },
      { "]d", desc = "下一个诊断" },
      { "] ", desc = "在下一行后加空行" },

      -- motions（按 d/y/c/gU/gu 等操作符后出现的动作键）
      { "w", desc = "下一个单词开头", mode = "no" },
      { "b", desc = "上一个单词开头", mode = "no" },
      { "e", desc = "下一个单词末尾", mode = "no" },
      { "W", desc = "下一个 WORD 开头", mode = "no" },
      { "B", desc = "上一个 WORD 开头", mode = "no" },
      { "E", desc = "下一个 WORD 末尾", mode = "no" },
      { "ge", desc = "上一个单词末尾", mode = "no" },
      { "gE", desc = "上一个 WORD 末尾", mode = "no" },
      { "0", desc = "行首", mode = "no" },
      { "$", desc = "行尾", mode = "no" },
      { "^", desc = "行首非空白字符", mode = "no" },
      { "gg", desc = "第一行", mode = "no" },
      { "G", desc = "最后一行", mode = "no" },
      { "%", desc = "匹配括号", mode = "no" },
      { "h", desc = "左", mode = "no" },
      { "j", desc = "下", mode = "no" },
      { "k", desc = "上", mode = "no" },
      { "l", desc = "右", mode = "no" },
      { "/", desc = "向前搜索", mode = "no" },
      { "?", desc = "向后搜索", mode = "no" },
      { ";", desc = "重复上次 f/t", mode = "no" },
      { ",", desc = "往回重复上次 f/t", mode = "no" },
      { "{", desc = "上一个空行", mode = "no" },
      { "}", desc = "下一个空行", mode = "no" },
      { "f", desc = "跳到指定字符", mode = "no" },
      { "F", desc = "往回跳到指定字符", mode = "no" },
      { "t", desc = "跳到指定字符前", mode = "no" },
      { "T", desc = "往回跳到指定字符前", mode = "no" },

      -- text objects（d/y/c 后可选的文本对象）
      { "a", group = "包围（含空白）", mode = "xo" },
      { "i", group = "内部（不含空白）", mode = "xo" },

      -- <C-w> 窗口操作
      { "<C-w>", group = "窗口操作" },
      { "<C-w>s", desc = "水平切分窗口" },
      { "<C-w>v", desc = "垂直切分窗口" },
      { "<C-w>q", desc = "关闭窗口" },
      { "<C-w>o", desc = "只保留当前窗口" },
      { "<C-w>h", desc = "切换到左窗口" },
      { "<C-w>j", desc = "切换到下窗口" },
      { "<C-w>k", desc = "切换到上窗口" },
      { "<C-w>l", desc = "切换到右窗口" },
      { "<C-w>w", desc = "循环切换窗口" },
      { "<C-w>x", desc = "交换当前窗口和下一个" },
      { "<C-w>=", desc = "所有窗口等高/等宽" },
      { "<C-w>_", desc = "最大化窗口高度" },
      { "<C-w>|", desc = "最大化窗口宽度" },
      { "<C-w>+", desc = "增加窗口高度" },
      { "<C-w>-", desc = "减少窗口高度" },
      { "<C-w>>", desc = "增加窗口宽度" },
      { "<C-w><", desc = "减少窗口宽度" },
      { "<C-w>T", desc = "移到新标签页" },
      { "<C-w>H", desc = "窗口移到最左" },
      { "<C-w>J", desc = "窗口移到最下" },
      { "<C-w>K", desc = "窗口移到最上" },
      { "<C-w>L", desc = "窗口移到最右" },

      -- 其他导航（H/L 已被 bufferline 覆盖为切换缓冲区）
      { "M", desc = "光标到窗口中间行", mode = "n" },
    },
  },
}
