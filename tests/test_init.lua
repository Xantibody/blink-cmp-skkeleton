--- Integration tests for blink-cmp-skkeleton main API
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local source_module = require("blink-cmp-skkeleton")

local T = new_set()

-- Helper to create a new source instance
local function new_source()
  return source_module.new()
end

-- Initialization tests
T["initialization"] = new_set()

T["initialization"]["creates a new source instance"] = function()
  local source = new_source()
  expect.no_equality(source, nil)
  expect.equality(type(source), "table")
end

T["initialization"]["has required methods"] = function()
  local source = new_source()
  expect.equality(type(source.enabled), "function")
  expect.equality(type(source.get_trigger_characters), "function")
  expect.equality(type(source.get_completions), "function")
  expect.equality(type(source.resolve), "function")
  expect.equality(type(source.execute), "function")
end

-- enabled tests
T["enabled"] = new_set()

T["enabled"]["returns true when skkeleton is available"] = function()
  local source = new_source()
  local old_exists = vim.fn.exists
  vim.fn.exists = function(name)
    if name == "*skkeleton#is_enabled" then
      return 1
    end
    return old_exists(name)
  end

  local result = source:enabled()
  expect.equality(result, true)

  vim.fn.exists = old_exists
end

T["enabled"]["returns false when skkeleton is not available"] = function()
  local source = new_source()
  local old_exists = vim.fn.exists
  vim.fn.exists = function(name)
    if name == "*skkeleton#is_enabled" then
      return 0
    end
    return old_exists(name)
  end

  local result = source:enabled()
  expect.equality(result, false)

  vim.fn.exists = old_exists
end

-- get_trigger_characters tests
T["get_trigger_characters"] = new_set()

T["get_trigger_characters"]["returns empty array"] = function()
  local source = new_source()
  local triggers = source:get_trigger_characters()
  expect.equality(type(triggers), "table")
  expect.equality(#triggers, 0)
end

-- get_completions integration tests
T["get_completions"] = new_set()

T["get_completions"]["returns empty when skkeleton is disabled"] = function()
  local source = new_source()
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

  local callback_called = false
  local items = nil

  source:get_completions({ cursor = { 1, 0 }, line = "" }, function(response)
    callback_called = true
    items = response.items
  end)

  vim.wait(100)

  expect.equality(callback_called, true)
  expect.equality(#items, 0)

  vim.fn = old_fn
end

T["get_completions"]["builds completion items correctly"] = function()
  local source = new_source()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "skkeleton#is_enabled" then
        return function()
          return 1
        end
      end
      if k == "denops#request" then
        return function(plugin, method, args)
          if method == "getCompletionResult" then
            return { { "あい", { "愛", "藍;indigo" } } }
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

  local callback_called = false
  local items = nil

  source:get_completions({ cursor = { 1, 9 }, line = "▽あい" }, function(response)
    callback_called = true
    items = response.items
  end)

  vim.wait(100)

  expect.equality(callback_called, true)
  expect.equality(#items, 2)
  expect.equality(items[1].label, "愛")
  expect.equality(items[1].filterText, "あい")
  expect.equality(items[2].label, "藍")
  expect.no_equality(items[2].documentation, nil)

  vim.fn = old_fn
end

-- resolve tests
T["resolve"] = new_set()

T["resolve"]["returns item unchanged"] = function()
  local source = new_source()
  local test_item = { label = "test" }
  local callback_called = false
  local resolved_item = nil

  source:resolve(test_item, function(item)
    callback_called = true
    resolved_item = item
  end)

  expect.equality(callback_called, true)
  expect.equality(resolved_item, test_item)
end

-- execute tests
T["execute"] = new_set()

T["execute"]["calls default for non-skkeleton items"] = function()
  local source = new_source()
  local default_called = false
  local callback_called = false

  source:execute({}, { data = {} }, function()
    callback_called = true
  end, function()
    default_called = true
  end)

  expect.equality(default_called, true)
  expect.equality(callback_called, true)
end

T["execute"]["registers okurinasi with skkeleton"] = function()
  local source = new_source()
  local old_fn = vim.fn
  local request_called = false
  local request_args = nil

  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "denops#request" then
        return function(plugin, method, args)
          if method == "completeCallback" then
            request_called = true
            request_args = args
          end
        end
      end
      return old_fn[k]
    end,
  })

  source:execute({}, {
    data = {
      skkeleton = true,
      kana = "あい",
      word = "愛",
    },
  }, function() end, function() end)

  expect.equality(request_called, true)
  expect.equality(request_args[1], "あい")
  expect.equality(request_args[2], "愛")
  expect.equality(request_args[3], "okurinasi")

  vim.fn = old_fn
end

T["execute"]["registers okuriari with uppercase"] = function()
  local source = new_source()
  local old_fn = vim.fn
  local request_args = nil

  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "denops#request" then
        return function(plugin, method, args)
          if method == "completeCallback" then
            request_args = args
          end
        end
      end
      return old_fn[k]
    end,
  })

  source:execute({}, {
    data = {
      skkeleton = true,
      kana = "おくR",
      word = "送る",
    },
  }, function() end, function() end)

  expect.equality(request_args[3], "okuriari")

  vim.fn = old_fn
end

T["execute"]["registers okuriari with asterisk"] = function()
  local source = new_source()
  local old_fn = vim.fn
  local request_args = nil

  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "denops#request" then
        return function(plugin, method, args)
          if method == "completeCallback" then
            request_args = args
          end
        end
      end
      return old_fn[k]
    end,
  })

  source:execute({}, {
    data = {
      skkeleton = true,
      kana = "おく*り",
      word = "送り",
    },
  }, function() end, function() end)

  expect.equality(request_args[3], "okuriari")

  vim.fn = old_fn
end

return T
