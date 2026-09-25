-- ============================================
-- snacks.nvim：全机唯一的选择器 / 输入框提供者
-- ============================================
-- 为什么引入：旧的 dressing+nui+telescope 做不出「图标列 / 分组 / 富文本着色 / 主题化排版」
-- （三者已于 2026-09-24 删除）。snacks.picker 支持 text-node 数组、原生多选与预览，一次做到位。
-- ⚠ 除 picker/input 外全部显式关闭：notifier 会顶掉 noice、dashboard 顶掉 alpha、terminal 顶掉 toggleterm。
-- ============================================
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,

    -- picker 皮肤：默认 soft（细灰边 + 背景变暗，接近 fzf-lua 的紧凑观感）；
    -- 想回到向导那套洋红： :PickerSkin pink（立刻生效，无需重启）
    config = function(_, opts)
      -- 上下选择：在 snacks **默认键表**上追加 <C-j>/<C-k>（Telescope 时代的习惯）与 <C-n>/<C-p>。
      -- ⚠ 坑：snacks 对 keys 是**整体替换**语义 —— 直接写 win.input.keys 会把默认的
      --   <CR> 确认、<Tab> 多选、<Esc> 取消一起干掉（实测：向导按 CR 不再确认、picker 关不掉）。
      --   所以必须从 defaults 拷贝再 merge；而且要放在 config() 里（spec 解析期 snacks 还不在 rtp）。
      do
        local dwin = require("snacks.picker.config.defaults").defaults.win
        local nav = {
          -- 一次 Esc 直接关掉：默认的 <Esc> 只在普通模式生效（插入模式下先退回普通模式），
          -- 实测要按两次；这里补上 i 模式
          ["<Esc>"] = { "cancel", mode = { "i", "n" } },
          ["<C-j>"] = { "list_down", mode = { "i", "n" } },
          ["<C-k>"] = { "list_up", mode = { "i", "n" } },
          ["<C-n>"] = { "list_down", mode = { "i", "n" } },
          ["<C-p>"] = { "list_up", mode = { "i", "n" } },
        }
        opts.picker.win = {
          input = { keys = vim.tbl_extend("force", vim.deepcopy(dwin.input.keys), nav) },
          list = {
            keys = vim.tbl_extend("force", vim.deepcopy(dwin.list.keys), {
              ["<C-j>"] = "list_down",
              ["<C-k>"] = "list_up",
            }),
          },
        }
      end

      require("snacks").setup(opts)

      local function apply_skin()
        if (vim.g.picker_skin or "soft") == "pink" then
          return
        end
        -- 边框 / 标题：细灰蓝边 + 主题蓝标题（不再是洋红，也不再是灰标题）
        -- ⚠ 四条边/标题的组名各不相同（实测）：box 的边框走 SnacksPickerBoxBorder、
        --   box 的标题走 **SnacksTitle**（不是 SnacksPickerTitle！）、list 走 SnacksPickerListBorder、
        --   input 走 SnacksPickerInputBorder。少设一个就会露出 catppuccin 默认的红标题。
        vim.api.nvim_set_hl(0, "SnacksTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "SnacksPickerTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "SnacksPickerInputTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "SnacksPickerBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "SnacksPickerBoxBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "SnacksPickerListBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "SnacksPickerInputBorder", { fg = "#7f849c" })
        -- 输入框的 ">" 提示符：跟标题同一支蓝色，别用默认的绿
        vim.api.nvim_set_hl(0, "SnacksPickerPrompt", { fg = "#89b4fa", bold = true })
        -- ★ 所有"通用浮窗"的边框/标题也统一进来（2026-09-25 视觉审查：全机两套边框色）：
        --   noice 命令行、LSP 悬浮/签名、诊断浮标、blink 文档窗、which-key、dap-ui 默认
        --   link 到 catppuccin 的蓝边 FloatBorder 与灰斜体 FloatTitle，与 picker/速查的
        --   "灰边 + 蓝粗标题" 并存。写这两个全局组一次就全对齐。
        vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "FloatTitle", { fg = "#89b4fa", bold = true })
        -- ★ 底色也统一：主题开了 transparent_background ⇒ NormalFloat 无底，
        --   which-key / LSP 悬浮 / 诊断浮标是"洞"，而 picker 卡片是实底 base。
        --   给 NormalFloat 补 base，所有浮窗一起变成同色卡片（与 picker 一致）。
        vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#1e1e2e" })
        vim.api.nvim_set_hl(0, "SnacksInputBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "SnacksInputTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "SnacksInputNormal", { bg = "#1e1e2e" })
        vim.api.nvim_set_hl(0, "NoiceCmdlinePopup", { bg = "#1e1e2e" })
        vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = "#7f849c" })
        -- ★ 面板底色：这两个组默认为空 → 浮窗是透明的，透出终端黑底（看着像黑洞）。
        --   给一个 catppuccin base 色的实底，才是"卡片"而不是"洞"。
        vim.api.nvim_set_hl(0, "SnacksPickerBox", { bg = "#1e1e2e" })
        vim.api.nvim_set_hl(0, "SnacksPickerList", { bg = "#1e1e2e" })
        -- 输入框那两行原本是 catppuccin 的 mantle(#181825)，比列表面板深一档 ⇒ 一张卡片上
        -- 出现两种底色。统一成 base，整卡同色（向导卡片、所有 picker 一起变）。
        vim.api.nvim_set_hl(0, "SnacksPicker", { bg = "#1e1e2e" })
        vim.api.nvim_set_hl(0, "SnacksPickerInput", { bg = "#1e1e2e" })
        -- ★ 选中行：必须给底色，否则完全看不出选中哪条。
        --   注意 snacks 的 list 用的是 **SnacksPickerListCursorLine**（link 到 Visual），
        --   只设 SnacksPickerCursorLine 是白设（2026-09-24 实测），两个一起设。
        vim.api.nvim_set_hl(0, "SnacksPickerCursorLine", { bg = "#313244", bold = true })
        vim.api.nvim_set_hl(0, "SnacksPickerListCursorLine", { bg = "#313244", bold = true })
        vim.api.nvim_set_hl(0, "SnacksPickerInputCursorLine", { bg = "#313244", bold = true })
        -- 匹配到的关键字用暖黄强调
        vim.api.nvim_set_hl(0, "SnacksPickerMatch", { fg = "#f9e2af", bold = true })
        -- ★ 列表行的层次感（fzf-lua 观感）：主体亮、次要信息灰。
        --   SnacksPickerFile 默认为空组（行内容是 Normal 色），Dir 只 link 到 NonText；
        --   项目列表的自定义行靠这两个组区分「项目名」与「父目录」。
        vim.api.nvim_set_hl(0, "SnacksPickerFile", { fg = "#cdd6f4" }) -- 项目名 / 文件名：主题正文色
        vim.api.nvim_set_hl(0, "SnacksPickerDirectory", { fg = "#cdd6f4" })
        vim.api.nvim_set_hl(0, "SnacksPickerDir", { fg = "#7f849c" }) -- 父目录 / 路径：灰
        vim.api.nvim_set_hl(0, "SnacksPickerDelim", { fg = "#585b70" })
        vim.api.nvim_set_hl(0, "SnacksPickerTotals", { fg = "#7f849c" }) -- 计数别抢眼
        -- ★ 速查面板（core/cheatsheet.lua，<leader>hk）也吃这套色：
        --   它的默认组是 default link（边框=主题蓝、窗标题=带蓝底的 FloatTitle），
        --   非 default 地写一遍就整片截胡，观感与 picker 一致。
        vim.api.nvim_set_hl(0, "CheatSheetBg", { bg = "#1e1e2e" })
        vim.api.nvim_set_hl(0, "CheatSheetBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "CheatSheetWinTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "CheatSheetTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "CheatSheetSection", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "CheatSheetBar", { fg = "#585b70" })
        vim.api.nvim_set_hl(0, "CheatSheetSeparator", { fg = "#585b70" })
        vim.api.nvim_set_hl(0, "CheatSheetHint", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "CheatSheetKey", { fg = "#f9e2af", bold = true })
        vim.api.nvim_set_hl(0, "CheatSheetText", { fg = "#cdd6f4" })
        -- 其它 picker 的行内小标签（缓冲区编号/序号/类型）也统一到同一套灰蓝色阶
        vim.api.nvim_set_hl(0, "SnacksPickerIdx", { fg = "#6c7086" }) -- ui.select 的 "1."
        vim.api.nvim_set_hl(0, "SnacksPickerBufNr", { fg = "#6c7086" }) -- 缓冲区编号
        vim.api.nvim_set_hl(0, "SnacksPickerBufFlags", { fg = "#f9e2af" }) -- 缓冲区 flags
        vim.api.nvim_set_hl(0, "SnacksPickerSpecial", { fg = "#89b4fa" }) -- [client] 之类
        -- 项目列表里「当前所在项目」：名字用主题蓝加粗 + 行尾灰徽标
        vim.api.nvim_set_hl(0, "SnacksPickerCurrentProject", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "SnacksPickerCurrentBadge", { fg = "#6c7086" })
        -- 没有 bg 的话 backdrop 窗是透明的，变暗看不出效果
        vim.api.nvim_set_hl(0, "SnacksPickerBackdrop", { bg = "#11111b" })
        -- snacks 输入框（vim.ui.input）：同样给实底 + 细边 + 蓝标题
        vim.api.nvim_set_hl(0, "SnacksInputBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "SnacksInputTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "SnacksInputNormal", { bg = "#1e1e2e" })
        -- 向导那套 Wiz* 也跟着换，避免"有些地方还是粉的/还是黑底"。
        -- 向导自己的 define_highlights() 现在只在 pink 皮肤下写，所以 soft 时这些值就是最终值。
        vim.api.nvim_set_hl(0, "WizBg", { bg = "#1e1e2e" })
        vim.api.nvim_set_hl(0, "WizBorder", { fg = "#7f849c" })
        vim.api.nvim_set_hl(0, "WizTitle", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "WizCursorLine", { bg = "#313244", fg = "#cdd6f4", bold = true })
        vim.api.nvim_set_hl(0, "WizKey", { fg = "#cdd6f4" })
        vim.api.nvim_set_hl(0, "WizSel", { fg = "#89b4fa", bold = true })
        vim.api.nvim_set_hl(0, "WizBadge", { fg = "#f9e2af", bold = true })
        vim.api.nvim_set_hl(0, "WizHint", { fg = "#a6adc8" })
        vim.api.nvim_set_hl(0, "WizDim", { fg = "#585b70" })
        vim.api.nvim_set_hl(0, "WizMagenta", { fg = "#f9e2af", bold = true }) -- 过滤匹配词
        vim.api.nvim_set_hl(0, "WizMarker", { fg = "#89b4fa", bold = true }) -- 行首 ▸
        vim.api.nvim_set_hl(0, "WizPeach", { fg = "#fab387" })
        vim.api.nvim_set_hl(0, "WizMenuSel", { fg = "#cdd6f4", bold = true })
      end

      apply_skin()
      -- 向导（spring_wizard.lua）在启动更晚的时候还会把 SnacksPicker* 写成洋红，
      -- 所以启动后再盖一次；换配色时用 schedule 保证排在他的 define_highlights 之后
      vim.defer_fn(apply_skin, 1000)
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("PickerSkin", { clear = true }),
        callback = function()
          vim.schedule(apply_skin)
        end,
      })

      -- 注册「紧凑」预设：克隆内置 select（居中 + min_height=2 随内容变高），只改两处——
      -- min_width 40（内置 80 在 80 列终端上会连边框一起超出屏幕，实测被裁 3 列）与 height 0.4。
      -- 注意：预设的窗口**键位**等字段出现过赢过内联覆盖的情况（round 1 实测），但布局字段不是——
      -- 2026-09-24 实测 `layout = { preset = "picker_compact", layout = { width = 61 } }` 生效（53 → 61）。
      -- 结论：改预设前先按目标字段实测一次，别照搬结论。
      local layouts = require("snacks.picker.config.layouts")
      layouts.picker_compact = vim.tbl_deep_extend("force", vim.deepcopy(layouts.select), {
        hidden = { "preview" },
        -- ⚠ config 必须放在**顶层**（与 layout 同级）：picker/config/init.lua 的
        --   M.layout() 只读 resolved layout 顶层的 .config 并调用它；写进 layout.layout
        --   里会被当成 box 选项丢掉（第一次就踩了）。
        -- 高度修正：snacks 给 box 的是"含上下边框外高"，子窗按"内高"分配 ⇒
        --   input(1)+input 下边框(1)+list(内高) 比内区多 2 行：底边框被 list 盖掉、
        --   最下面 1 行漏到卡片外（实测 160x50：box h=18 / list h=16 起点 row=2，无底边框）。
        config = function(layout)
          -- list 子窗默认是「填满父框内高」，但 input(1) 还占了它自己下方的边框行(1)，
          -- 引擎没扣掉 ⇒ 内容总高 = 内高 + 2：底边框被吃掉、底下还会漏 1 行
          -- （实测 160x50：box 18 / 内高 16 / list 16 起点 2）。
          -- 这里显式给 list 一个 = 内高 − 2 的高度（ui.select 也是用同样的手法设 list 高度的）。
          local spec = layout.layout or {}
          local h = spec.height
          -- 注意：这里算的是"外高"，snacks 的 size() 会自己减边框，见下面的 inner 计算
          local outer
          if type(h) == "number" and h > 0 and h < 1 then
            outer = math.floor(vim.o.lines * h) - 2
          elseif type(h) == "number" then
            outer = h
          else
            outer = math.floor(vim.o.lines * 0.5) - 2
          end
          outer = math.max(3, outer)
          -- snacks 的 size() 还会再减掉上下边框 ⇒ 真正的内高 = outer − 2；
          -- list 再让出 input(1) + input 下边框(1) = 2 行，正好贴合不溢出。
          local inner = math.max(2, outer - 2)
          for _, child in ipairs(spec) do
            if child.win == "list" then
              child.height = math.max(2, inner - 2)
            end
          end
          return layout
        end,
        layout = {
          min_width = 40,
          max_width = 110,
          -- 宽度自适应：内置 select 的 0.5 在 160 列终端只有 78 列（49%），略小；
          -- 改成 0.55 并抬高上限（窄终端仍夹在 40 列起）。
          width = function()
            return math.max(40, math.min(110, math.floor(vim.o.columns * 0.55)))
          end,
          height = 0.4,
          min_height = 2,
          title = " {title} {live} {flags} ",
          title_pos = "center",
        },
      })

      -- ⚠ 已知良性：:checkhealth snacks 会报 "vim.ui.select is not set to Snacks.picker.select" ——
      --   因为下面这层 wrapper 让身份比较（== Snacks.picker.select）永远失败；功能完全正常
      --   （wrapper 内部调用的就是 snacks 原函数，只是先收 2 行高度）。2026-09-25 审查线②核实并登记。
      -- snacks 的 ui.select 自带一个 layout.config（按条目数算列表高度，见 select.lua:44-52），
      -- 会**覆盖**上面预设里的高度修正 ⇒ 列表填满时底边框照样被吃掉（实测 30 项：
      -- box 20 / list 18@2）。snacks 是在 UIEnter 才把 vim.ui.select 指向自己，
      -- 所以这里也挂 UIEnter（注册晚于 snacks，执行顺序在其后），在外面包一层再收 2 行。
      local wrapped_target = nil
      local function wrap_ui_select()
        local current = vim.ui.select
        -- 只包 snacks 的实现：config 阶段的立即调用时 vim.ui.select 还是 Neovim 原生，
        -- 包了也会被 snacks 在 UIEnter 时覆盖（第一次就踩了这个，白包一场）。
        if current == nil or current == wrapped_target then
          return
        end
        local info = debug.getinfo(current, "S")
        if not (info and info.short_src or ""):match("snacks") then
          return
        end
        vim.ui.select = function(items, sel_opts, on_choice)
          sel_opts = vim.deepcopy(sel_opts or {})
          local snacks = sel_opts.snacks or {}
          local prev_cfg = snacks.layout and snacks.layout.config
          sel_opts.snacks = vim.tbl_deep_extend("force", snacks, {
            layout = {
              -- ⚠ 上游 select 源自带 layout.preset = "select"（min_width 80），会盖掉全局的
              --   picker_compact ⇒ 80 列终端上框宽 80 + 边框，左右贴边/越界
              --   （2026-09-25 审查 F09，真 PTY 复现）。这里对 select 显式指定紧凑预设。
              preset = "picker_compact",
              config = function(layout)
                if prev_cfg then
                  layout = prev_cfg(layout) or layout
                end
                for _, child in ipairs(layout.layout or {}) do
                  if child.win == "list" then
                    -- ⚠ 我们的 config 会整体替换上游"按条目数收缩高度"的那个回调
                    --   （select.lua 里的 if not box.height then ... end），所以这里自己算一遍
                    --   同样的公式，否则 3 个条目也会撑满一屏（F09 的第二个根因）。
                    child.height = math.max(math.min(#items, math.floor(vim.o.lines * 0.8) - 10), 2)
                  end
                end
                return layout
              end,
            },
          })
          return current(items, sel_opts, on_choice)
        end
        wrapped_target = vim.ui.select -- 记下我们这层，避免重复包装
      end
      vim.api.nvim_create_autocmd("UIEnter", {
        group = vim.api.nvim_create_augroup("SnacksUiSelectHeightFix", { clear = true }),
        callback = wrap_ui_select,
      })
      wrap_ui_select() -- UI 已存在时（:R 重载、或启动即 did_enter）立刻生效

      vim.api.nvim_create_user_command("PickerSkin", function(cmd)
        local skin = cmd.args ~= "" and cmd.args or "soft"
        vim.g.picker_skin = skin
        if skin == "pink" then
          -- 洋红那套是**向导**定义的（core/spring_wizard.lua 的 HL_DEFS/SNACKS_HL），
          -- apply_skin() 在 pink 模式下故意早退、不再覆盖。所以要真正切到粉色，
          -- 得把向导的 setup() 再跑一遍（它幂等，命令与 ColorScheme autocmd 都会重建）。
          -- 实测：原来只调 apply_skin() ⇒ ":PickerSkin pink" 什么也没发生（软色保持）。
          pcall(function()
            require("core.spring_wizard").setup()
          end)
        else
          apply_skin()
        end
        vim.notify(
          "picker 皮肤 = " .. skin .. (skin == "soft" and "（细灰边 + 背景变暗）" or "（向导洋红）")
        )
      end, {
        nargs = "?",
        complete = function()
          return { "soft", "pink" }
        end,
        desc = "切换 picker 皮肤（soft|pink）",
      })
    end,

    opts = {
      picker = {
        enabled = true,
        -- ★ 全机统一「紧凑列表」观感（2026-09-25，用户："基本上所有的都换成这种风格"）：
        --   原来是 snacks 默认 —— >=120 列用 default（0.8 宽 + 右侧预览窗）、窄屏用 vertical。
        --   现在所有 picker（文件/内容/缓冲区/帮助/最近/ui.select/项目…）都用注册的
        --   picker_compact 预设：居中、细灰边、贴合内容的窄框、无预览窗。
        --   ⚠ 副作用：预览窗被 `hidden` 掉（<a-p> 无法再叫出来）；想要回预览给单个 picker
        --     传 `layout = { preset = "default" }` 即可。
        layout = {
          cycle = true,
          preset = "picker_compact",
        },
        -- 键位在下面的 config() 里注入（spec 解析期 snacks 还没进 rtp，require 会失败）
        -- ★ 接管 vim.ui.select：全机只留 snacks 一个选择器（原来留给 dressing，
        --   两套 UI 会互相打架）。注意 snacks 的 select 用 source="select"，
        --   同 source 会互相 dedupe ⇒ 向导的两个 picker 已改用 "spring-wizard*" 源。
        ui_select = true,
      },

      -- 与现有插件冲突的，全部关掉
      notifier = { enabled = false },
      dashboard = { enabled = false },
      terminal = { enabled = false },
      -- ★ 接管 vim.ui.input（重命名、向导的文本步骤等）。原来关着是为了让给 dressing，
      --   现在 dressing 整个撤掉，输入也必须由 snacks 提供，否则只剩命令行输入。
      input = { enabled = true },
      scroll = { enabled = false },
      -- 注：以前这里还有 zoom/util/list/job/git_linker/git_hosting 六个键 —— 2026-09-25 审查
      -- （§29.2.2）逐个对照已装 snacks 源码：它们**都不是模块**（真名是 zen；util/list/job 是
      -- 命名空间；git_linker/git_hosting 不存在），写在这里是纯噪音，已删除。
      zen = { enabled = false },
      toggle = { enabled = false },
      bigfile = { enabled = false },
      quickfile = { enabled = false },
      scratch = { enabled = false },
      scope = { enabled = false },
      image = { enabled = false },
      debug = { enabled = false },
      profiler = { enabled = false },
      git = { enabled = false },
      rename = { enabled = false },
      bufdelete = { enabled = false },
      explorer = { enabled = false },
    },
  },
}
