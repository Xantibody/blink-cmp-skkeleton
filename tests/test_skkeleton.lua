--- Tests for blink-cmp-skkeleton.skkeleton module
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local skkeleton = require("blink-cmp-skkeleton.skkeleton")

local T = new_set()

--- Build a vim.fn mock whose denops#request_async resolves each method via the
--- success callback. `counter` (optional) is incremented per async RPC.
--- When `responses.getPrefix` is omitted it defaults to the getPreEdit value
--- with the leading ▽ marker stripped (= the henkanFeed), so existing fixtures
--- keep working with the prefix-anchored async flow.
local function mock_async(old_fn, responses, counter)
  return setmetatable({}, {
    __index = function(_, k)
      if k == "denops#request_async" then
        return function(_plugin, method, _args, success, _failure)
          if counter then
            counter.count = counter.count + 1
          end
          local value = responses[method]
          if method == "getPrefix" and value == nil then
            value = (responses.getPreEdit or ""):gsub("^▽", "")
          end
          success(value)
        end
      end
      return old_fn[k]
    end,
  })
end

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

  skkeleton.register_completion("あい", "愛", "okurinasi", "愛")

  expect.equality(called, true)
  expect.equality(call_args[1], "あい")
  expect.equality(call_args[2], "愛")
  expect.equality(call_args[3], "okurinasi")
  expect.equality(call_args[4], "愛")

  vim.fn = old_fn
  skkeleton.clear_cache()
end

-- get_completion_data_async tests
T["get_completion_data_async"] = new_set()

T["get_completion_data_async"]["returns completion data"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛", "藍" } } },
    getRanks = { { "愛", 100 } },
  })

  local result
  skkeleton.get_completion_data_async(function(candidates, ranks_array, pre_edit)
    result = { candidates = candidates, ranks_array = ranks_array, pre_edit = pre_edit }
  end)

  expect.no_equality(result, nil)
  expect.equality(#result.candidates, 1)
  expect.equality(result.candidates[1][1], "あい")
  expect.equality(result.ranks_array[1][1], "愛")
  expect.equality(result.pre_edit, "▽あい")

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["returns empty data on failure"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(_, k)
      if k == "denops#request_async" then
        return function(_plugin, method, _args, success, failure)
          if method == "getPrefix" then
            success("あい")
          elseif method == "getPreEdit" then
            success("▽あい")
          else
            -- getCompletionResult fails
            failure("boom")
          end
        end
      end
      return old_fn[k]
    end,
  })

  local result
  skkeleton.get_completion_data_async(function(candidates, ranks_array, pre_edit)
    result = { candidates = candidates, ranks_array = ranks_array, pre_edit = pre_edit }
  end)

  expect.no_equality(result, nil)
  expect.equality(#result.candidates, 0)
  expect.equality(#result.ranks_array, 0)
  expect.equality(result.pre_edit, "▽あい")

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["caches result for same pre_edit"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  local counter = { count = 0 }
  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = { { "愛", 100 } },
  }, counter)

  -- First call: cache miss
  -- (getPrefix + getPreEdit + getCompletionResult + getRanks + getPrefix re-check)
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 5)

  -- Second call: cache hit (getPrefix + getPreEdit to check the key)
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 2)

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["invalidates cache on pre_edit change"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  local pre_edit_value = "▽あい"

  vim.fn = setmetatable({}, {
    __index = function(_, k)
      if k == "denops#request_async" then
        return function(_plugin, method, _args, success, _failure)
          if method == "getPrefix" then
            success((pre_edit_value:gsub("^▽", "")))
          elseif method == "getPreEdit" then
            success(pre_edit_value)
          elseif method == "getCompletionResult" then
            success({ { pre_edit_value:sub(4), { "test" } } })
          elseif method == "getRanks" then
            success({})
          else
            success(nil)
          end
        end
      end
      return old_fn[k]
    end,
  })

  -- First call
  local p1
  skkeleton.get_completion_data_async(function(_candidates, _ranks_array, pre_edit)
    p1 = pre_edit
  end)
  expect.equality(p1, "▽あい")

  -- Change pre_edit
  pre_edit_value = "▽あいう"

  -- Second call: cache miss (different pre_edit)
  local p2
  skkeleton.get_completion_data_async(function(_candidates, _ranks_array, pre_edit)
    p2 = pre_edit
  end)
  expect.equality(p2, "▽あいう")
  expect.no_equality(p1, p2)

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["clears cache after register_completion"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  local counter = { count = 0 }
  -- register_completion issues completeCallback via the synchronous denops#request,
  -- which this mock leaves to old_fn (pcall-guarded, so it is a harmless no-op in
  -- tests) and does not count -- only async RPCs increment the counter.
  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = { { "愛", 100 } },
  }, counter)

  -- Populate cache
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 5)

  -- Verify cache works
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 2) -- cache hit

  -- Register completion (should clear cache)
  skkeleton.register_completion("あい", "愛", "okurinasi")

  -- Next call should be cache miss
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 5) -- cache was cleared

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["drops candidates whose midashi does not match the prefix"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  vim.fn = mock_async(old_fn, {
    getPrefix = "あい",
    getPreEdit = "▽あい",
    -- "じぇい" は prefix "あい" に前方一致しないので除去される
    getCompletionResult = { { "あい", { "愛" } }, { "じぇい", { "J POINTS" } } },
    getRanks = { { "愛", 100 } },
  })

  local result
  skkeleton.get_completion_data_async(function(candidates, ranks_array, pre_edit)
    result = { candidates = candidates, ranks_array = ranks_array, pre_edit = pre_edit }
  end)

  expect.no_equality(result, nil)
  expect.equality(#result.candidates, 1)
  expect.equality(result.candidates[1][1], "あい")
  expect.equality(result.pre_edit, "▽あい")

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["discards result when prefix changes mid-fetch"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  -- getPrefix is read twice: once up front, once after candidates/ranks. Return
  -- a different henkanFeed the second time to simulate a keystroke landing
  -- mid-fetch. The reading/candidates are then from inconsistent states and the
  -- whole result must be dropped.
  local prefix_calls = 0
  vim.fn = setmetatable({}, {
    __index = function(_, k)
      if k == "denops#request_async" then
        return function(_plugin, method, _args, success, _failure)
          if method == "getPrefix" then
            prefix_calls = prefix_calls + 1
            success(prefix_calls == 1 and "あい" or "あいう")
          elseif method == "getPreEdit" then
            success("▽あい")
          elseif method == "getCompletionResult" then
            success({ { "あい", { "愛" } } })
          elseif method == "getRanks" then
            success({ { "愛", 100 } })
          else
            success(nil)
          end
        end
      end
      return old_fn[k]
    end,
  })

  local result
  skkeleton.get_completion_data_async(function(candidates, ranks_array, pre_edit)
    result = { candidates = candidates, ranks_array = ranks_array, pre_edit = pre_edit }
  end)

  expect.no_equality(result, nil)
  expect.equality(#result.candidates, 0)
  expect.equality(result.pre_edit, "")
  expect.equality(prefix_calls, 2)

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["returns empty when not in input state"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  local completion_called = false
  vim.fn = setmetatable({}, {
    __index = function(_, k)
      if k == "denops#request_async" then
        return function(_plugin, method, _args, success, _failure)
          if method == "getPrefix" then
            success("")
          elseif method == "getCompletionResult" then
            completion_called = true
            success({})
          else
            success(nil)
          end
        end
      end
      return old_fn[k]
    end,
  })

  local result
  skkeleton.get_completion_data_async(function(candidates, ranks_array, pre_edit)
    result = { candidates = candidates, ranks_array = ranks_array, pre_edit = pre_edit }
  end)

  expect.no_equality(result, nil)
  expect.equality(#result.candidates, 0)
  expect.equality(result.pre_edit, "")
  -- empty prefix short-circuits before fetching candidates
  expect.equality(completion_called, false)

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["get_completion_data_async"]["bails out and skips fetching when cancelled"] = function()
  skkeleton.clear_cache()
  local old_fn = vim.fn
  local counter = { count = 0 }
  vim.fn = mock_async(old_fn, {
    getPrefix = "あい",
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = { { "愛", 100 } },
  }, counter)

  local result
  counter.count = 0
  skkeleton.get_completion_data_async(function(candidates, ranks_array, pre_edit)
    result = { candidates = candidates, ranks_array = ranks_array, pre_edit = pre_edit }
  end, function()
    return true
  end)

  expect.no_equality(result, nil)
  expect.equality(#result.candidates, 0)
  expect.equality(result.pre_edit, "")
  -- cancelled before the first RPC: the chain never issues a request
  expect.equality(counter.count, 0)

  vim.fn = old_fn
  skkeleton.clear_cache()
end

-- Cache configuration tests
T["cache configuration"] = new_set()

T["cache configuration"]["returns data with custom TTL from vim.g"] = function()
  local old_fn = vim.fn
  local old_g = vim.g.blink_cmp_skkeleton_cache_ttl
  local old_loop = vim.loop

  vim.g.blink_cmp_skkeleton_cache_ttl = 50

  local current_time = 0
  vim.loop = {
    now = function()
      return current_time
    end,
  }

  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = {},
  })

  local function fetch()
    local pre_edit
    skkeleton.get_completion_data_async(function(_candidates, _ranks_array, p)
      pre_edit = p
    end)
    return pre_edit
  end

  current_time = 0
  skkeleton.clear_cache()
  expect.equality(fetch(), "▽あい")

  current_time = 40
  expect.equality(fetch(), "▽あい")

  current_time = 60
  expect.equality(fetch(), "▽あい")

  vim.fn = old_fn
  vim.loop = old_loop
  vim.g.blink_cmp_skkeleton_cache_ttl = old_g
  skkeleton.clear_cache()
end

-- Cache metrics tests
T["cache metrics"] = new_set()

T["cache metrics"]["tracks hit and miss counts"] = function()
  local old_fn = vim.fn
  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = {},
  })

  skkeleton.clear_cache()
  local stats = skkeleton.get_cache_stats()
  local initial_hits = stats.hits
  local initial_misses = stats.misses

  -- First call: miss
  skkeleton.get_completion_data_async(function() end)
  stats = skkeleton.get_cache_stats()
  expect.equality(stats.misses, initial_misses + 1)

  -- Second call: hit
  skkeleton.get_completion_data_async(function() end)
  stats = skkeleton.get_cache_stats()
  expect.equality(stats.hits, initial_hits + 1)

  vim.fn = old_fn
  skkeleton.clear_cache()
end

T["cache metrics"]["calculates hit rate correctly"] = function()
  local old_fn = vim.fn
  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = {},
  })

  skkeleton.clear_cache()

  -- 1 miss + 3 hits = 75% hit rate
  skkeleton.get_completion_data_async(function() end) -- miss
  skkeleton.get_completion_data_async(function() end) -- hit
  skkeleton.get_completion_data_async(function() end) -- hit
  skkeleton.get_completion_data_async(function() end) -- hit

  local stats = skkeleton.get_cache_stats()
  expect.equality(stats.hit_rate >= 74 and stats.hit_rate <= 76, true) -- Allow for floating point

  vim.fn = old_fn
  skkeleton.clear_cache()
end

-- TTL boundary tests (uses default 100ms TTL)
T["cache TTL boundary"] = new_set()

T["cache TTL boundary"]["invalidates at exact TTL boundary"] = function()
  local old_fn = vim.fn
  local old_loop = vim.loop

  -- Uses default TTL of 100ms (set at module load time)
  local current_time = 0
  vim.loop = {
    now = function()
      return current_time
    end,
  }

  local counter = { count = 0 }
  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = {},
  }, counter)

  -- First call at t=0 (cache miss)
  current_time = 0
  skkeleton.clear_cache()
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 5) -- miss: full fetch + prefix re-check

  -- At t=99 (just before 100ms TTL) - should be cache hit
  current_time = 99
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 2) -- hit: getPrefix + getPreEdit

  -- At t=100 (exactly at 100ms TTL) - should be cache miss
  current_time = 100
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 5) -- miss: full fetch

  vim.fn = old_fn
  vim.loop = old_loop
  skkeleton.clear_cache()
end

T["cache TTL boundary"]["just before TTL is cache hit"] = function()
  local old_fn = vim.fn
  local old_loop = vim.loop

  local current_time = 0
  vim.loop = {
    now = function()
      return current_time
    end,
  }

  local counter = { count = 0 }
  vim.fn = mock_async(old_fn, {
    getPreEdit = "▽あい",
    getCompletionResult = { { "あい", { "愛" } } },
    getRanks = {},
  }, counter)

  -- First call at t=0 (cache miss)
  current_time = 0
  skkeleton.clear_cache()
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 5) -- miss

  -- At t=50 (half of 100ms TTL) - should be cache hit
  current_time = 50
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 2) -- hit

  -- At t=99 (1ms before TTL) - should still be cache hit
  current_time = 99
  counter.count = 0
  skkeleton.get_completion_data_async(function() end)
  expect.equality(counter.count, 2) -- hit

  vim.fn = old_fn
  vim.loop = old_loop
  skkeleton.clear_cache()
end

return T
