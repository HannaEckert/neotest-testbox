local lib = require("neotest.lib")

local M = {}

function M.is_test_file(file_path)
	return vim.endswith(file_path, "Test.cfc") or vim.endswith(file_path, "Test.bx")
end

function M.get_strategy_config(strategy, python, python_script, args)
	local config = {
		dap = nil,
	}
	if config[strategy] then
		return config[strategy]()
	end
end

M.treesitter_query = [[
	;; describe blocks
	(expression_statement
	  (call_expression
		function: (identifier) @func_name (#match? @func_name "^describe$")
		arguments: (arguments
			[(assignment_expression (string (string_fragment) @namespace.name))
			(string (string_fragment) @namespace.name )])
		)) @namespace.definition

	;; it blocks
	(expression_statement
	  (call_expression
		function: (identifier) @func_name (#match? @func_name "^it$")
		arguments: (arguments
			[(assignment_expression (string (string_fragment) @test.name ))
			(string (string_fragment) @test.name )])
		)) @test.definition
]]

function M.get_script_path()
	local paths = vim.api.nvim_get_runtime_file("run_tests.lua", true)
	for _, path in ipairs(paths) do
		if vim.endswith(path, ("neotest-testbox%srun_tests.lua"):format(lib.files.sep)) then
			return path
		end
	end
end

return M
