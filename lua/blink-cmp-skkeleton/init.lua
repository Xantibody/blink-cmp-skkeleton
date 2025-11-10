--- blink.cmp source for skkeleton
--- Based on skkeleton's ddc.vim source implementation
--- Adapted for blink.cmp native API
--- @module blink-cmp-skkeleton

local utils = require("blink-cmp-skkeleton.utils")
local skkeleton = require("blink-cmp-skkeleton.skkeleton")
local completion = require("blink-cmp-skkeleton.completion")

-- Module-level cache for trigger characters
local trigger_characters_cache = nil

--- @class blink.cmp.Source
local source = {}

--- Check if skkeleton is currently enabled
--- This is a public helper function for use in sources.default configuration
--- @return boolean
function source.is_enabled()
  return skkeleton.is_enabled()
end

--- Create a new source instance
--- @param opts? table Options
--- @return blink.cmp.Source
function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

--- Check if skkeleton is available
--- @return boolean
function source:enabled()
  return vim.fn.exists("*skkeleton#is_enabled") == 1
end

--- Get trigger characters for completion
--- @return string[]
function source:get_trigger_characters()
  -- Return hiragana and katakana characters as triggers
  -- This ensures that completion is triggered after accepting a completion
  -- and continuing to type Japanese characters
  if not trigger_characters_cache then
    trigger_characters_cache = utils.generate_japanese_triggers()
    utils.debug_log(string.format("Generated %d trigger characters", #trigger_characters_cache))
  end
  return trigger_characters_cache
end

--- Get completions from skkeleton
--- @param context blink.cmp.Context
--- @param callback fun(response: { is_incomplete_forward: boolean, is_incomplete_backward: boolean, items: blink.cmp.CompletionItem[] })
--- @return function cancel function
function source:get_completions(context, callback)
  -- Cancel function (no-op for now since we don't have async operations)
  local cancel_fun = function() end

  -- Debug: Log basic information
  utils.debug_log(
    string.format(
      "get_completions: line=%d, col=%d, trigger=%s",
      context.cursor[1],
      context.cursor[2],
      context.trigger and context.trigger.kind or "nil"
    )
  )

  -- Check if skkeleton is enabled
  if not skkeleton.is_enabled() then
    utils.debug_log("skkeleton not enabled, returning empty")
    callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = {},
    })
    return cancel_fun
  end

  -- Get completion data from skkeleton via denops
  local candidates, ranks_array, pre_edit = skkeleton.get_completion_data()

  -- Convert ranks and build items
  local ranks = completion.convert_ranks_to_map(ranks_array)

  -- Adjust text_edit_range based on context.bounds to match blink.cmp's keyword extraction
  local text_edit_range
  if context.bounds and pre_edit ~= "" then
    -- Use bounds to determine the range, but only replace the pre_edit portion
    local cursor_col = context.cursor[2]
    local pre_edit_byte_len = #pre_edit
    text_edit_range = {
      start = {
        line = context.cursor[1] - 1,
        character = cursor_col - pre_edit_byte_len,
      },
      ["end"] = {
        line = context.cursor[1] - 1,
        character = cursor_col,
      },
    }
  else
    text_edit_range = completion.build_text_edit_range(context, pre_edit)
  end

  -- Get filterText from context.bounds if available
  -- This ensures blink.cmp's filtering matches the keyword it extracted
  local filter_text = pre_edit
  if context.bounds and context.bounds.length > 0 then
    local current_line = vim.api.nvim_get_current_line()
    local start_byte = context.bounds.start_col - 1
    local length_bytes = context.bounds.length
    filter_text = current_line:sub(start_byte + 1, start_byte + length_bytes)
  end

  local items = completion.build_completion_items(candidates, ranks, text_edit_range, filter_text)

  utils.debug_log(string.format("Returning %d items for pre_edit='%s'", #items, pre_edit))

  -- Wrap callback in vim.schedule_wrap
  local wrapped_callback = vim.schedule_wrap(function()
    callback({
      is_incomplete_forward = true, -- Tell blink.cmp not to filter
      is_incomplete_backward = true,
      items = items,
    })
  end)

  wrapped_callback()
  return cancel_fun
end

--- Resolve additional information for a completion item
--- @param item blink.cmp.CompletionItem
--- @param callback fun(resolved_item: blink.cmp.CompletionItem|nil)
function source:resolve(item, callback)
  callback(item)
end

--- Execute completion (called when item is confirmed)
--- @param context blink.cmp.Context
--- @param item blink.cmp.CompletionItem
--- @param callback fun()
--- @param default_implementation fun()
function source:execute(context, item, callback, default_implementation)
  if not item.data or not item.data.skkeleton then
    default_implementation()
    return callback()
  end

  utils.debug_log(string.format("execute: kana=%s, word=%s", item.data.kana, item.data.word))

  -- First, let blink.cmp insert the text
  default_implementation()

  -- Then, register the result with skkeleton for dictionary learning
  local henkan_type = utils.determine_henkan_type(item.data.kana)
  skkeleton.register_completion(item.data.kana, item.data.word, henkan_type)

  callback()
end

return source
