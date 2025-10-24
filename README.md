# blink-cmp-skkeleton

Native [blink.cmp](https://github.com/saghen/blink.cmp) source for [skkeleton](https://github.com/vim-skk/skkeleton) (Japanese SKK input method).

## Features

- ✅ Native blink.cmp integration (no `blink.compat` required)
- ✅ Dynamic source switching (only shows when skkeleton is active)
- ✅ Fuzzy matching support for Japanese characters
- ✅ Dictionary learning for both okurinasi and okuriari
- ✅ Proper pre-edit text replacement
- ✅ Comprehensive test suite

## Requirements

- Neovim >= 0.10
- [blink.cmp](https://github.com/saghen/blink.cmp)
- [skkeleton](https://github.com/vim-skk/skkeleton)
- [denops.vim](https://github.com/vim-denops/denops.vim)
- [Deno](https://deno.land/) (for denops)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "saghen/blink.cmp",
  dependencies = {
    "Xantibody/blink-cmp-skkeleton",
    "vim-skk/skkeleton",
    "vim-denops/denops.vim",
  },
  opts = {
    keymap = {
      preset = "super-tab",
      -- Don't use Space for completion - let skkeleton handle it
      ["<Space>"] = {},
    },
    sources = {
      -- Dynamically select sources based on skkeleton state
      default = function(ctx)
        local ok, result = pcall(vim.fn["skkeleton#is_enabled"])
        local skkeleton_enabled = ok and (result == true or result == 1)

        if skkeleton_enabled then
          return { "skkeleton" }
        else
          return { "lsp", "path", "snippets", "buffer" }
        end
      end,
      providers = {
        skkeleton = {
          name = "skkeleton",
          module = "blink-cmp-skkeleton",
          score_offset = 100,
          min_keyword_length = 0,
        },
      },
    },
  },
}
```

### Skkeleton Configuration

Configure skkeleton to work with blink.cmp:

```lua
{
  "vim-skk/skkeleton",
  dependencies = { "vim-denops/denops.vim" },
  config = function()
    vim.fn["skkeleton#config"]({
      eggLikeNewline = true,
      registerConvertResult = true,
      sources = { "skk_server" },
      showCandidatesCount = 999, -- Prevent auto-conversion
    })

    -- Key mappings
    vim.keymap.set("i", "<C-j>", "<Plug>(skkeleton-enable)")
    vim.keymap.set("c", "<C-j>", "<Plug>(skkeleton-enable)")

    -- Integration with blink.cmp
    vim.api.nvim_create_autocmd("User", {
      pattern = "skkeleton-enable-pre",
      callback = function()
        local ok, blink_cmp = pcall(require, "blink.cmp")
        if ok then
          vim.schedule(function() blink_cmp.show() end)
        end
      end,
    })

    vim.api.nvim_create_autocmd("TextChangedI", {
      callback = function()
        if vim.fn.exists("*skkeleton#is_enabled") == 0 then return end
        if vim.fn["skkeleton#is_enabled"]() ~= 1 then return end

        local ok, blink_cmp = pcall(require, "blink.cmp")
        if ok then
          vim.schedule(function() blink_cmp.show() end)
        end
      end,
    })
  end,
}
```

## Usage

1. Enable skkeleton: `<C-j>` (or your configured key)
2. Type Japanese in hiragana (e.g., "あいざわ")
3. Completion candidates appear automatically
4. Select with `Tab` or `Enter` to confirm
5. For okurigana conversion, use `Space` for traditional SKK behavior

## Key Bindings

| Key | Action |
|-----|--------|
| `Tab` / `Enter` | Accept completion |
| `Space` | SKK conversion (for okurigana) |
| `<C-j>` | Toggle skkeleton (default) |

## Conversion Types

### Okurinasi (送りなし変換)

Type: `▽あいざわ`

- Completion window shows multiple candidates
- Select with Tab/Enter
- Automatically registered to dictionary

### Okuriari (送りあり変換)

Type: `▽おくr` → `▽おく*り`

- Uses traditional SKK space-key conversion
- Completion window doesn't appear (by skkeleton's design)
- Automatically registered to dictionary with okuriari type

> **Note**: Okurigana conversion doesn't show the completion window due to skkeleton's internal state management. This is the same behavior as the official ddc.vim source.

## Architecture

### Module Structure

```
lua/blink-cmp-skkeleton/
└── init.lua          # Main source implementation
```

### Helper Functions

- `safe_call()`: Safely call vim functions with error handling
- `request()`: Request data from skkeleton via denops
- `convert_ranks_to_map()`: Convert ranks array to lookup table
- `build_text_edit_range()`: Calculate LSP TextEdit range
- `parse_word()`: Extract label and info from word string
- `build_completion_item()`: Build a single completion item
- `build_completion_items()`: Build all completion items
- `determine_henkan_type()`: Detect okurinasi vs okuriari

### Source Methods

- `enabled()`: Check if skkeleton is available
- `get_trigger_characters()`: Return trigger characters (none)
- `get_completions()`: Fetch and build completion items
- `resolve()`: Resolve additional information (no-op)
- `execute()`: Handle completion confirmation and dictionary learning

## Implementation Notes

### Character Count vs Byte Position

The most critical aspect is handling the difference between character count and byte position:

- `pre_edit_len` from skkeleton: **Character count** (e.g., 5 for "▽あいざわ")
- `context.cursor[2]`: **Byte position** (e.g., 15 bytes for UTF-8 "▽あいざわ")

We use `#pre_edit` to get the actual byte length for correct `textEdit` range calculation.

### Fuzzy Matching

Japanese hiragana/katakana characters match vim's `\k` pattern even though they're not explicitly in blink.cmp's `iskeyword` setting. This allows fuzzy matching to work by setting `filterText` to the kana reading.

### Dictionary Learning

The plugin automatically detects the henkan type:

- Uppercase letters (e.g., "おくR") → okuriari
- Asterisk (e.g., "おく*り") → okuriari
- Otherwise → okurinasi

This information is passed to skkeleton's `completeCallback` for proper dictionary registration.

## Development

### Running Tests

Requirements: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

```bash
# Clone the repository
git clone https://github.com/Xantibody/blink-cmp-skkeleton
cd blink-cmp-skkeleton

# Run tests
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/" -c "qa"
```

### Test Coverage

- ✅ Source initialization
- ✅ Enabled/disabled states
- ✅ Completion item generation
- ✅ Okurinasi/okuriari detection
- ✅ Dictionary learning integration
- ✅ textEdit range calculation

## Comparison with Other Implementations

| Feature | ddc.vim source | cmp-skkeleton | blink-cmp-skkeleton |
|---------|----------------|---------------|---------------------|
| Okurinasi completion | ✅ | ✅ | ✅ |
| Okuriari completion | ❌ (by design) | ❌ (by design) | ❌ (by design) |
| Dictionary learning | ✅ | ✅ | ✅ |
| Ranking support | ✅ | ✅ | ✅ |
| Documentation display | ✅ | ✅ | ✅ |
| Native integration | ✅ (ddc) | ⚠️ (nvim-cmp) | ✅ (blink.cmp) |

## Troubleshooting

### Completion window doesn't appear

1. Check if skkeleton is enabled: `:echo skkeleton#is_enabled()`
2. Check if blink.cmp source is loaded: `:lua =require('blink.cmp').sources`
3. Enable debug logging in the source (set `DEBUG = true`)

### Text is garbled after completion

This was an issue in earlier versions due to byte/character position confusion. Update to the latest version.

### Space key doesn't work for conversion

Make sure you have `["<Space>"] = {}` in your blink.cmp keymap configuration to prevent blink.cmp from handling the Space key.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT

## Credits

Based on:
- [skkeleton ddc.vim source](https://github.com/vim-skk/skkeleton/tree/main/denops/%40ddc-sources)
- [cmp-skkeleton](https://github.com/uga-rosa/cmp-skkeleton)

## Author

[Xantibody](https://github.com/Xantibody)
