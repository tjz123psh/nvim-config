-- ============================================
-- 语法高亮引擎：nvim-treesitter
-- Treesitter 比传统正则高亮更精确，
-- 能理解代码结构，支持语义级高亮
-- ============================================

return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate", -- 安装后自动更新解析器
  lazy = false, -- 新版 nvim-treesitter 不支持 lazy-loading
  -- 2026-09-25 审查（§29.2.2 P3）：lazy=false 下 cmd 桩永不生效（插件启动即加载），
  -- 命令由插件自带的 plugin/nvim-treesitter.lua 注册，这里删掉死桩。

  opts = {
    install_dir = vim.fn.stdpath("data") .. "/site",

    -- 确保安装的解析器（对应你常用的语言）
    ensure_installed = {
      "bash",
      "c",
      "cpp",
      "css",
      "diff",
      "go",
      "html",
      "java",
      "javascript",
      "json",
      "lua",
      "markdown",
      "markdown_inline",
      "query",
      "regex",
      "rust",
      -- 前端（2026-09-24 补）：typescript 覆盖 .ts，tsx 覆盖 .tsx；vue/svelte/scss 同名文件类型。
      -- tsx 依赖 ecma/jsx/typescript，vue/svelte 依赖 html_tags，scss 依赖 css——安装器会自动带上依赖。
      "scss",
      "svelte",
      "tsx",
      "typescript",
      "vue",
      "vim",
      "vimdoc",
      "yaml",
    },

    highlight_filetypes = {
      "bash",
      "c",
      "cpp",
      "css",
      "go",
      "html",
      "java",
      "javascript",
      "json",
      "jsonc",
      "lua",
      "markdown",
      "markdown.mdx",
      "rust",
      "sh",
      "scss",
      "svelte",
      "typescript",
      "typescriptreact", -- .tsx 的 filetype；nvim-treesitter 的 plugin/filetypes.lua 已注册到 tsx 解析器
      "vim",
      "vue",
      "yaml",
      "yaml.docker-compose",
      "yaml.gitlab",
      "yaml.helm-values",
    },

    indent_filetypes = {
      c = true,
      cpp = true,
      go = true,
      java = true,
      lua = true,
      rust = true,
      vim = true,
    },
  },

  config = function(_, opts)
    local ts = require("nvim-treesitter")

    ts.setup({ install_dir = opts.install_dir })

    -- treesitter 与 mason 都是启动插件，加载顺序不固定；安装解析器前补齐 Mason CLI 路径。
    local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
    local tree_sitter = mason_bin .. "/tree-sitter"
    if vim.fn.executable("tree-sitter") ~= 1 and vim.fn.executable(tree_sitter) == 1 then
      vim.env.PATH = mason_bin .. ":" .. (vim.env.PATH or "")
    end

    local ok_installed, installed = pcall(ts.get_installed, "parsers")
    if ok_installed then
      local seen = {}
      for _, lang in ipairs(installed) do
        seen[lang] = true
      end

      local missing = {}
      for _, lang in ipairs(opts.ensure_installed or {}) do
        if not seen[lang] then
          table.insert(missing, lang)
        end
      end

      -- 缺失解析器就自动下载，但网络不可用（本机 GitHub 需走 127.0.0.1:7890 的代理，
      -- 代理没开时直连会超时）会在**每次启动**都重试并刷一屏红色错误。
      -- 因此把尝试频率限制到 6 小时一次，其余情况只留一条 INFO 提示。
      local stamp = vim.fn.stdpath("state") .. "/treesitter-install-stamp"
      local function recently_attempted()
        local f = io.open(stamp, "r")
        if not f then
          return false
        end
        local t = tonumber(f:read("*l")) or 0
        f:close()
        return os.time() - t < 6 * 60 * 60
      end
      local function mark_attempt()
        local f = io.open(stamp, "w")
        if f then
          f:write(tostring(os.time()))
          f:close()
        end
      end

      if #missing > 0 then
        if vim.fn.executable("tree-sitter") ~= 1 then
          vim.notify(
            "Treesitter 解析器缺失，且未找到 tree-sitter CLI；请先安装 tree-sitter-cli",
            vim.log.levels.WARN
          )
        elseif recently_attempted() then
          vim.notify(
            ("Treesitter 解析器缺失：%s（6 小时内已尝试下载，未重复联网；可用 :TSInstall %s 手动安装）"):format(
              table.concat(missing, ", "),
              table.concat(missing, " ")
            ),
            vim.log.levels.INFO
          )
        else
          mark_attempt()
          ts.install(missing)
        end
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
      pattern = opts.highlight_filetypes,
      callback = function(args)
        local ok = pcall(vim.treesitter.start, args.buf)
        if ok and opts.indent_filetypes[vim.bo[args.buf].filetype] then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
