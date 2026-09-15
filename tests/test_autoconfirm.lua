--- Tests for blink-cmp-skkeleton.autoconfirm module
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local autoconfirm = require("blink-cmp-skkeleton.autoconfirm")
local skkeleton = require("blink-cmp-skkeleton.skkeleton")

--- Put `text` in the current buffer and the cursor at its end, the way an
--- `auto_insert` preview leaves things.
--- @param text string
--- @return integer[] cursor
local function set_line(text)
  vim.api.nvim_set_current_line(text)
  local cursor = { 1, #text }
  vim.api.nvim_win_set_cursor(0, cursor)
  return cursor
end

--- Stand-in for `blink.cmp.completion.list`. `preview_undo` is only ever read
--- as a flag, so its contents do not matter.
--- @param opts { is_explicitly_selected: boolean, previewed: boolean|nil }
--- @return table
local function fake_list(opts)
  return {
    is_explicitly_selected = opts.is_explicitly_selected,
    preview_undo = opts.previewed and { text_edit = {} } or nil,
  }
end

--- @param kana string
--- @param word string
--- @return blink.cmp.CompletionItem
local function skk_item(kana, word)
  return { label = word, data = { skkeleton = true, kana = kana, word = word } }
end

--- Select `item` with its preview standing in the buffer, as blink.cmp leaves
--- things after the user moves the selection.
--- @param item blink.cmp.CompletionItem
--- @param line? string buffer contents, defaults to the item's text alone
local function select_with_preview(item, line)
  set_line(line or item.label)
  autoconfirm.on_select(fake_list({ is_explicitly_selected = true, previewed = true }), item)
end

--- Capture `register_completion()` calls for the duration of `fn`. The module
--- table is shared with autoconfirm, so replacing the field is enough.
--- @param fn fun(calls: table[])
local function with_captured_registration(fn)
  local saved = skkeleton.register_completion
  local calls = {}
  skkeleton.register_completion = function(kana, word, henkan_type, inserted)
    table.insert(calls, { kana = kana, word = word, henkan_type = henkan_type, inserted = inserted })
  end
  local ok, err = pcall(fn, calls)
  skkeleton.register_completion = saved
  if not ok then
    error(err)
  end
end

--- Registration is deferred with `vim.schedule()`, so let the loop run.
local function flush()
  vim.wait(10, function()
    return false
  end)
end

local saved_virtualedit

local T = new_set({
  hooks = {
    pre_case = function()
      autoconfirm.reset()
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
      -- All of this happens in insert mode for real, where the cursor may sit
      -- one past the end of the line. Normal mode clamps it to the start of the
      -- last character instead, which would put `set_line()` at the wrong byte.
      saved_virtualedit = vim.o.virtualedit
      vim.o.virtualedit = "onemore"
    end,
    post_case = function()
      vim.o.virtualedit = saved_virtualedit
      autoconfirm.reset()
      pcall(vim.api.nvim_del_augroup_by_name, "blink-cmp-skkeleton-autoconfirm")
    end,
  },
})

T["commit"] = new_set()

T["commit"]["learns a candidate left standing when the menu closes"] = function()
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"))
    -- The user carries on typing; the previewed text stays put
    set_line("プラグインほげ")
    expect.equality(autoconfirm.on_hide(), true)
    flush()
    expect.equality(#calls, 1)
    expect.equality(calls[1].kana, "ぷらぐいん")
    expect.equality(calls[1].word, "プラグイン")
    expect.equality(calls[1].henkan_type, "okurinasi")
    -- the text the preview left standing, for skkeleton's kakutei undo
    expect.equality(calls[1].inserted, "プラグイン")
  end)
end

T["commit"]["learns a candidate that is not at the start of the line"] = function()
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"), "この プラグイン")
    set_line("この プラグインは")
    expect.equality(autoconfirm.on_hide(), true)
    flush()
    expect.equality(#calls, 1)
  end)
end

T["commit"]["ignores a candidate that was rolled back"] = function()
  -- accept() and cancel() both call undo_preview() before hiding, so the
  -- pre-preview text is what is standing by the time the hide arrives
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"))
    set_line("▽ぷらぐ")
    expect.equality(autoconfirm.on_hide(), false)
    flush()
    expect.equality(#calls, 0)
  end)
end

T["commit"]["ignores the automatic preselect of the first entry"] = function()
  with_captured_registration(function(calls)
    set_line("プラグイン")
    autoconfirm.on_select(
      fake_list({ is_explicitly_selected = false, previewed = true }),
      skk_item("ぷらぐいん", "プラグイン")
    )
    expect.equality(autoconfirm.on_hide(), false)
    flush()
    expect.equality(#calls, 0)
  end)
end

T["commit"]["ignores a hide with nothing pending"] = function()
  with_captured_registration(function(calls)
    expect.equality(autoconfirm.on_hide(), false)
    flush()
    expect.equality(#calls, 0)
  end)
end

T["commit"]["ignores items from other sources"] = function()
  with_captured_registration(function(calls)
    set_line("plugin")
    autoconfirm.on_select(
      fake_list({ is_explicitly_selected = true, previewed = true }),
      { label = "plugin", data = { lsp = true } }
    )
    expect.equality(autoconfirm.on_hide(), false)
    flush()
    expect.equality(#calls, 0)
  end)
end

T["commit"]["ignores a candidate left in another buffer"] = function()
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"))
    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    expect.equality(autoconfirm.on_hide(), false)
    flush()
    expect.equality(#calls, 0)
  end)
end

T["commit"]["forgets the candidate so a second hide is a no-op"] = function()
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"))
    expect.equality(autoconfirm.on_hide(), true)
    expect.equality(autoconfirm.on_hide(), false)
    flush()
    expect.equality(#calls, 1)
  end)
end

T["commit"]["passes okuriari readings through as okuriari"] = function()
  with_captured_registration(function(calls)
    select_with_preview(skk_item("あ*たり", "当"))
    expect.equality(autoconfirm.on_hide(), true)
    flush()
    expect.equality(#calls, 1)
    expect.equality(calls[1].henkan_type, "okuriari")
  end)
end

T["commit"]["registers the dictionary entry, not the displayed label"] = function()
  -- Annotated entries show only the part before the ';', but skkeleton has to
  -- be handed the whole entry back
  with_captured_registration(function(calls)
    local item = skk_item("かんじ", "感じ;feeling")
    item.label = "感じ"
    item.textEdit = { newText = "感じ" }
    select_with_preview(item)
    expect.equality(autoconfirm.on_hide(), true)
    flush()
    expect.equality(#calls, 1)
    expect.equality(calls[1].word, "感じ;feeling")
  end)
end

T["selection moves"] = new_set()

T["selection moves"]["does not learn the candidate the user moved off"] = function()
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"))
    -- Moving the selection replaces the previewed text with the next candidate
    select_with_preview(skk_item("ぷらぐ", "🔌"))
    expect.equality(autoconfirm.on_hide(), true)
    flush()
    expect.equality(#calls, 1)
    expect.equality(calls[1].word, "🔌")
  end)
end

T["selection moves"]["keeps the choice when the menu re-preselects another entry"] = function()
  -- After the user types on, blink.cmp clears is_explicitly_selected and
  -- preselects the first entry. The chosen candidate is still standing, so it
  -- must survive until the session actually ends.
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"))
    set_line("プラグインほ")
    autoconfirm.on_select(fake_list({ is_explicitly_selected = false }), skk_item("ほげ", "反故"))
    expect.equality(autoconfirm.on_hide(), true)
    flush()
    expect.equality(#calls, 1)
    expect.equality(calls[1].word, "プラグイン")
  end)
end

T["selection moves"]["settles the choice when the selection is cleared"] = function()
  with_captured_registration(function(calls)
    select_with_preview(skk_item("ぷらぐいん", "プラグイン"))
    -- <C-p> back past the top undoes the preview and selects nothing
    set_line("▽ぷらぐ")
    autoconfirm.on_select(fake_list({ is_explicitly_selected = true }), nil)
    expect.equality(autoconfirm.on_hide(), false)
    flush()
    expect.equality(#calls, 0)
  end)
end

T["attach"] = new_set()

T["attach"]["is skipped when blink.cmp is unavailable"] = function()
  local saved = package.loaded["blink.cmp.completion.list"]
  local saved_loader = package.preload["blink.cmp.completion.list"]
  package.loaded["blink.cmp.completion.list"] = nil
  package.preload["blink.cmp.completion.list"] = function()
    error("blink.cmp is not installed")
  end
  local ok, attached = pcall(autoconfirm.attach)
  package.loaded["blink.cmp.completion.list"] = saved
  package.preload["blink.cmp.completion.list"] = saved_loader
  expect.equality(ok, true)
  expect.equality(attached, false)
end

T["setup"] = new_set()

T["setup"]["defers attaching until skkeleton is about to be enabled"] = function()
  local saved = autoconfirm.attach
  local count = 0
  autoconfirm.attach = function()
    count = count + 1
    return true
  end
  autoconfirm.setup()
  expect.equality(count, 0)
  vim.api.nvim_exec_autocmds("User", { pattern = "skkeleton-enable-pre" })
  expect.equality(count, 1)
  -- The autocmd is `once`, so a second enable does not attach again
  vim.api.nvim_exec_autocmds("User", { pattern = "skkeleton-enable-pre" })
  expect.equality(count, 1)
  autoconfirm.attach = saved
end

T["setup"]["does not pile up autocmds when called twice"] = function()
  local saved = autoconfirm.attach
  local count = 0
  autoconfirm.attach = function()
    count = count + 1
    return true
  end
  autoconfirm.setup()
  autoconfirm.setup()
  vim.api.nvim_exec_autocmds("User", { pattern = "skkeleton-enable-pre" })
  expect.equality(count, 1)
  autoconfirm.attach = saved
end

return T
