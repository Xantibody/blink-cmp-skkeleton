--- Tests for blink-cmp-skkeleton
--- Run with: nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

local source_module = require("blink-cmp-skkeleton")

describe("blink-cmp-skkeleton", function()
  local source

  before_each(function()
    source = source_module.new()
  end)

  describe("initialization", function()
    it("creates a new source instance", function()
      assert.is_not_nil(source)
      assert.is_table(source)
    end)

    it("has required methods", function()
      assert.is_function(source.enabled)
      assert.is_function(source.get_trigger_characters)
      assert.is_function(source.get_completions)
      assert.is_function(source.resolve)
      assert.is_function(source.execute)
    end)
  end)

  describe("enabled", function()
    it("returns true when skkeleton is available", function()
      -- Mock vim.fn.exists to return 1 (skkeleton available)
      local old_exists = vim.fn.exists
      vim.fn.exists = function(name)
        if name == "*skkeleton#is_enabled" then
          return 1
        end
        return old_exists(name)
      end

      local result = source:enabled()
      assert.is_true(result)

      vim.fn.exists = old_exists
    end)

    it("returns false when skkeleton is not available", function()
      -- Mock vim.fn.exists to return 0 (skkeleton not available)
      local old_exists = vim.fn.exists
      vim.fn.exists = function(name)
        if name == "*skkeleton#is_enabled" then
          return 0
        end
        return old_exists(name)
      end

      local result = source:enabled()
      assert.is_false(result)

      vim.fn.exists = old_exists
    end)
  end)

  describe("get_trigger_characters", function()
    it("returns empty array", function()
      local triggers = source:get_trigger_characters()
      assert.is_table(triggers)
      assert.equals(0, #triggers)
    end)
  end)

  describe("helper functions", function()
    -- Test helper functions via their exposed behavior
    it("handles completion items correctly", function()
      -- This tests the overall integration of helper functions
      -- We can't test them directly as they're local, but we can test their effect

      -- Mock skkeleton APIs
      local old_fn = vim.fn
      vim.fn = setmetatable({}, {
        __index = function(t, k)
          if k == "skkeleton#is_enabled" then
            return function()
              return true
            end
          end
          if k == "denops#request" then
            return function(plugin, method, args)
              if method == "getCompletionResult" then
                -- Return mock candidates: [kana, [word1, word2]]
                return { { "あい", { "愛", "藍;indigo" } } }
              elseif method == "getRanks" then
                -- Return mock ranks: [[word, rank]]
                return { { "愛", 100 } }
              elseif method == "getPreEdit" then
                return "▽あい"
              elseif method == "getPreEditLength" then
                return 3
              end
              return nil
            end
          end
          return old_fn[k]
        end,
      })

      local callback_called = false
      local callback_items = nil

      source:get_completions(
        {
          cursor = { 1, 9 }, -- line 1, byte position 9
          line = "▽あい",
        },
        function(response)
          callback_called = true
          callback_items = response.items
        end
      )

      -- Wait for vim.schedule
      vim.wait(100)

      assert.is_true(callback_called)
      assert.is_not_nil(callback_items)
      assert.equals(2, #callback_items) -- "愛" and "藍"

      -- Check first item
      local first_item = callback_items[1]
      assert.equals("愛", first_item.label)
      assert.equals("あい", first_item.filterText)
      assert.is_not_nil(first_item.textEdit)
      assert.equals("愛", first_item.textEdit.newText)

      -- Check second item has documentation
      local second_item = callback_items[2]
      assert.equals("藍", second_item.label)
      assert.is_not_nil(second_item.documentation)
      assert.equals("indigo", second_item.documentation.value)

      vim.fn = old_fn
    end)
  end)

  describe("resolve", function()
    it("returns item unchanged", function()
      local test_item = { label = "test" }
      local callback_called = false
      local resolved_item = nil

      source:resolve(test_item, function(item)
        callback_called = true
        resolved_item = item
      end)

      assert.is_true(callback_called)
      assert.equals(test_item, resolved_item)
    end)
  end)

  describe("execute", function()
    it("calls default_implementation for non-skkeleton items", function()
      local default_called = false
      local callback_called = false

      source:execute(
        {},
        { data = {} }, -- No skkeleton data
        function()
          callback_called = true
        end,
        function()
          default_called = true
        end
      )

      assert.is_true(default_called)
      assert.is_true(callback_called)
    end)

    it("registers with skkeleton for okurinasi", function()
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
              return nil
            end
          end
          return old_fn[k]
        end,
      })

      local default_called = false
      source:execute(
        {},
        {
          data = {
            skkeleton = true,
            kana = "あい",
            word = "愛",
          },
        },
        function() end,
        function()
          default_called = true
        end
      )

      assert.is_true(default_called)
      assert.is_true(request_called)
      assert.is_not_nil(request_args)
      assert.equals("あい", request_args[1])
      assert.equals("愛", request_args[2])
      assert.equals("okurinasi", request_args[3])

      vim.fn = old_fn
    end)

    it("registers with skkeleton for okuriari", function()
      local old_fn = vim.fn
      local request_args = nil

      vim.fn = setmetatable({}, {
        __index = function(t, k)
          if k == "denops#request" then
            return function(plugin, method, args)
              if method == "completeCallback" then
                request_args = args
              end
              return nil
            end
          end
          return old_fn[k]
        end,
      })

      source:execute(
        {},
        {
          data = {
            skkeleton = true,
            kana = "おくR", -- Uppercase R indicates okuriari
            word = "送る",
          },
        },
        function() end,
        function() end
      )

      assert.is_not_nil(request_args)
      assert.equals("okuriari", request_args[3])

      vim.fn = old_fn
    end)

    it("detects okuriari with asterisk", function()
      local old_fn = vim.fn
      local request_args = nil

      vim.fn = setmetatable({}, {
        __index = function(t, k)
          if k == "denops#request" then
            return function(plugin, method, args)
              if method == "completeCallback" then
                request_args = args
              end
              return nil
            end
          end
          return old_fn[k]
        end,
      })

      source:execute(
        {},
        {
          data = {
            skkeleton = true,
            kana = "おく*り",
            word = "送り",
          },
        },
        function() end,
        function() end
      )

      assert.is_not_nil(request_args)
      assert.equals("okuriari", request_args[3])

      vim.fn = old_fn
    end)
  end)
end)
