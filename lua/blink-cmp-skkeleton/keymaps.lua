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
  local utils = require("blink-cmp-skkeleton.utils")

  -- Check if blink.cmp config is available
  local ok, config = pcall(require, "blink.cmp.config")
  if not ok or not config.keymap then
    utils.debug_log("sync_to_skkeleton: blink.cmp.config not available")
    return
  end

  utils.debug_log("sync_to_skkeleton: blink.cmp keymap preset = " .. (config.keymap.preset or "none"))

  -- Get merged keymap from blink.cmp.keymap module
  -- This expands presets into actual key mappings
  local keymap_ok, keymap_module = pcall(require, "blink.cmp.keymap")
  if not keymap_ok or not keymap_module.get_mappings then
    utils.debug_log("sync_to_skkeleton: blink.cmp.keymap module not available")
    return
  end

  local mappings_ok, mappings = pcall(keymap_module.get_mappings, config.keymap, "default")
  if not mappings_ok then
    utils.debug_log("sync_to_skkeleton: failed to get merged mappings")
    return
  end

  utils.debug_log(
    string.format("sync_to_skkeleton: got %d merged mappings from preset", vim.tbl_count(mappings))
  )

  -- Find keys for next/prev commands in merged mappings
  local next_keys = find_keys_for_command(mappings, "select_next")
  local prev_keys = find_keys_for_command(mappings, "select_prev")

  utils.debug_log(
    string.format("sync_to_skkeleton: found %d next keys, %d prev keys", #next_keys, #prev_keys)
  )

  -- Register keys to skkeleton henkan mode
  for _, key in ipairs(next_keys) do
    utils.debug_log("sync_to_skkeleton: registering " .. key .. " -> henkanForward")
    vim.fn["skkeleton#register_keymap"]("henkan", key, "henkanForward")
  end

  for _, key in ipairs(prev_keys) do
    utils.debug_log("sync_to_skkeleton: registering " .. key .. " -> henkanBackward")
    vim.fn["skkeleton#register_keymap"]("henkan", key, "henkanBackward")
  end
end

return M
