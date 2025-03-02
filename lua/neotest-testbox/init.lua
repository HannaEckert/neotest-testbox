local create_adapter = require("neotest-testbox.adapter")

local TestboxNeotestAdapter = create_adapter({})

setmetatable(TestboxNeotestAdapter, {
  __call = function(_, opts)
    opts = opts or {}
    return create_adapter({ min_init = opts.min_init })
  end,
})

TestboxNeotestAdapter.setup = function(opts)
  return TestboxNeotestAdapter(opts)
end

return TestboxNeotestAdapter
