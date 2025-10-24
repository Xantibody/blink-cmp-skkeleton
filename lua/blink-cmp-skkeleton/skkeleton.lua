--- Skkeleton and denops integration layer
--- @module blink-cmp-skkeleton.skkeleton

local utils = require("blink-cmp-skkeleton.utils")

local M = {}

--- Request data from skkeleton via denops
--- @param key string
--- @param args? any[]
--- @return unknown
local function request(key, args)
  args = args or {}
  local ok, result = pcall(vim.fn["denops#request"], "skkeleton", key, args)
  return ok and result or nil
end

--- Check if skkeleton is available and enabled
--- @return boolean
function M.is_enabled()
  local result = utils.safe_call(vim.fn["skkeleton#is_enabled"])
  return result == true or result == 1
end

--- Get completion data from skkeleton
--- @return table candidates, table ranks_array, string pre_edit
function M.get_completion_data()
  local candidates = request("getCompletionResult") or {}
  local ranks_array = request("getRanks") or {}
  local pre_edit = request("getPreEdit") or ""

  utils.debug_log(string.format("pre_edit='%s', candidates=%d", pre_edit, #candidates))

  return candidates, ranks_array, pre_edit
end

--- Register completion result with skkeleton for dictionary learning
--- @param kana string
--- @param word string
--- @param henkan_type "okuriari"|"okurinasi"
function M.register_completion(kana, word, henkan_type)
  utils.debug_log(string.format("register: kana=%s, word=%s, type=%s", kana, word, henkan_type))
  request("completeCallback", { kana, word, henkan_type })
end

return M
