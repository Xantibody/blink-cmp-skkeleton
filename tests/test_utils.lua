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

return T
