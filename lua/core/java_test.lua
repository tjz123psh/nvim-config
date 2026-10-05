-- Java 终端测试选择器：只认光标所在的语法节点，绝不向上猜前一个方法。
local M = {}

local class_types = {
  class_declaration = true,
  interface_declaration = true,
  enum_declaration = true,
  record_declaration = true,
}

local function node_name(node, bufnr)
  local name = node:field("name")[1]
  return name and vim.treesitter.get_node_text(name, bufnr) or nil
end

--- 返回 Maven 使用的 类名[#方法]；调用方负责 shellescape，Gradle 将 # 换成 .。
function M.selector(bufnr, include_method)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "java")
  if not ok or not parser then
    return nil, "Java Treesitter 解析器不可用，未运行测试（可用 :TSInstall java 安装）"
  end
  local parsed, trees = pcall(parser.parse, parser)
  if not parsed or not trees or not trees[1] then
    return nil, "Java 语法解析失败，未运行测试"
  end
  local root = trees[1]:root()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  -- 行首缩进不属于方法节点；让光标在缩进上时也能选中本行声明，空行不跨界。
  col = math.max(col, (line:find("%S") or 1) - 1)
  local node = root:named_descendant_for_range(row, col, row, col)
  local method
  if include_method then
    while node and not class_types[node:type()] do
      if node:type() == "method_declaration" then
        method = node
        break
      end
      if node:type() == "constructor_declaration" or node:type() == "class_body" then
        break
      end
      node = node:parent()
    end
    if not method then
      return nil, "光标不在 Java 方法内，未运行测试"
    end
    if method:has_error() then
      return nil, "当前方法存在语法错误，无法可靠定位测试"
    end
  end

  local names = {}
  while node do
    local kind = node:type()
    if class_types[kind] then
      local parent = node:parent()
      local owner = parent and parent:type() or ""
      if
        not vim.tbl_contains(
          { "program", "class_body", "interface_body", "enum_body_declarations", "annotation_type_body" },
          owner
        )
      then
        return nil, "不支持将方法或初始化块内的局部类作为测试目标"
      end
      local name = node_name(node, bufnr)
      if not name then
        return nil, "无法识别当前 Java 类名"
      end
      table.insert(names, 1, name)
    elseif kind == "object_creation_expression" or kind == "enum_constant" then
      return nil, "不支持将匿名类作为测试目标"
    elseif #names > 0 and (kind == "method_declaration" or kind == "constructor_declaration") then
      return nil, "不支持将方法内的局部类作为测试目标"
    end
    node = node:parent()
  end
  if #names == 0 then
    -- 类测试保留在 package/import 行也可运行当前文件主类的用法。
    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t:r")
    for child in root:iter_children() do
      if class_types[child:type()] and node_name(child, bufnr) == filename then
        names = { filename }
        break
      end
    end
  end
  if #names == 0 then
    return nil, "未找到当前 Java 测试类"
  end
  local package_name
  for child in root:iter_children() do
    if child:type() == "package_declaration" then
      for part in child:iter_children() do
        if part:type() == "identifier" or part:type() == "scoped_identifier" then
          package_name = vim.treesitter.get_node_text(part, bufnr):gsub("%s+", "")
        end
      end
    end
  end
  local selector = table.concat(names, "$")
  if package_name then
    selector = package_name .. "." .. selector
  end
  if method then
    local name = node_name(method, bufnr)
    if not name then
      return nil, "无法识别当前 Java 测试方法名"
    end
    selector = selector .. "#" .. name
  end
  return selector
end

return M
