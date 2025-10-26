--- Tests for blink-cmp-skkeleton.keymaps module
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local keymaps = require("blink-cmp-skkeleton.keymaps")

local T = new_set()

-- sync_to_skkeleton tests
T["sync_to_skkeleton"] = new_set()

T["sync_to_skkeleton"]["does nothing if blink.cmp not available"] = function()
  -- Mock missing blink.cmp
  local old_package_loaded = package.loaded["blink.cmp.config"]
  package.loaded["blink.cmp.config"] = nil

  -- Should not error
  keymaps.sync_to_skkeleton()

  package.loaded["blink.cmp.config"] = old_package_loaded
end

T["sync_to_skkeleton"]["registers keys to skkeleton"] = function()
  local old_fn = vim.fn
  local registered_keymaps = {}

  -- Mock blink.cmp.config
  local old_package_loaded = package.loaded["blink.cmp.config"]
  package.loaded["blink.cmp.config"] = {
    keymap = {
      preset = "default",
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev" },
      ["<C-n>"] = { "select_next" },
      ["<C-p>"] = { "select_prev" },
    },
  }

  -- Mock skkeleton#register_keymap
  vim.fn = setmetatable({}, {
    __index = function(t, k)
      if k == "skkeleton#register_keymap" then
        return function(mode, key, action)
          table.insert(registered_keymaps, { mode = mode, key = key, action = action })
        end
      end
      return old_fn[k]
    end,
  })

  -- Execute
  keymaps.sync_to_skkeleton()

  -- Verify registered keymaps
  expect.equality(#registered_keymaps, 4) -- 2 next keys + 2 prev keys

  -- Check for henkanForward mappings
  local has_tab_forward = false
  local has_cn_forward = false
  for _, mapping in ipairs(registered_keymaps) do
    if mapping.mode == "henkan" and mapping.action == "henkanForward" then
      if mapping.key == "<Tab>" then
        has_tab_forward = true
      end
      if mapping.key == "<C-n>" then
        has_cn_forward = true
      end
    end
  end
  expect.equality(has_tab_forward, true)
  expect.equality(has_cn_forward, true)

  -- Check for henkanBackward mappings
  local has_stab_backward = false
  local has_cp_backward = false
  for _, mapping in ipairs(registered_keymaps) do
    if mapping.mode == "henkan" and mapping.action == "henkanBackward" then
      if mapping.key == "<S-Tab>" then
        has_stab_backward = true
      end
      if mapping.key == "<C-p>" then
        has_cp_backward = true
      end
    end
  end
  expect.equality(has_stab_backward, true)
  expect.equality(has_cp_backward, true)

  -- Cleanup
  vim.fn = old_fn
  package.loaded["blink.cmp.config"] = old_package_loaded
end

return T
