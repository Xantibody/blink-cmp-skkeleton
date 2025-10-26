--- blink.cmp source for skkeleton
--- Based on skkeleton's ddc.vim source implementation
--- Adapted for blink.cmp native API
--- @module blink-cmp-skkeleton

local utils = require("blink-cmp-skkeleton.utils")
local skkeleton = require("blink-cmp-skkeleton.skkeleton")
local completion = require("blink-cmp-skkeleton.completion")

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
  return {}
end

--- Get completions from skkeleton
--- @param context blink.cmp.Context
--- @param callback fun(response: { is_incomplete_forward: boolean, is_incomplete_backward: boolean, items: blink.cmp.CompletionItem[] })
--- @return function cancel function
function source:get_completions(context, callback)
  -- Cancel function (no-op for now since we don't have async operations)
  local cancel_fun = function() end

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

  -- Check if this is okurigana mode
  local is_okuriari = pre_edit:match("%*") or pre_edit:match("[A-Z]")

  if is_okuriari then
    utils.debug_log("Okurigana mode detected, fetching okuriari candidates")

    -- Get prefix (kana before conversion)
    local prefix = skkeleton.get_prefix()
    utils.debug_log(string.format("prefix='%s'", prefix))

    -- Try all possible splits
    local all_candidates = {}
    local splits = utils.okuri_splits(prefix)

    for _, split in ipairs(splits) do
      local word, okuri = split[1], split[2]
      local midasi = utils.get_okuri_str(word, okuri)

      utils.debug_log(string.format("Trying split: word='%s', okuri='%s', midasi='%s'", word, okuri, midasi))

      -- Get candidates for this split
      local cands = skkeleton.get_candidates(midasi, "okuriari")

      -- Add okuri back to each candidate
      for _, cand in ipairs(cands) do
        local label = cand:gsub(";.*$", "")  -- Strip annotations
        local with_okuri = label .. okuri

        table.insert(all_candidates, {
          word = with_okuri,
          kana = prefix,
          midasi = midasi,
        })
      end
    end

    utils.debug_log(string.format("Found %d okuriari candidates", #all_candidates))

    -- Build completion items
    local text_edit_range = completion.build_text_edit_range(context, pre_edit)
    local items = {}
    for i, cand in ipairs(all_candidates) do
      table.insert(items, {
        label = cand.word,
        kind = vim.lsp.protocol.CompletionItemKind.Text,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        textEdit = {
          newText = cand.word,
          range = text_edit_range,
        },
        filterText = cand.kana,
        sortText = string.format("%05d", -i),
        data = {
          skkeleton = true,
          kana = cand.kana,
          word = cand.word,
        },
      })
    end

    utils.debug_log(string.format("returning %d okuriari items", #items))

    -- Wrap callback in vim.schedule_wrap
    local wrapped_callback = vim.schedule_wrap(function()
      callback({
        is_incomplete_forward = true,
        is_incomplete_backward = true,
        items = items,
      })
    end)

    wrapped_callback()
    return cancel_fun
  end

  -- Normal okurinasi mode
  -- Convert ranks and build items
  local ranks = completion.convert_ranks_to_map(ranks_array)
  local text_edit_range = completion.build_text_edit_range(context, pre_edit)
  local items = completion.build_completion_items(candidates, ranks, text_edit_range)

  utils.debug_log(string.format("returning %d items", #items))

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
