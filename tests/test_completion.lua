--- Tests for blink-cmp-skkeleton.completion module
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local completion = require("blink-cmp-skkeleton.completion")

local T = new_set()

-- convert_ranks_to_map tests
T["convert_ranks_to_map"] = new_set()

T["convert_ranks_to_map"]["converts empty array"] = function()
  local result = completion.convert_ranks_to_map({})
  expect.equality(type(result), "table")
  expect.equality(next(result), nil) -- empty table
end

T["convert_ranks_to_map"]["converts ranks array to map"] = function()
  local ranks_array = {
    { "愛", 100 },
    { "藍", 50 },
  }
  local result = completion.convert_ranks_to_map(ranks_array)
  expect.equality(result["愛"], 100)
  expect.equality(result["藍"], 50)
end

T["convert_ranks_to_map"]["handles invalid entries"] = function()
  local ranks_array = {
    { "愛", 100 },
    { nil, 50 }, -- invalid
    { "藍" }, -- missing rank
  }
  local result = completion.convert_ranks_to_map(ranks_array)
  expect.equality(result["愛"], 100)
  expect.equality(result["藍"], nil)
end

-- build_text_edit_range tests
T["build_text_edit_range"] = new_set()

T["build_text_edit_range"]["calculates correct range for ASCII"] = function()
  local context = {
    cursor = { 1, 5 }, -- line 1, column 5
  }
  local pre_edit = "test"
  local result = completion.build_text_edit_range(context, pre_edit)

  expect.equality(result.start.line, 0) -- LSP 0-indexed
  expect.equality(result.start.character, 1) -- 5 - 4 bytes
  expect.equality(result["end"].line, 0)
  expect.equality(result["end"].character, 5)
end

T["build_text_edit_range"]["calculates correct range for multibyte"] = function()
  local context = {
    cursor = { 1, 9 }, -- line 1, column 9
  }
  local pre_edit = "▽あい" -- 3 + 3 + 3 = 9 bytes
  local result = completion.build_text_edit_range(context, pre_edit)

  expect.equality(result.start.line, 0)
  expect.equality(result.start.character, 0) -- 9 - 9 bytes
  expect.equality(result["end"].line, 0)
  expect.equality(result["end"].character, 9)
end

-- build_completion_item tests
T["build_completion_item"] = new_set()

T["build_completion_item"]["creates item without documentation"] = function()
  local text_edit_range = {
    start = { line = 0, character = 0 },
    ["end"] = { line = 0, character = 5 },
  }
  local item = completion.build_completion_item("あい", "愛", 100, text_edit_range)

  expect.equality(item.label, "愛")
  expect.equality(item.filterText, "あい")
  expect.equality(item.textEdit.newText, "愛")
  expect.equality(item.data.kana, "あい")
  expect.equality(item.data.word, "愛")
  expect.equality(item.data.rank, 100)
  expect.equality(item.documentation, nil)
end

T["build_completion_item"]["creates item with documentation"] = function()
  local text_edit_range = {
    start = { line = 0, character = 0 },
    ["end"] = { line = 0, character = 5 },
  }
  local item = completion.build_completion_item("あい", "藍;indigo", 50, text_edit_range)

  expect.equality(item.label, "藍")
  expect.no_equality(item.documentation, nil)
  expect.equality(item.documentation.kind, "plaintext")
  expect.equality(item.documentation.value, "indigo")
end

-- build_completion_items tests
T["build_completion_items"] = new_set()

T["build_completion_items"]["builds items from candidates"] = function()
  local candidates = {
    { "あい", { "愛", "藍;indigo" } },
  }
  local ranks = { ["愛"] = 100 }
  local text_edit_range = {
    start = { line = 0, character = 0 },
    ["end"] = { line = 0, character = 9 },
  }

  local items = completion.build_completion_items(candidates, ranks, text_edit_range)

  expect.equality(#items, 2)
  expect.equality(items[1].label, "愛") -- Higher rank comes first
  expect.equality(items[2].label, "藍")
end

T["build_completion_items"]["sorts by rank"] = function()
  local candidates = {
    { "あい", { "愛", "藍", "哀" } },
  }
  local ranks = {
    ["愛"] = 100,
    ["哀"] = 50,
    -- 藍 has no rank, gets global rank
  }
  local text_edit_range = {
    start = { line = 0, character = 0 },
    ["end"] = { line = 0, character = 9 },
  }

  local items = completion.build_completion_items(candidates, ranks, text_edit_range)

  expect.equality(#items, 3)
  expect.equality(items[1].label, "愛") -- rank 100
  expect.equality(items[2].label, "哀") -- rank 50
  expect.equality(items[3].label, "藍") -- global rank -1
end

return T
