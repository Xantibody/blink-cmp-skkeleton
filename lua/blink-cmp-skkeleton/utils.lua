--- Utility functions for blink-cmp-skkeleton
--- @module blink-cmp-skkeleton.utils

local M = {}

--- Log debug message
--- @param msg string
function M.debug_log(msg)
  if vim.g.blink_cmp_skkeleton_debug then
    vim.notify("[blink-cmp-skkeleton] " .. msg, vim.log.levels.INFO)
  end
end

--- Helper function to safely call vim functions
--- @param fn function|nil
--- @param ... unknown args
--- @return unknown
function M.safe_call(fn, ...)
  if not fn then
    return nil
  end
  local ok, result = pcall(fn, ...)
  return ok and result or nil
end

--- Parse word to extract label and info
--- @param word string
--- @return string label, string info
function M.parse_word(word)
  local label = word:gsub(";.*$", "")
  local info = word:find(";") and word:gsub(".*;", "") or ""
  return label, info
end

--- Determine henkan type from kana string
--- @param kana string
--- @return "okuriari"|"okurinasi"
function M.determine_henkan_type(kana)
  -- If kana contains uppercase letter or asterisk, it's okuriari (送りあり)
  if kana:match("[A-Z]") or kana:match("%*") then
    return "okuriari"
  end
  return "okurinasi"
end

--- Generate all hiragana characters as trigger characters
--- @return string[]
function M.generate_hiragana_triggers()
  local triggers = {}
  -- Basic hiragana: ぁ-ん (U+3041 - U+3093)
  for codepoint = 0x3041, 0x3093 do
    table.insert(triggers, vim.fn.nr2char(codepoint))
  end
  -- Additional hiragana marks: ゛゜ゝゞ (U+309B - U+309E)
  for codepoint = 0x309B, 0x309E do
    table.insert(triggers, vim.fn.nr2char(codepoint))
  end
  -- Long vowel mark: ー (U+30FC)
  table.insert(triggers, vim.fn.nr2char(0x30FC))
  return triggers
end

--- Generate all katakana characters as trigger characters
--- @return string[]
function M.generate_katakana_triggers()
  local triggers = {}
  -- Basic katakana: ァ-ヴ (U+30A1 - U+30F4)
  for codepoint = 0x30A1, 0x30F4 do
    table.insert(triggers, vim.fn.nr2char(codepoint))
  end
  -- Additional katakana marks: ・ヽヾ (U+30FB - U+30FE)
  for codepoint = 0x30FB, 0x30FE do
    table.insert(triggers, vim.fn.nr2char(codepoint))
  end
  return triggers
end

--- Generate all Japanese trigger characters (hiragana + katakana)
--- @return string[]
function M.generate_japanese_triggers()
  local triggers = M.generate_hiragana_triggers()
  vim.list_extend(triggers, M.generate_katakana_triggers())
  return triggers
end

return M
