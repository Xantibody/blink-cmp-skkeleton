--- Skkeleton and denops integration layer
--- @module blink-cmp-skkeleton.skkeleton

local utils = require("blink-cmp-skkeleton.utils")

local M = {}

-- Cache storage
local cache = {
  key = nil, -- Cache key (pre_edit)
  data = nil, -- Cached data
  timestamp = 0, -- Cache creation time
  cursor_pos = nil, -- Cursor position {line, col} when cache was created
}

-- Cache statistics
local cache_stats = {
  hits = 0,
  misses = 0,
}

-- Cache TTL in milliseconds (configurable via vim.g.blink_cmp_skkeleton_cache_ttl)
local CACHE_TTL_MS = vim.g.blink_cmp_skkeleton_cache_ttl or 100

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
--- @param cursor_pos table|nil {line, col}
local function set_cache(key, data, cursor_pos)
  cache.key = key
  cache.data = data
  cache.timestamp = vim.loop.now()
  cache.cursor_pos = cursor_pos
end

--- Clear cache and reset statistics (public for testing)
function M.clear_cache()
  cache.key = nil
  cache.data = nil
  cache.timestamp = 0
  cache.cursor_pos = nil
  cache_stats.hits = 0
  cache_stats.misses = 0
end

--- Get cache statistics
--- @return table stats { hits: number, misses: number, hit_rate: number }
function M.get_cache_stats()
  local total = cache_stats.hits + cache_stats.misses
  return {
    hits = cache_stats.hits,
    misses = cache_stats.misses,
    hit_rate = total > 0 and (cache_stats.hits / total * 100) or 0,
  }
end

--- Check if skkeleton is available and enabled
--- @return boolean
function M.is_enabled()
  local result = utils.safe_call(vim.fn["skkeleton#is_enabled"])
  return result == true or result == 1
end

--- Extract pre_edit text from current line when getPreEdit returns empty
--- @return string|nil
local function extract_pre_edit_from_line()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  -- Get the text up to cursor position
  local text_before_cursor = line:sub(1, col)

  -- Look for the henkan marker (▽) before cursor
  local marker_pos = text_before_cursor:find("▽")
  if marker_pos then
    -- Extract text after ▽ up to cursor (▽ is 3 bytes in UTF-8)
    local text_after_marker = text_before_cursor:sub(marker_pos + 3)
    return text_after_marker
  end

  return nil
end

--- Get completion data from skkeleton (with caching)
--- @return table candidates, table ranks_array, string pre_edit
function M.get_completion_data()
  -- Step 1: Get current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  -- Step 2: Get pre_edit (lightweight RPC)
  local pre_edit = request("getPreEdit") or ""

  -- Step 2.5: If pre_edit is empty, try to extract from current line
  if pre_edit == "" then
    local extracted = extract_pre_edit_from_line()
    if extracted then
      pre_edit = extracted
      utils.debug_log(string.format("Extracted pre_edit: '%s'", pre_edit))
    end
  end

  -- Step 3: Check if we can use cached data
  -- Use cache if:
  -- a) pre_edit matches the cached key, OR
  -- b) pre_edit is empty AND cursor position hasn't changed (rapid consecutive calls)
  local can_use_cache = false

  if is_cache_valid(pre_edit) then
    can_use_cache = true
  elseif pre_edit == "" and cache.data and cache.cursor_pos then
    -- If pre_edit is empty but we're at the same cursor position, use cache
    local same_position = (cache.cursor_pos[1] == cursor_line and cache.cursor_pos[2] == cursor_col)
    local cache_age = vim.loop.now() - cache.timestamp

    if same_position and cache_age < CACHE_TTL_MS then
      utils.debug_log(string.format("Using cache at same position (age=%dms)", cache_age))
      can_use_cache = true
    end
  end

  if can_use_cache then
    cache_stats.hits = cache_stats.hits + 1
    local total = cache_stats.hits + cache_stats.misses
    local hit_rate = cache_stats.hits / total * 100
    utils.debug_log(
      string.format("Cache HIT for '%s' (total: %d/%d, %.1f%%)", pre_edit, cache_stats.hits, total, hit_rate)
    )
    return cache.data.candidates, cache.data.ranks, cache.data.pre_edit
  end

  -- Step 4: Cache miss - fetch data
  cache_stats.misses = cache_stats.misses + 1
  utils.debug_log(string.format("Cache MISS for '%s', fetching...", pre_edit))

  local candidates = request("getCompletionResult") or {}
  local ranks_array = request("getRanks") or {}

  utils.debug_log(string.format("pre_edit='%s', candidates=%d", pre_edit, #candidates))

  -- Step 5: Update cache with cursor position
  set_cache(pre_edit, {
    candidates = candidates,
    ranks = ranks_array,
    pre_edit = pre_edit,
  }, { cursor_line, cursor_col })

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
