--- blink.cmp source for skkeleton
--- Based on skkeleton's ddc.vim source implementation
--- Adapted for blink.cmp native API

--- @class blink.cmp.Source
local source = {}

-- Debug flag - set to true to enable logging
local DEBUG = false

local function debug_log(msg)
  if DEBUG then
    vim.notify("[blink-cmp-skkeleton] " .. msg, vim.log.levels.INFO)
  end
end

--- Helper function to safely call vim functions
--- @param fn function|nil
--- @param ... unknown args
--- @return unknown
local function safe_call(fn, ...)
  if not fn then
    return nil
  end
  local ok, result = pcall(fn, ...)
  return ok and result or nil
end

--- Request data from skkeleton via denops
--- @param key string
--- @param args? any[]
--- @return unknown
local function request(key, args)
  args = args or {}
  local ok, result = pcall(vim.fn["denops#request"], "skkeleton", key, args)
  return ok and result or nil
end

--- Convert ranks array to map
--- @param ranks_array any[]
--- @return table<string, number>
local function convert_ranks_to_map(ranks_array)
  local ranks = {}
  for _, rank_entry in ipairs(ranks_array) do
    if rank_entry[1] and rank_entry[2] then
      ranks[rank_entry[1]] = rank_entry[2]
    end
  end
  return ranks
end

--- Build text edit range for pre-edit replacement
--- @param context blink.cmp.Context
--- @param pre_edit string
--- @return table LSP TextEdit range
local function build_text_edit_range(context, pre_edit)
  local cursor_line = context.cursor[1]
  local cursor_col = context.cursor[2]

  -- IMPORTANT: pre_edit_len is CHARACTER count, but cursor_col is BYTE position
  -- We need to use the actual byte length of pre_edit string
  local pre_edit_byte_len = #pre_edit
  local start_col = cursor_col - pre_edit_byte_len

  return {
    start = {
      line = cursor_line - 1, -- LSP uses 0-indexed lines
      character = start_col,
    },
    ["end"] = {
      line = cursor_line - 1,
      character = cursor_col,
    },
  }
end

--- Parse word to extract label and info
--- @param word string
--- @return string label, string info
local function parse_word(word)
  local label = word:gsub(";.*$", "")
  local info = word:find(";") and word:gsub(".*;", "") or ""
  return label, info
end

--- Build a single completion item
--- @param kana string
--- @param word string
--- @param rank number
--- @param text_edit_range table
--- @return blink.cmp.CompletionItem
local function build_completion_item(kana, word, rank, text_edit_range)
  local label, info = parse_word(word)

  local item = {
    label = label,
    kind = vim.lsp.protocol.CompletionItemKind.Text,
    -- filterText: use kana so it matches the extracted keyword
    filterText = kana,
    -- Use textEdit to replace the entire pre-edit text (including ▽)
    textEdit = {
      newText = label,
      range = text_edit_range,
    },
    -- sortText for ranking
    sortText = string.format("%010d", 1000000000 - rank),
    data = {
      skkeleton = true,
      kana = kana,
      word = word,
      rank = rank,
    },
  }

  if info ~= "" then
    item.documentation = {
      kind = "plaintext",
      value = info,
    }
  end

  return item
end

--- Build completion items from candidates
--- @param candidates any[]
--- @param ranks table<string, number>
--- @param text_edit_range table
--- @return blink.cmp.CompletionItem[]
local function build_completion_items(candidates, ranks, text_edit_range)
  -- Sort candidates by kana (reading)
  table.sort(candidates, function(a, b)
    return a[1] < b[1]
  end)

  -- グローバル辞書由来の候補はユーザー辞書の末尾より配置する
  -- 辞書順に並べるため先頭から順に負の方向にランクを振っていく
  local globalRank = -1
  local items = {}

  for _, cand in ipairs(candidates) do
    local kana = cand[1]
    debug_log(string.format("Building items for kana='%s', word_count=%d", kana, #cand[2]))

    for _, word in ipairs(cand[2]) do
      local rank = ranks[word] or globalRank
      if not ranks[word] then
        globalRank = globalRank - 1
      end

      local item = build_completion_item(kana, word, rank, text_edit_range)
      debug_log(string.format("  item: label='%s', rank=%d", item.label, rank))
      table.insert(items, item)
    end
  end

  -- Sort by rank (same as ddc implementation)
  table.sort(items, function(a, b)
    return a.data.rank > b.data.rank
  end)

  return items
end

--- Determine henkan type from kana string
--- @param kana string
--- @return "okuriari"|"okurinasi"
local function determine_henkan_type(kana)
  -- If kana contains uppercase letter or asterisk, it's okuriari (送りあり)
  if kana:match("[A-Z]") or kana:match("%*") then
    return "okuriari"
  end
  return "okurinasi"
end

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
  local is_enabled = safe_call(vim.fn["skkeleton#is_enabled"])
  if not is_enabled then
    debug_log("skkeleton not enabled, returning empty")
    callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = {},
    })
    return cancel_fun
  end

  -- Get completion data from skkeleton via denops
  local candidates = request("getCompletionResult") or {}
  local ranks_array = request("getRanks") or {}
  local pre_edit = request("getPreEdit") or ""

  debug_log(string.format("pre_edit='%s', candidates=%d", pre_edit, #candidates))

  -- Convert ranks and build items
  local ranks = convert_ranks_to_map(ranks_array)
  local text_edit_range = build_text_edit_range(context, pre_edit)
  local items = build_completion_items(candidates, ranks, text_edit_range)

  debug_log(string.format("returning %d items", #items))

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

  debug_log(string.format("execute: kana=%s, word=%s", item.data.kana, item.data.word))

  -- First, let blink.cmp insert the text
  default_implementation()

  -- Then, register the result with skkeleton for dictionary learning
  local henkan_type = determine_henkan_type(item.data.kana)
  request("completeCallback", { item.data.kana, item.data.word, henkan_type })

  callback()
end

return source
