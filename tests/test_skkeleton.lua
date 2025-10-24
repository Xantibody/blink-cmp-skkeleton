--- Tests for blink-cmp-skkeleton.skkeleton module
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local skkeleton = require("blink-cmp-skkeleton.skkeleton")

local T = new_set()

-- is_enabled tests
T["is_enabled"] = new_set()

T["is_enabled"]["returns true when skkeleton is enabled"] = function()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "skkeleton#is_enabled" then
        return function()
          return 1
        end
      end
      return old_fn[k]
    end,
  })

  local result = skkeleton.is_enabled()
  expect.equality(result, true)

  vim.fn = old_fn
end

T["is_enabled"]["returns false when skkeleton is disabled"] = function()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "skkeleton#is_enabled" then
        return function()
          return 0
        end
      end
      return old_fn[k]
    end,
  })

  local result = skkeleton.is_enabled()
  expect.equality(result, false)

  vim.fn = old_fn
end

T["is_enabled"]["returns false on error"] = function()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "skkeleton#is_enabled" then
        return function()
          error("test error")
        end
      end
      return old_fn[k]
    end,
  })

  local result = skkeleton.is_enabled()
  expect.equality(result, false)

  vim.fn = old_fn
end

-- get_completion_data tests
T["get_completion_data"] = new_set()

T["get_completion_data"]["returns completion data"] = function()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "denops#request" then
        return function(plugin, method, args)
          if method == "getCompletionResult" then
            return { { "あい", { "愛", "藍" } } }
          elseif method == "getRanks" then
            return { { "愛", 100 } }
          elseif method == "getPreEdit" then
            return "▽あい"
          end
        end
      end
      return old_fn[k]
    end,
  })

  local candidates, ranks_array, pre_edit = skkeleton.get_completion_data()

  expect.equality(#candidates, 1)
  expect.equality(candidates[1][1], "あい")
  expect.equality(#ranks_array, 1)
  expect.equality(ranks_array[1][1], "愛")
  expect.equality(pre_edit, "▽あい")

  vim.fn = old_fn
end

T["get_completion_data"]["returns empty data on error"] = function()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "denops#request" then
        return function()
          error("test error")
        end
      end
      return old_fn[k]
    end,
  })

  local candidates, ranks_array, pre_edit = skkeleton.get_completion_data()

  expect.equality(type(candidates), "table")
  expect.equality(#candidates, 0)
  expect.equality(type(ranks_array), "table")
  expect.equality(#ranks_array, 0)
  expect.equality(pre_edit, "")

  vim.fn = old_fn
end

-- register_completion tests
T["register_completion"] = new_set()

T["register_completion"]["calls denops request"] = function()
  local old_fn = vim.fn
  local called = false
  local call_args = nil

  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "denops#request" then
        return function(plugin, method, args)
          if method == "completeCallback" then
            called = true
            call_args = args
          end
        end
      end
      return old_fn[k]
    end,
  })

  skkeleton.register_completion("あい", "愛", "okurinasi")

  expect.equality(called, true)
  expect.equality(call_args[1], "あい")
  expect.equality(call_args[2], "愛")
  expect.equality(call_args[3], "okurinasi")

  vim.fn = old_fn
end

return T
