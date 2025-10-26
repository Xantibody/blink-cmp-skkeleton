--- Utility functions for blink-cmp-skkeleton
--- @module blink-cmp-skkeleton.utils

local M = {}

-- Debug flag - set to true to enable logging
local DEBUG = false

--- Log debug message
--- @param msg string
function M.debug_log(msg)
  if DEBUG then
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

--- Split kana string into all possible [word, okuri] combinations
--- Based on skkeleton's okuriSplits function
--- @param text string
--- @return table[] Array of [word, okuri] pairs
function M.okuri_splits(text)
  if text == "" then
    return {}
  end

  local chars = {}
  for c in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    table.insert(chars, c)
  end

  local result = {}
  for i = #chars - 1, 1, -1 do
    local word = table.concat(chars, "", 1, i)
    local okuri = table.concat(chars, "", i + 1)
    table.insert(result, { word, okuri })
  end

  return result
end

--- Okuri character to romanized mapping table
--- Based on skkeleton's okuriTable
local okuri_table = {
  ["あ"] = "a",
  ["い"] = "i",
  ["う"] = "u",
  ["え"] = "e",
  ["お"] = "o",
  ["か"] = "k",
  ["き"] = "k",
  ["く"] = "k",
  ["け"] = "k",
  ["こ"] = "k",
  ["が"] = "g",
  ["ぎ"] = "g",
  ["ぐ"] = "g",
  ["げ"] = "g",
  ["ご"] = "g",
  ["さ"] = "s",
  ["し"] = "s",
  ["す"] = "s",
  ["せ"] = "s",
  ["そ"] = "s",
  ["ざ"] = "z",
  ["じ"] = "z",
  ["ず"] = "z",
  ["ぜ"] = "z",
  ["ぞ"] = "z",
  ["た"] = "t",
  ["ち"] = "t",
  ["つ"] = "t",
  ["て"] = "t",
  ["と"] = "t",
  ["だ"] = "d",
  ["ぢ"] = "d",
  ["づ"] = "d",
  ["で"] = "d",
  ["ど"] = "d",
  ["な"] = "n",
  ["に"] = "n",
  ["ぬ"] = "n",
  ["ね"] = "n",
  ["の"] = "n",
  ["は"] = "h",
  ["ひ"] = "h",
  ["ふ"] = "h",
  ["へ"] = "h",
  ["ほ"] = "h",
  ["ば"] = "b",
  ["び"] = "b",
  ["ぶ"] = "b",
  ["べ"] = "b",
  ["ぼ"] = "b",
  ["ぱ"] = "p",
  ["ぴ"] = "p",
  ["ぷ"] = "p",
  ["ぺ"] = "p",
  ["ぽ"] = "p",
  ["ま"] = "m",
  ["み"] = "m",
  ["む"] = "m",
  ["め"] = "m",
  ["も"] = "m",
  ["や"] = "y",
  ["ゆ"] = "y",
  ["よ"] = "y",
  ["ら"] = "r",
  ["り"] = "r",
  ["る"] = "r",
  ["れ"] = "r",
  ["ろ"] = "r",
  ["わ"] = "w",
  ["ゐ"] = "w",
  ["ゑ"] = "w",
  ["を"] = "w",
  ["ん"] = "n",
}

--- Get okuri string for dictionary lookup
--- Based on skkeleton's getOkuriStr function
--- @param word string
--- @param okuri string
--- @return string
function M.get_okuri_str(word, okuri)
  -- Handle っ (sokuon)
  if okuri:sub(1, 3) == "っ" then
    return word .. "t"
  end

  -- Get first character of okuri
  local first_char = okuri:match("^[%z\1-\127\194-\244][\128-\191]*")
  if not first_char then
    return word
  end

  -- Look up in okuri table
  local rom = okuri_table[first_char]
  if rom then
    return word .. rom
  end

  return word
end

return M
