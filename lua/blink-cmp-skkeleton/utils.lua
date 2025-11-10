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

return M
