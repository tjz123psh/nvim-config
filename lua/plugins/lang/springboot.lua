-- ============================================
-- Spring Boot 支持
-- ============================================
-- JavaHello/spring-boot.nvim：application.yml/properties 的 Spring 属性补全、
-- 诊断、跳转和 Code Action，底层使用 Mason 的 vscode-spring-boot-tools。
-- elmcgill/springboot-nvim：保留原有的 Java 类生成、增量编译和项目辅助功能。
-- 两者配合现有 mfussenegger/nvim-jdtls 使用，不替换 Java 启动配置。
-- ============================================

return {
  {
    "JavaHello/spring-boot.nvim",
    -- 懒加载（原为 lazy = false，历史遗留）：lazy = false 让下面的 ft 变成死配置，
    -- 并把 nvim-jdtls / DAP 一起拖进启动期。:SpringBoot 命令由本插件 setup() 注册，
    -- 所以用 cmd 声明——启动时命令就存在，但只有真正调用时才加载插件。
    cmd = { "SpringBoot" },
    ft = { "java", "yaml", "jproperties" },
    dependencies = {
      "mfussenegger/nvim-jdtls",
    },
    opts = {},
    config = function(_, opts)
      require("core.spring_wizard").setup()
      require("spring_boot").setup(opts)
    end,
    keys = {
      {
        "<leader>sp",
        function()
          require("core.spring_wizard").create()
        end,
        desc = "Spring Boot 项目向导（可搜索选择）",
      },
      -- <leader>sP（原版向导 :SpringBootNewProject）已于 2026-09-25 按用户要求删除：
      -- 它生成的 Boot 4 版本号有 bug，自研向导（core/spring_wizard.lua）已完全覆盖该用途。
      -- 上游命令本身在 Java 缓冲区里仍可用（插件 ft=java 加载后自行注册），只是不再挂键位。
    },
  },

  {
    "elmcgill/springboot-nvim",
    ft = { "java" },
    -- 只保留它真正还在用的能力：<leader>Gc/Gi/Ge/Gr 类生成 + 保存时的增量编译。
    -- <leader>sP 与它的 cmd 桩（:SpringBootNewProject）已随"原版向导不推荐"一起移除
    -- （2026-09-25）：该向导生成的 Boot 4 版本号有 bug，自研向导已覆盖。
    dependencies = {
      "neovim/nvim-lspconfig",
      "mfussenegger/nvim-jdtls",
    },
    keys = {
      {
        "<leader>Gc",
        function()
          require("springboot-nvim").generate_class()
        end,
        desc = "生成: Java Class",
      },
      {
        "<leader>Gi",
        function()
          require("springboot-nvim").generate_interface()
        end,
        desc = "生成: Java Interface",
      },
      {
        "<leader>Ge",
        function()
          require("springboot-nvim").generate_enum()
        end,
        desc = "生成: Java Enum",
      },
      {
        "<leader>Gr",
        function()
          require("springboot-nvim").generate_record()
        end,
        desc = "生成: Java Record",
      },
    },
    config = function()
      local springboot = require("springboot-nvim")
      springboot.setup({})

      -- 原插件无条件注册增量编译；只在 jdtls 已附加时执行，避免裸 Java 文件刷错。
      local group = vim.api.nvim_create_augroup("JavaAutoCommands", { clear = true })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = "*.java",
        callback = function(ev)
          if vim.lsp.get_clients({ bufnr = ev.buf, name = "jdtls" })[1] then
            springboot.incremental_compile()
          end
        end,
      })
    end,
  },
}
