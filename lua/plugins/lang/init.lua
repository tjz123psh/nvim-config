-- =============================================================================
-- 语言专用配置聚合入口
-- =============================================================================
-- init.lua 被 lazy.nvim 自动加载，import 各语言的配置文件
-- =============================================================================

local specs = {}

-- 单个语言配置加载失败必须出声：旧实现只有 pcall 没有分支，
-- 整门语言的 spec（插件、LSP、键位）会静默消失，只剩"某功能就是不生效"。
local function load_lang(name)
  local ok, mod = pcall(require, "plugins.lang." .. name)
  if not ok then
    vim.notify(
      ("语言配置 plugins/lang/%s.lua 加载失败，该语言相关插件/键位将不可用：%s"):format(
        name,
        mod
      ),
      vim.log.levels.ERROR
    )
    return {}
  end
  return mod
end

for _, name in ipairs({ "cpp", "java", "go", "springboot", "rust" }) do
  for _, spec in ipairs(load_lang(name)) do
    table.insert(specs, spec)
  end
end

return specs
