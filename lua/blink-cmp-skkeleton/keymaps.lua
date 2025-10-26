--- Keymap synchronization between blink.cmp and skkeleton
--- @module blink-cmp-skkeleton.keymaps

local M = {}

--- Find keys mapped to a specific command in blink.cmp keymap
--- @param keymap table
--- @param command_name string
--- @return string[]
local function find_keys_for_command(keymap, command_name)
  local keys = {}
  for key, commands in pairs(keymap) do
    if key ~= "preset" and type(commands) == "table" then
      for _, cmd in ipairs(commands) do
        if cmd == command_name then
          table.insert(keys, key)
          break
        end
      end
    end
  end
  return keys
end

--- Synchronize blink.cmp keymap to skkeleton henkan mode
--- Maps blink.cmp's select_next/select_prev keys to skkeleton's henkanForward/henkanBackward
function M.sync_to_skkeleton()
  -- Check if blink.cmp is available
  local ok, config = pcall(require, "blink.cmp.config")
  if not ok or not config.keymap then
    return
  end

  -- Find keys for next/prev commands
  local next_keys = find_keys_for_command(config.keymap, "select_next")
  local prev_keys = find_keys_for_command(config.keymap, "select_prev")

  -- Register keys to skkeleton henkan mode
  for _, key in ipairs(next_keys) do
    vim.fn["skkeleton#register_keymap"]("henkan", key, "henkanForward")
  end

  for _, key in ipairs(prev_keys) do
    vim.fn["skkeleton#register_keymap"]("henkan", key, "henkanBackward")
  end
end

return M
