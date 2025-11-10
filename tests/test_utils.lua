--- Tests for blink-cmp-skkeleton.utils module
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local utils = require("blink-cmp-skkeleton.utils")

local T = new_set()

-- parse_word tests
T["parse_word"] = new_set()

T["parse_word"]["extracts label from word without info"] = function()
  local label, info = utils.parse_word("愛")
  expect.equality(label, "愛")
  expect.equality(info, "")
end

T["parse_word"]["extracts label and info from word with semicolon"] = function()
  local label, info = utils.parse_word("藍;indigo")
  expect.equality(label, "藍")
  expect.equality(info, "indigo")
end

T["parse_word"]["handles multiple semicolons"] = function()
  local label, info = utils.parse_word("愛;love;affection")
  expect.equality(label, "愛")
  expect.equality(info, "affection") -- Only last part after final semicolon
end

-- determine_henkan_type tests
T["determine_henkan_type"] = new_set()

T["determine_henkan_type"]["returns okurinasi for hiragana only"] = function()
  local result = utils.determine_henkan_type("あい")
  expect.equality(result, "okurinasi")
end

T["determine_henkan_type"]["returns okuriari for uppercase letter"] = function()
  local result = utils.determine_henkan_type("おくR")
  expect.equality(result, "okuriari")
end

T["determine_henkan_type"]["returns okuriari for asterisk"] = function()
  local result = utils.determine_henkan_type("おく*り")
  expect.equality(result, "okuriari")
end

T["determine_henkan_type"]["returns okuriari for multiple uppercase"] = function()
  local result = utils.determine_henkan_type("おくRiNa")
  expect.equality(result, "okuriari")
end

-- safe_call tests
T["safe_call"] = new_set()

T["safe_call"]["returns result on success"] = function()
  local fn = function()
    return "success"
  end
  local result = utils.safe_call(fn)
  expect.equality(result, "success")
end

T["safe_call"]["returns nil on error"] = function()
  local fn = function()
    error("test error")
  end
  local result = utils.safe_call(fn)
  expect.equality(result, nil)
end

T["safe_call"]["returns nil for nil function"] = function()
  local result = utils.safe_call(nil)
  expect.equality(result, nil)
end

T["safe_call"]["passes arguments to function"] = function()
  local fn = function(a, b)
    return a + b
  end
  local result = utils.safe_call(fn, 2, 3)
  expect.equality(result, 5)
end

-- Japanese trigger character generation tests
T["generate_hiragana_triggers"] = new_set()

T["generate_hiragana_triggers"]["generates all basic hiragana characters"] = function()
  local triggers = utils.generate_hiragana_triggers()
  -- Should include basic hiragana
  expect.truthy(vim.tbl_contains(triggers, "あ"))
  expect.truthy(vim.tbl_contains(triggers, "い"))
  expect.truthy(vim.tbl_contains(triggers, "ん"))
end

T["generate_hiragana_triggers"]["includes hiragana marks"] = function()
  local triggers = utils.generate_hiragana_triggers()
  -- Should include marks
  expect.truthy(vim.tbl_contains(triggers, "゛")) -- U+309B
  expect.truthy(vim.tbl_contains(triggers, "゜")) -- U+309C
  expect.truthy(vim.tbl_contains(triggers, "ー")) -- U+30FC (long vowel mark)
end

T["generate_hiragana_triggers"]["generates correct number of characters"] = function()
  local triggers = utils.generate_hiragana_triggers()
  -- Basic hiragana (U+3041-U+3093): 83 chars
  -- Marks (U+309B-U+309E): 4 chars
  -- Long vowel (U+30FC): 1 char
  -- Total: ~88 chars
  expect.truthy(#triggers >= 85 and #triggers <= 90)
end

T["generate_katakana_triggers"] = new_set()

T["generate_katakana_triggers"]["generates all basic katakana characters"] = function()
  local triggers = utils.generate_katakana_triggers()
  -- Should include basic katakana
  expect.truthy(vim.tbl_contains(triggers, "ア"))
  expect.truthy(vim.tbl_contains(triggers, "イ"))
  expect.truthy(vim.tbl_contains(triggers, "ン"))
end

T["generate_katakana_triggers"]["includes katakana marks"] = function()
  local triggers = utils.generate_katakana_triggers()
  -- Should include marks
  expect.truthy(vim.tbl_contains(triggers, "・")) -- U+30FB
end

T["generate_katakana_triggers"]["generates correct number of characters"] = function()
  local triggers = utils.generate_katakana_triggers()
  -- Basic katakana (U+30A1-U+30F4): 84 chars
  -- Marks (U+30FB-U+30FE): 4 chars
  -- Total: ~88 chars
  expect.truthy(#triggers >= 85 and #triggers <= 90)
end

T["generate_japanese_triggers"] = new_set()

T["generate_japanese_triggers"]["combines hiragana and katakana"] = function()
  local triggers = utils.generate_japanese_triggers()
  -- Should include both hiragana and katakana
  expect.truthy(vim.tbl_contains(triggers, "あ"))
  expect.truthy(vim.tbl_contains(triggers, "ア"))
  expect.truthy(vim.tbl_contains(triggers, "ん"))
  expect.truthy(vim.tbl_contains(triggers, "ン"))
end

T["generate_japanese_triggers"]["generates approximately 174 characters"] = function()
  local triggers = utils.generate_japanese_triggers()
  -- Hiragana (~88) + Katakana (~88) = ~176 chars
  expect.truthy(#triggers >= 170 and #triggers <= 180)
end

return T
