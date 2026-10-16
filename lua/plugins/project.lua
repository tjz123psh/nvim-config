-- 项目管理：project.nvim

return {
  "ahmedkhalf/project.nvim",
  lazy = false,
  config = function()
    require("project_nvim").setup({
      detection_methods = { "pattern", "lsp" },
      patterns = {
        ".git",
        "_darcs",
        ".hg",
        ".bzr",
        ".svn",
        "Makefile",
        "CMakeLists.txt",
        "package.json",
        "go.mod",
        "Cargo.toml",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
      },
      manual_mode = false,
    })
    require("core.projects").patch()
  end,
}
