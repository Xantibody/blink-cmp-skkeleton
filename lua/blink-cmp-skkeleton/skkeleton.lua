--- Skkeleton and denops integration layer
--- @module blink-cmp-skkeleton.skkeleton

local utils = require("blink-cmp-skkeleton.utils")

local M = {}

-- Cache storage
local cache = {
  key = nil,      -- Cache key (pre_edit)
  data = nil,     -- Cached data
  timestamp = 0,  -- Cache creation time
}

-- Cache TTL in milliseconds
local CACHE_TTL_MS = 100

--- Request data from skkeleton via denops
--- @param key string
--- @param args? any[]
--- @return unknown
local function request(key, args)
  args = args or {}
  local ok, result = pcall(vim.fn["denops#request"], "skkeleton", key, args)
  return ok and result or nil
end

--- Check if cache is valid
--- @param key string
--- @return boolean
local function is_cache_valid(key)
  if cache.key ~= key or not cache.data then
    return false
  end

  local now = vim.loop.now()
  local age = now - cache.timestamp

  return age < CACHE_TTL_MS
end

--- Set cache
--- @param key string
--- @param data table
local function set_cache(key, data)
  cache.key = key
  cache.data = data
  cache.timestamp = vim.loop.now()
end

--- Clear cache (public for testing)
function M.clear_cache()
  cache.key = nil
  cache.data = nil
  cache.timestamp = 0
end

--- Check if skkeleton is available and enabled
--- @return boolean
function M.is_enabled()
  local result = utils.safe_call(vim.fn["skkeleton#is_enabled"])
  return result == true or result == 1
end

--- Get completion data from skkeleton (with caching)
--- @return table candidates, table ranks_array, string pre_edit
function M.get_completion_data()
  -- Step 1: Get pre_edit (lightweight RPC)
  local pre_edit = request("getPreEdit") or ""

  -- Step 2: Check cache
  if is_cache_valid(pre_edit) then
    utils.debug_log(string.format("Cache HIT for '%s'", pre_edit))
    return cache.data.candidates, cache.data.ranks, cache.data.pre_edit
  end

  -- Step 3: Cache miss - fetch data
  utils.debug_log(string.format("Cache MISS for '%s', fetching...", pre_edit))

  local candidates = request("getCompletionResult") or {}
  local ranks_array = request("getRanks") or {}

  utils.debug_log(string.format("pre_edit='%s', candidates=%d", pre_edit, #candidates))

  -- Step 4: Update cache
  set_cache(pre_edit, {
    candidates = candidates,
    ranks = ranks_array,
    pre_edit = pre_edit,
  })

  return candidates, ranks_array, pre_edit
end

--- Register completion result with skkeleton for dictionary learning
--- @param kana string
--- @param word string
--- @param henkan_type "okuriari"|"okurinasi"
function M.register_completion(kana, word, henkan_type)
  utils.debug_log(string.format("register: kana=%s, word=%s, type=%s", kana, word, henkan_type))
  request("completeCallback", { kana, word, henkan_type })

  -- Clear cache after dictionary learning (ranks may change)
  M.clear_cache()
end

return M
