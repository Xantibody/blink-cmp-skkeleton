--- Teach skkeleton about candidates that were confirmed without `accept`.
---
--- Every other SKK implementation learns a candidate the moment the text it
--- inserted is left standing, not when a dedicated confirm key is pressed. In
--- SKK you leave the selection state simply by carrying on, and the candidate
--- is committed and learned on the way out (macSKK does this in
--- `fixCurrentSelect()`; ddc gets it for free because `CompleteDone` fires
--- whenever the popup closes with an item inserted).
---
--- blink.cmp has no such event: `source:execute()` only runs on `accept`, so
--- selecting a candidate and moving on teaches skkeleton nothing even though
--- the previewed text stays in the buffer.
---
--- The state that says "the user chose this" is only intact at the moment of
--- selection, so that is where it is recorded. By the time the session ends,
--- blink.cmp has undone the preview and -- if the keyword bounds moved --
--- cleared `is_explicitly_selected`, so neither can be consulted then.
---
--- What decides it at the end is the buffer itself: the candidate is learned
--- only if its text is still standing where the preview put it. That single
--- check covers everything that must not be learned, because blink.cmp calls
--- `undo_preview()` before it hides in every one of those cases:
---
---   * `accept` restores the pre-preview text and only applies the real edit
---     later, after `resolve`, so nothing is standing when the hide arrives --
---     and `source:execute()` learns it anyway
---   * `cancel` rolls the text back and leaves it that way
---   * moving the selection replaces the text with the next candidate's, so
---     the one being left behind no longer stands
---
--- NOTE: `blink.cmp.completion.list` is not a documented interface. The
---       emitters behind the `BlinkCmpListSelect` / `BlinkCmpHide` autocmds
---       are used instead of the autocmds themselves because the autocmd
---       variants are `vim.schedule`d, by which point the buffer and the
---       state above have moved on. Everything internal is confined to this
---       file, and kept to the two fields least likely to move:
---       `is_explicitly_selected`, and `preview_undo` as a plain "is a preview
---       applied" flag -- never its contents.
---
--- @module blink-cmp-skkeleton.autoconfirm

local skkeleton = require("blink-cmp-skkeleton.skkeleton")
local utils = require("blink-cmp-skkeleton.utils")

local M = {}

--- A candidate whose text is standing in the buffer, waiting to be either
--- learned or superseded.
--- @class blink-cmp-skkeleton.Pending
--- @field kana string
--- @field word string dictionary entry, annotation included
--- @field text string what the preview actually inserted
--- @field bufnr integer
--- @field row integer 1-indexed, as returned by nvim_win_get_cursor
--- @field col integer byte column just past the inserted text, 0-indexed

--- @type blink-cmp-skkeleton.Pending|nil
local pending = nil

--- True once the emitters have been subscribed to, so `attach()` is idempotent.
local attached = false

--- @param item blink.cmp.CompletionItem|nil
--- @return boolean
local function is_skkeleton_item(item)
  return item ~= nil and item.data ~= nil and item.data.skkeleton == true
end

--- @param item blink.cmp.CompletionItem
--- @return string
local function inserted_text(item)
  return item.textEdit and item.textEdit.newText or item.label
end

--- Is the pending candidate's text still where the preview put it?
--- @param p blink-cmp-skkeleton.Pending
--- @return boolean
local function still_stands(p)
  if p.bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  if cursor[1] ~= p.row then
    return false
  end
  local line = vim.api.nvim_get_current_line()
  return line:sub(1, p.col):sub(-#p.text) == p.text
end

--- Learn the pending candidate if its text was left standing.
--- @param reason string what ended the candidate's turn, for the log
--- @return boolean learned
function M.commit(reason)
  local p = pending
  pending = nil
  if p == nil then
    return false
  end

  if not still_stands(p) then
    utils.debug_log(string.format("autoconfirm: %s, %s was rolled back, not learning", reason, p.text))
    return false
  end

  utils.debug_log(string.format("autoconfirm: %s, learning %s/%s", reason, p.kana, p.text))
  local kana, word = p.kana, p.word
  vim.schedule(function()
    skkeleton.register_completion(kana, word, utils.determine_henkan_type(kana))
  end)
  return true
end

--- Record a candidate the user deliberately selected, and settle the one it
--- displaces.
---
--- `is_explicitly_selected` is what separates a choice from an automatic
--- preselect, including when the item is nil: stepping off the top of the list
--- deselects deliberately, whereas re-showing the menu preselects the first
--- entry with `is_explicit_selection = false`. A preselect must leave an
--- earlier choice alone, because that candidate's text may well still be
--- standing -- that is exactly the state after the user types on.
--- @param list table blink.cmp's completion list module (or a stand-in)
--- @param item blink.cmp.CompletionItem|nil
function M.on_select(list, item)
  if not list.is_explicitly_selected then
    return
  end

  local chosen = is_skkeleton_item(item) and list.preview_undo ~= nil
  if pending ~= nil and (not chosen or item.data.word ~= pending.word) then
    M.commit("selection moved on")
  end
  if not chosen then
    return
  end

  -- The cursor sits just past the text the preview inserted: `apply_preview()`
  -- has run and nothing has moved it by the time this event is emitted. Taking
  -- it from the editor rather than from `preview_undo` keeps us clear of that
  -- table's contents, which blink.cmp has already reshaped on main (`cursor_after`
  -- became `pos_after`, a `vim.Pos`, in #2584).
  local cursor = vim.api.nvim_win_get_cursor(0)
  pending = {
    kana = item.data.kana,
    word = item.data.word,
    text = inserted_text(item),
    bufnr = vim.api.nvim_get_current_buf(),
    row = cursor[1],
    col = cursor[2],
  }
end

--- The completion session ended: settle whatever was pending.
--- @return boolean learned
function M.on_hide()
  return M.commit("menu closed")
end

--- Forget any pending candidate without learning it. Only useful for tests.
function M.reset()
  pending = nil
end

--- Subscribe to blink.cmp's completion list events.
--- @return boolean attached false when blink.cmp is missing or its internals moved
function M.attach()
  if attached then
    return true
  end

  local ok, list = pcall(require, "blink.cmp.completion.list")
  if not ok or type(list) ~= "table" or not list.select_emitter or not list.hide_emitter then
    utils.debug_log("autoconfirm: blink.cmp.completion.list is unavailable, skipped")
    return false
  end

  list.select_emitter:on(function(event)
    M.on_select(list, event.item)
  end)
  list.hide_emitter:on(function()
    M.on_hide()
  end)

  attached = true
  utils.debug_log("autoconfirm: attached to blink.cmp completion list")
  return true
end

--- Attach once skkeleton is about to be enabled. Deferred so that merely
--- installing this plugin does not pull blink.cmp in at startup.
function M.setup()
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("blink-cmp-skkeleton-autoconfirm", { clear = true }),
    pattern = "skkeleton-enable-pre",
    once = true,
    callback = M.attach,
    desc = "Learn skkeleton candidates confirmed without blink.cmp's accept",
  })
end

return M
