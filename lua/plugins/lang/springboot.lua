-- ============================================
-- Spring Boot 开发辅助：springboot-nvim
-- ============================================
-- 提供三件 IDEA 里很顺手、但 jdtls 本身不给的能力：
--   1. 保存 .java 后增量编译 → 配合 spring-boot-devtools 自动重启应用
--   2. Class / Interface / Enum / Record 生成 UI（省样板代码）
--   3. :SpringBootNewProject 走 start.spring.io 建项目（需要 spring CLI）
--
-- 不负责"运行 Spring Boot"：那在 lang/java.lua 的 <leader>sr，
-- 走 toggleterm + 自动挑 mvnw/gradlew，比插件自带的 split|terminal 更可控。
--
-- ⚠ 注意本文件的返回结构：必须是 **spec 列表** `return { { ... } }`，
--   因为 plugins/lang/init.lua 用 ipairs 遍历每个语言模块的返回值再
--   table.insert 汇总。写成扁平的 `return { "插件名", ft = ... }` 的话，
--   ipairs 只会取到数组部分的字符串 "elmcgill/springboot-nvim"，
--   lazy 把它当成最简 spec —— 结果插件能装上，但 ft / keys / config 全丢，
--   表现为快捷键和 :SpringBootNewProject 都不存在。
-- ============================================

return {
  {
    "elmcgill/springboot-nvim",
    ft = { "java" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "mfussenegger/nvim-jdtls",
    },

    -- 放在 keys 里而不是在 config 里 map：这样在非 java 文件也能按
    -- <leader>sp 建项目，lazy 会在按下时才加载插件
    keys = {
      { "<leader>sp", "<cmd>SpringBootNewProject<cr>", desc = "Spring Initializr: 新建项目" },
      { "<leader>Gc", function() require("springboot-nvim").generate_class() end, desc = "生成: Java Class" },
      { "<leader>Gi", function() require("springboot-nvim").generate_interface() end, desc = "生成: Java Interface" },
      { "<leader>Ge", function() require("springboot-nvim").generate_enum() end, desc = "生成: Java Enum" },
      { "<leader>Gr", function() require("springboot-nvim").generate_record() end, desc = "生成: Java Record" },
    },

    config = function()
      local springboot = require("springboot-nvim")
      springboot.setup({})

      -- 插件的 setup 用 vimscript 无条件注册了
      --   augroup JavaAutoCommands | autocmd BufWritePost *.java incremental_compile()
      -- 问题：对没有 jdtls 附加的裸 .java 文件（比如临时写的 Hello.java），
      -- jdtls.compile 会报错刷屏。这里用同名 augroup + clear 换成带守卫的版本。
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
      -- 插件另一个 augroup JavaPackageDetails（BufReadPost 自动补 package 声明）
      -- 保持原样，不动它。
    end,
  },
}
