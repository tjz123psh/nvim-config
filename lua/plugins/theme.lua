-- ============================================
-- 主题配色：catppuccin
-- 目前最流行的 Neovim 主题，柔和护眼
-- 风味：mocha（最深色） / macchiato / frappe / latte（浅色）
-- ============================================

--- 当前风味：运行时切换过就用 vim.g 记着的那个，否则用下面 opts.flavour 的默认值
local function current_flavour()
  return vim.g.catppuccin_flavour or "mocha"
end

return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false, -- 立即加载（主题必须在启动时加载）
  priority = 1000, -- 高优先级，确保在其他插件之前加载

  opts = {
    -- 深色风味。运行时改了风味记在 vim.g.catppuccin_flavour（<leader>ft 用），
    -- 但那只是「当前生效值」；要持久就改这一行的默认值。
    flavour = "mocha",
    transparent_background = true, -- kitty 终端已配 background_opacity，Neovim 不设背景色即可透出桌面
    term_colors = true, -- 让终端模拟器的颜色也匹配主题

    -- 与已安装插件的配色集成（让所有插件都统一用主题色）
    integrations = {
      treesitter = true, -- 语法高亮
      native_lsp = { enabled = true }, -- LSP 语义高亮
      blink_cmp = true, -- 补全菜单 blink.cmp
      -- telescope 集成已随插件一起删除（搜索统一走 snacks picker）
      indent_blankline = { enabled = true }, -- 缩进线
      -- 注意：catppuccin 的 lualine 集成必须是 override 表；写 boolean 会让
      -- lualine.themes.catppuccin-mocha 抛错、被 statusline.lua 的 pcall 吞掉，
      -- 状态栏静默退化成 "auto"（中段变纯黑带）
      lualine = { enabled = true }, -- 状态栏
      alpha = true, -- 欢迎页
      mason = true, -- Mason UI
      neotree = true, -- 文件树
      noice = true, -- UI 美化
      dap = true, -- 调试器
      dap_ui = true, -- 调试界面
      which_key = true, -- 快捷键提示
      -- 下面三个之前漏了：snacks 是现在所有选择器的宿主（不接进来它的组只能是默认黑底），
      -- flash 是 s/S 跳转，notify 是通知卡片
      snacks = true,
      flash = true,
      notify = true,
    },
  },

  -- 换主题的选择框（2026-09-28）。放在 spec 的 keys 里注册：lazy 用 callback 挂键，
  -- 按下去才加载，不需要 core/keymaps.lua 再抄一份。
  --
  -- ⚠ 核心约束：vim.ui.select 的回调**可能是异步的**（snacks 是异步、Neovim 原生是同步）。
  --   所以「应用」必须写在 on_choice **内部**，绝不能写成：
  --     local picked; vim.ui.select(..., function(ch) picked = ch end); apply(picked)
  --   —— 异步时 select 立刻返回、picked 还是 nil，那条 apply 会拿旧值把预览顶掉，
  --   之后真正的选择再也不会生效（本地实测踩过：选 frappe 毫无反应）。
  keys = {
    {
      "<leader>ft",
      function()
        local flavours = { "mocha", "macchiato", "frappe", "latte" }
        local labels = {
          mocha = "mocha（最深，当前默认）",
          macchiato = "macchiato（次深）",
          frappe = "frappe（偏灰的暗色）",
          latte = "latte（浅色，白天用）",
        }
        local original = current_flavour()
        -- 换风味只做两件事：记下当前值 + :colorscheme。
        -- 剩下三处收尾（诊断 tag / picker 皮肤 / 向导高亮）都挂在 ColorScheme 事件上，会自己跟上。
        local function apply(f)
          vim.g.catppuccin_flavour = f
          local ok, err = pcall(vim.cmd.colorscheme, "catppuccin-" .. f)
          if ok then
            return true
          end
          vim.notify("切换主题失败：" .. tostring(err), vim.log.levels.ERROR)
          return false
        end
        vim.ui.select(flavours, {
          prompt = "主题风味（回车确认 / Esc 取消）",
          format_item = function(f)
            return (f == original and "● " or "  ") .. (labels[f] or f)
          end,
        }, function(choice)
          -- choice 为 nil = 用户取消 ⇒ 还原成原风味（这里其实什么都没改过，写出来更明确）
          if not choice or choice == original then
            if not choice then
              apply(original)
            end
            return
          end
          if apply(choice) then
            vim.notify(
              "主题 = catppuccin-"
                .. choice
                .. "（仅本次会话；要持久就改 plugins/theme.lua 的 flavour）",
              vim.log.levels.INFO
            )
          end
        end)
      end,
      desc = "切换主题风味（选择框）",
    },
  },

  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin") -- 应用主题

    -- ── 诊断 tag 不要重绘文字颜色（2026-09-26，用户报「写 Java 时代码颜色变来变去」）──
    -- Neovim 0.12 对带 `unnecessary` tag 的诊断（jdtls 的未使用字段/局部变量/import）会
    -- 额外叠一层 DiagnosticUnnecessary（runtime/lua/vim/diagnostic.lua:1832-1856），
    -- 而 runtime/colors/vim.lua:137 把它 link 到 Comment ⇒ catppuccin 下整段文字被染成
    -- 灰 #9399b2 + 斜体。jdtls 每次编辑后 300~700ms 重新发布诊断，于是「刚写下的字段/常量」
    -- 会先变灰、被用上之后又变回来 —— 这正是「写着写着颜色变来变去」里最刺眼的一层。
    -- 清空属性后：文字保持 treesitter 原色，tag 诊断仍有常规严重级别下划线（不受影响）。
    -- DiagnosticDeprecated 只有删除线、不染字色（实测 sp+strikethrough），保持原样。
    local function neutralize_unnecessary_tag()
      vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", {})
    end
    neutralize_unnecessary_tag()
    -- 手动 :colorscheme 会重建高亮组，这里补一次（ColorScheme 事件在主题高亮之后触发）
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("theme_diagnostic_tags", { clear = true }),
      callback = neutralize_unnecessary_tag,
      desc = "诊断 tag（Unnecessary）不重绘文字颜色",
    })
  end,
}
