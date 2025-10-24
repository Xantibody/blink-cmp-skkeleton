--- Completion item builder for blink-cmp-skkeleton
--- @module blink-cmp-skkeleton.completion

local utils = require("blink-cmp-skkeleton.utils")

local M = {}

--- Convert ranks array to map
--- @param ranks_array any[]
--- @return table<string, number>
function M.convert_ranks_to_map(ranks_array)
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
function M.build_text_edit_range(context, pre_edit)
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

--- Build a single completion item
--- @param kana string
--- @param word string
--- @param rank number
--- @param text_edit_range table
--- @return blink.cmp.CompletionItem
function M.build_completion_item(kana, word, rank, text_edit_range)
  local label, info = utils.parse_word(word)

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
function M.build_completion_items(candidates, ranks, text_edit_range)
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
    utils.debug_log(string.format("Building items for kana='%s', word_count=%d", kana, #cand[2]))

    for _, word in ipairs(cand[2]) do
      local rank = ranks[word] or globalRank
      if not ranks[word] then
        globalRank = globalRank - 1
      end

      local item = M.build_completion_item(kana, word, rank, text_edit_range)
      utils.debug_log(string.format("  item: label='%s', rank=%d", item.label, rank))
      table.insert(items, item)
    end
  end

  -- Sort by rank (same as ddc implementation)
  table.sort(items, function(a, b)
    return a.data.rank > b.data.rank
  end)

  return items
end

return M
