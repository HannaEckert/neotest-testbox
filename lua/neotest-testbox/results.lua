local lib = require("neotest.lib")

---@class TestboxTestResult
---@field descriptions string[]
---@field msg? string

---@class TestboxTestResults
---@field pass TestboxTestResult[]
---@field fail TestboxTestResult[]
---@field errs TestboxTestResult[]
---@field fatal TestboxTestResult[]

---@class TestboxOutput
---@field results TestboxTestResults
---@field locations table<string, integer>

local function join_results(base_result, update)
  if not base_result or not update then
    return base_result or update
  end
  local status = (base_result.status == "failed" or update.status == "failed") and "failed"
    or "passed"
  local errors = (base_result.errors or update.errors)
      and (vim.list_extend(base_result.errors or {}, update.errors or {}))
    or nil
  return {
    status = status,
    errors = errors,
  }
end

---@param result TestboxTestResult
local function convert_testbox_result(result, status, file)
  return table.concat(vim.iter({ file, result.descriptions }):flatten():totable(), "::"),
    {
      status = status,
      short = result.msg,
      errors = result.msg and {
        {
          message = result.msg,
        },
      },
    }
end

---@param lists string[][]
local function permutations(lists, cur_i)
  cur_i = cur_i or 1
  if cur_i > #lists then
    return { {} }
  end
  local sub_results = permutations(lists, cur_i + 1)
  local result = {}
  for _, elem in pairs(lists[cur_i]) do
    for _, sub_result in pairs(sub_results) do
      local l = vim.list_extend({ elem }, sub_result)
      table.insert(result, l)
    end
  end
  return result
end
---
---@async
---@param spec neotest.RunSpec
---@param tree neotest.Tree
---@return neotest.Result[]
return function(spec, tree)
  local success, data = pcall(lib.files.read, spec.context.results_path)
  if not success then
    data = vim.json.encode({ pass = {}, fail = {}, errs = {}, fatal = {} })
  end
  ---@type TestboxOutput
  local testbox_output = vim.json.decode(data, { luanil = { object = true } })
  if not testbox_output.results then
    return {}
  end

  local testbox_results = testbox_output.results
  local locations = testbox_output.locations
  local results = {}
  for _, plen_result in pairs(testbox_results.pass) do
    local pos_id, pos_result = convert_testbox_result(plen_result, "passed", spec.context.file)
    results[pos_id] = pos_result
  end
  local file_result = { status = "passed", errors = {} }
  local failed = vim.list_extend({}, testbox_results.errs)
  vim.list_extend(failed, testbox_results.fail)

  for _, plen_result in pairs(failed) do
    local pos_id, pos_result = convert_testbox_result(plen_result, "failed", spec.context.file)
    results[pos_id] = pos_result
    file_result.status = "failed"
    vim.list_extend(file_result.errors, pos_result.errors)
  end

  results[spec.context.file] = file_result

  --- We now have all results mapped by their runtime names
  --- Need to combine using alias map

  local aliases = {}
  local file_tree = tree
  if file_tree:data().type ~= "file" then
    for parent in tree:iter_parents() do
      if parent:data().type == "file" then
        file_tree = parent
        break
      end
    end
  end
  for alias, lines in pairs(locations) do
    for _, line in pairs(lines) do
      local node = lib.positions.nearest(file_tree, line)
      local pos = node:data()
      aliases[pos.id] = aliases[pos.id] or {}
      table.insert(aliases[pos.id], alias)
    end
  end

  local function get_result_of_node(node)
    local pos = node:data()
    if not results[pos.id] then
      local namespace_aliases = {}
      for parent in node:iter_parents() do
        if parent:data().type ~= "namespace" then
          break
        end
        table.insert(namespace_aliases, 1, aliases[parent:data().id])
      end
      local namespace_permutations = permutations(namespace_aliases)
      for _, perm in ipairs(namespace_permutations) do
        for _, alias in ipairs(aliases[pos.id] or {}) do
          local alias_id = vim.iter({ pos.path, perm, alias }):flatten():join("::")

          results[pos.id] = join_results(results[pos.id], results[alias_id])
          results[alias_id] = nil
        end
      end
    end
    if not results[pos.id] then
      results[pos.id] = results[pos.path]
    end
  end

  for _, node in tree:iter_nodes() do
    if node:data().type == "test" then
      get_result_of_node(node)
    end
  end

  return results
end
