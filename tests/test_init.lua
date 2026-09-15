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

-- is_enabled static helper tests
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

  local result = source_module.is_enabled()
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

  local result = source_module.is_enabled()
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

  local result = source_module.is_enabled()
  expect.equality(result, false)

  vim.fn = old_fn
end

-- get_trigger_characters tests
T["get_trigger_characters"] = new_set()

T["get_trigger_characters"]["returns Japanese trigger characters"] = function()
  local source = new_source()
  local triggers = source:get_trigger_characters()
  expect.equality(type(triggers), "table")
  -- Should have ~174 characters (hiragana + katakana)
  expect.equality(#triggers >= 170 and #triggers <= 180, true)
  -- Should include hiragana
  expect.equality(vim.tbl_contains(triggers, "あ"), true)
  expect.equality(vim.tbl_contains(triggers, "ん"), true)
  -- Should include katakana
  expect.equality(vim.tbl_contains(triggers, "ア"), true)
  expect.equality(vim.tbl_contains(triggers, "ン"), true)
end

T["get_trigger_characters"]["caches trigger characters"] = function()
  local source = new_source()
  local triggers1 = source:get_trigger_characters()
  local triggers2 = source:get_trigger_characters()
  -- Should return the same table reference (cached)
  expect.equality(triggers1, triggers2)
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
  require("blink-cmp-skkeleton.skkeleton").clear_cache()
  local source = new_source()
  local old_fn = vim.fn
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "skkeleton#is_enabled" then
        return function()
          return 1
        end
      end
      if k == "denops#request_async" then
        return function(plugin, method, args, success, _failure)
          if method == "getCompletionResult" then
            success({ { "あい", { "愛", "藍;indigo" } } })
          elseif method == "getRanks" then
            success({ { "愛", 100 } })
          elseif method == "getPreEdit" then
            success("▽あい")
          elseif method == "getPrefix" then
            success("あい")
          end
        end
      end
      return old_fn[k]
    end,
  })

  -- extract_filter_text slices the live buffer line using context.bounds, so
  -- populate the buffer to exercise the real path (filterText == reading
  -- without the ▽ marker). "▽あい" is 9 bytes; "あい" starts at byte 4.
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "▽あい" })
  vim.api.nvim_win_set_cursor(0, { 1, 9 })

  local callback_called = false
  local items = nil

  source:get_completions({
    cursor = { 1, 9 },
    line = "▽あい",
    bounds = { start_col = 4, length = 6 },
  }, function(response)
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

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
  vim.fn = old_fn
  require("blink-cmp-skkeleton.skkeleton").clear_cache()
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
  -- what has been inserted, which lets skkeleton take the completion back.
  -- This item carries neither a textEdit nor a label, so the entry stands in
  expect.equality(request_args[4], "愛")

  vim.fn = old_fn
end

T["execute"]["reports the inserted text, annotation excluded"] = function()
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
    label = "愛",
    textEdit = { newText = "愛" },
    data = {
      skkeleton = true,
      kana = "あい",
      word = "愛;love",
    },
  }, function() end, function() end)

  -- the entry is learned as it stands, the buffer got the text edit
  expect.equality(request_args[2], "愛;love")
  expect.equality(request_args[4], "愛")

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
