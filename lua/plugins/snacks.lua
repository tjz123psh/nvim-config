-- ============================================
-- snacks.nvim：全机唯一的选择器 / 输入框提供者
-- ============================================
-- 统一提供选择器和输入框；通知、欢迎页、终端与文件树保留各自插件。
-- dressing / telescope 已移除；nui 仍是 Noice 和 neo-tree 的依赖。
-- 共享配色在 core/ui.lua，本文件只管理 Snacks 行为与布局。
-- ============================================
-- 输入类浮窗的统一尺寸/位置（与 plugins/noice.lua 共用，见该模块注释）
local input_boxes = require("core.input_boxes")

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,

    -- picker 皮肤：默认 soft（细灰边 + 背景变暗，接近 fzf-lua 的紧凑观感）；
    -- 想回到向导那套洋红： :PickerSkin pink（立刻生效，无需重启）
    config = function(_, opts)
      -- 基于默认键表追加导航键；直接替换会丢掉确认、多选和取消。
      do
        local dwin = require("snacks.picker.config.defaults").defaults.win
        local nav = {
          -- 插入/普通模式都支持一次 Esc 关闭选择器。
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

      require("core.ui").setup()

      -- 普通选择器保留紧凑单列；项目列表可另传宽度，ui.select 按条目数收缩。
      local layouts = require("snacks.picker.config.layouts")
      layouts.picker_compact = vim.tbl_deep_extend("force", vim.deepcopy(layouts.select), {
        hidden = { "preview" },
        -- config 必须与 layout 同级；本回调只处理此单列预设，不用于 grep。
        config = function(layout)
          -- 为输入行、分隔线和边框留出空间，保留已有紧凑列表的高度策略。
          local spec = layout.layout or {}
          local h = spec.height
          local outer
          if type(h) == "number" and h > 0 and h < 1 then
            outer = math.floor(vim.o.lines * h) - 2
          elseif type(h) == "number" then
            outer = h
          else
            outer = math.floor(vim.o.lines * 0.5) - 2
          end
          outer = math.max(3, outer)
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
          width = function()
            return math.max(40, math.min(110, math.floor(vim.o.columns * 0.55)))
          end,
          height = 0.4,
          min_height = 2,
          title = " {title} {live} {flags} ",
          title_pos = "center",
        },
      })

      -- 搜内容需要预览：宽屏左右分栏，窄屏上下排列，resize 时重新计算。
      -- 必须独立构造整棵布局：deep_extend 合并带数字键的旧布局会残留 input 的
      -- height=1 和重复 preview 节点，导致列表被压成一行、预览跑出主框。
      layouts.grep_split = {
        hidden = {},
        config = function(layout)
          local width = math.max(1, math.min(150, math.floor(vim.o.columns * 0.8), vim.o.columns - 4))
          local height = math.max(6, math.min(36, math.floor(vim.o.lines * 0.75), vim.o.lines - 4))
          -- 正整数尺寸是内容宽/高；外框另占两列/两行，内部隔线也需计入预算。
          local box = {
            width = width,
            height = height,
            border = "rounded",
            backdrop = false,
            title = " {title} {live} {flags} ",
            title_pos = "center",
          }
          if vim.o.columns >= 120 then
            local left = math.floor(width / 2)
            box.box = "horizontal"
            box[1] = {
              box = "vertical",
              border = "none",
              width = left,
              height = height,
              { win = "input", height = 1, border = "bottom" },
              { win = "list", height = height - 2, border = "none" },
            }
            box[2] = { win = "preview", title = " {preview} ", border = "left", width = width - left - 1 }
          else
            local list_height = math.max(2, math.floor((height - 3) / 2))
            box.box = "vertical"
            box[1] = { win = "input", height = 1, border = "bottom" }
            box[2] = { win = "list", height = list_height, border = "none" }
            box[3] = {
              win = "preview",
              title = " {preview} ",
              border = "top",
              height = height - list_height - 3,
            }
          end
          layout.layout = box
          return layout
        end,
      }

      -- ui.select 自带的布局会覆盖全局预设，所以在 UIEnter 接管后再包装：
      -- 显式选紧凑预设，并按条目数设置高度。包装使 health 的函数身份比较误报，
      -- 但内部仍调用原来的 Snacks 实现，不再引入第二套选择器。
      local wrapped_target = nil
      local function wrap_ui_select()
        local current = vim.ui.select
        -- 初始化时可能还是原生实现；只包装 Snacks，且不重复包装。
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
              -- 避免上游 select 的 80 列下限盖过紧凑预设。
              preset = "picker_compact",
              config = function(layout)
                if prev_cfg then
                  layout = prev_cfg(layout) or layout
                end
                for _, child in ipairs(layout.layout or {}) do
                  if child.win == "list" then
                    -- 替换上游高度回调后，这里负责按条目数收缩。
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
      wrap_ui_select() -- 已有 UI 时立即包装；完整配置重载请重启 Neovim
    end,

    opts = {
      picker = {
        enabled = true,
        -- 文件名、缓冲区、帮助等使用无预览的紧凑列表。
        layout = {
          cycle = true,
          preset = "picker_compact",
        },
        -- 搜文件内容例外：预览用于查看上下文，布局随终端宽度切换。
        sources = {
          grep = { layout = { preset = "grep_split" } },
        },
        -- 接管 vim.ui.select；向导与项目列表使用不同 source，避免同源互相关闭。
        ui_select = true,
      },

      -- 与现有插件冲突的，全部关掉
      notifier = { enabled = false },
      dashboard = { enabled = false },
      terminal = { enabled = false },
      -- 输入框与 Noice 共用尺寸策略，但 Noice 的最小宽度是加载时快照。
      input = {
        enabled = true,
        -- width 传**函数**：开窗时求值 ⇒ 跟随当前屏幕列数（input_boxes.width 见 core/input_boxes.lua）
        win = { row = input_boxes.center_row, width = input_boxes.width },
      },
      scroll = { enabled = false },
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
