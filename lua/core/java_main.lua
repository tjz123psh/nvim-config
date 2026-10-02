-- ============================================
-- Java 主类扫描 / Spring Boot 运行参数解析（纯逻辑，无 UI）
-- ============================================
-- 给 plugins/lang/java.lua 的 <leader>sr 用：扫出项目里所有带 main 的类（多个时由调用方
-- 弹选择框，只有一个就直接启动），并算出「怎么把选中的主类交给构建工具」。
--
-- 纯逻辑、零 UI、不依赖 jdtls ⇒ 可以 headless 直接断言（见 nvim-troubleshooting §35）。
-- 放 core/ 而不是 plugins/：core/lazy.lua 是 { import = "plugins" }，lazy 会把 plugins/
-- 下每个 .lua 当插件 spec 加载（spring_wizard 同理，纯模块只能放 core/）。
-- ============================================

local M = {}

-- main 入口签名 public static void main(。实测用户项目里有
-- ...main(String[] args){（) 与 { 之间无空格）这种写法，所以只认到左括号；
-- 顺序颠倒的 static public 也一并认。
local MAIN_PATTERNS = {
  "public%s+static%s+void%s+main%s*%(",
  "static%s+public%s+void%s+main%s*%(",
}

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then
    return nil
  end
  return table.concat(lines, "\n")
end

--- 这段 Java 源码里有没有 main 入口
function M.has_main(text)
  for _, pat in ipairs(MAIN_PATTERNS) do
    if text:find(pat) then
      return true
    end
  end
  return false
end

--- 扫项目里的主类（只扫 src/main/java：测试源集里的 main 不该出现在启动列表里）
--- 返回按 FQCN 排序的 { { fqcn, simple, pkg }, ... }；顺序稳定 ⇒ 终端槽分配也稳定。
--- Kotlin 暂不扫：顶层 fun main 编译成 XxxKt，FQCN 和文件名不一致，猜错会让 spring-boot:run 找不到类。
function M.scan(root)
  local out = {}
  for _, file in ipairs(vim.fn.globpath(root, "src/main/java/**/*.java", true, true)) do
    local text = read_file(file)
    if text and M.has_main(text) then
      local pkg = text:match("package%s+([%w_%.]+)%s*;") or ""
      local simple = vim.fn.fnamemodify(file, ":t:r")
      out[#out + 1] = {
        fqcn = pkg ~= "" and (pkg .. "." .. simple) or simple,
        simple = simple,
        pkg = pkg,
      }
    end
  end
  table.sort(out, function(a, b)
    return a.fqcn < b.fqcn
  end)
  return out
end

--- spring-boot-maven-plugin 在 pom 里的那一段（artifactId 起、到 </plugin> 止）
local function plugin_block(pom)
  local i = pom:find("<artifactId>%s*spring%-boot%-maven%-plugin%s*</artifactId>")
  if not i then
    return nil
  end
  return pom:sub(i, pom:find("</plugin>", i, true) or #pom)
end

--- 主类能不能从命令行指定（2026-10-02 用一次性 Boot 4.0.8 工程实测）：
---   ① pom 写 <mainClass>${main.class}</mainClass> ⇒ -Dmain.class=X 生效（feed-java 就是这个形态）
---   ② pom 不写 mainClass ⇒ 父 pom（spring-boot-starter-parent）的 pluginManagement 里是
---      <mainClass>${spring-boot.run.main-class}</mainClass> ⇒ -Dspring-boot.run.main-class=X 生效
---   ③ pom 把 mainClass 写成字面量 ⇒ 两个参数都不生效（显式 <configuration> 盖过 -D），只能改 pom
--- ⚠ 别被 4.x 的插件描述符骗了：spring-boot-maven-plugin 4.0.8 的 plugin.xml 里一个 <property>
---   标签都没有（spring-boot.run.* 只出现在参数说明文字里），属性改由 mojo 的 configuration
---   默认值表达式接出来：<mainClass implementation="java.lang.String">${spring-boot.run.main-class}
---   </mainClass>（plugin.xml:1581），父 pom 的 pluginManagement 也写着同一句 —— 两处一致，
---   所以 ② 实测照样生效。
--- 返回 { flag = 属性名 } 或 { pinned = 写死的类名, reason = 说明 }
function M.main_flag(root)
  local pom = read_file(root .. "/pom.xml")
  if not pom then
    return { reason = "读不到 pom.xml" }
  end
  local block = plugin_block(pom)
  local value = block and block:match("<mainClass>%s*([^<]-)%s*</mainClass>")
  if value and value ~= "" then
    local prop = value:match("^%${([%w%._%-]+)}$")
    if prop then
      return { flag = prop }
    end
    return { pinned = value, reason = "pom 里的 <mainClass> 写死为 " .. value .. "，命令行改不了" }
  end
  -- 项目 pom 没写 ⇒ 走父 pom 接出来的标准属性（① ③ 都不成立时唯一还能用的）
  return { flag = "spring-boot.run.main-class" }
end

--- pom 里某个属性的默认值（用于在选择框里标出「不带参数时跑哪个」）
function M.default_main(root, prop)
  if not prop then
    return nil
  end
  local pom = read_file(root .. "/pom.xml")
  if not pom then
    return nil
  end
  local name = vim.pesc(prop)
  return pom:match("<" .. name .. ">%s*([%w%._%-]+)%s*</" .. name .. ">")
end

--- 组装 spring-boot:run / bootRun 的主类参数
--- 返回 { args = " -Dmain.class=x.y.Z", note = "给用户看的一句说明或 nil" }
--- note 只是提示、不阻断启动：pom 写死主类、Gradle 多入口这些情况让构建工具自己报错更可信。
function M.run_args(root, kind, fqcn, multi)
  if kind == "gradle" then
    -- Gradle 没有等价参数：bootRun 的 mainClass 只能写在 build.gradle(.kts) 里
    if multi then
      return {
        args = "",
        note = "Gradle 的 bootRun 主类只能由 build.gradle(.kts) 指定（没有通用命令行参数）"
          .. "；多入口项目会在终端报 Unable to find a single main class，请在 build 脚本里给 bootRun 设 mainClass",
      }
    end
    return { args = "" }
  end
  local pom = read_file(root .. "/pom.xml")
  if not pom then
    return { args = "", note = "读不到 " .. root .. "/pom.xml，将按构建工具的默认主类启动" }
  end
  if not pom:find("spring%-boot%-maven%-plugin") then
    return {
      args = "",
      note = "pom 里没看到 spring-boot-maven-plugin（声明在父 pom 里的话忽略这句）"
        .. "；<leader>sr 只适用于 Spring Boot 项目",
    }
  end
  local info = M.main_flag(root)
  if not info.flag then
    return {
      args = "",
      note = (info.reason or "无法指定主类")
        .. "；要能选主类就把 pom 改成 <mainClass>${main.class}</mainClass> 并在 properties 里给 main.class 一个默认值",
    }
  end
  return { args = " -D" .. info.flag .. "=" .. fqcn }
end

return M
