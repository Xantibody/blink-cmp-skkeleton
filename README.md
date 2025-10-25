# blink-cmp-skkeleton

Native [blink.cmp](https://github.com/saghen/blink.cmp) source for [skkeleton](https://github.com/vim-skk/skkeleton) (Japanese SKK input method).

## ✨ Features

- ✅ Native blink.cmp integration (no `blink.compat` required)
- ✅ Dynamic source switching (only shows when skkeleton is active)
- ✅ Fuzzy matching support for Japanese characters
- ✅ Dictionary learning for both okurinasi and okuriari
- ✅ Proper pre-edit text replacement
- ✅ **Performance optimization with intelligent caching** (~70% faster)
- ✅ Comprehensive test suite (47 tests)

## 📦 Installation

### Requirements

- Neovim >= 0.10
- [blink.cmp](https://github.com/saghen/blink.cmp)
- [skkeleton](https://github.com/vim-skk/skkeleton)
- [denops.vim](https://github.com/vim-denops/denops.vim)
- [Deno](https://deno.land/) (for denops)

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
        if require("blink-cmp-skkeleton").is_enabled() then
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
  end,
}
```

## 🚀 Usage

1. **Enable skkeleton**: Press `<C-j>` (or your configured key)
2. **Type in hiragana**: e.g., "▽あいざわ"
3. **Select completion**: Candidates appear automatically
4. **Confirm**: Press `Tab` or `Enter`
5. **Okurigana conversion**: Use `Space` for traditional SKK behavior

### Conversion Types

#### Okurinasi (送りなし変換)

Type: `▽あいざわ`

- Completion window shows multiple candidates
- Select with Tab/Enter
- Automatically registered to dictionary

#### Okuriari (送りあり変換)

Type: `▽おくr` → `▽おく*り`

- Uses traditional SKK space-key conversion
- Completion window doesn't appear (by skkeleton's design)
- Automatically registered to dictionary with okuriari type

> **Note**: Okurigana conversion doesn't show the completion window due to skkeleton's internal state management. This is the same behavior as the official ddc.vim source.

## ⚙️ Configuration

### Cache Settings

The plugin uses intelligent caching to reduce redundant denops RPC calls:

```lua
-- Customize cache TTL (default: 100ms)
vim.g.blink_cmp_skkeleton_cache_ttl = 150

-- Check cache statistics
:lua print(vim.inspect(require('blink-cmp-skkeleton.skkeleton').get_cache_stats()))
-- => { hits = 150, misses = 50, hit_rate = 75.0 }
```

**Performance impact**:
- Cache miss: 3 RPC calls (~9ms)
- Cache hit: 1 RPC call (~3ms)
- Average improvement: ~70% with typical 75% cache hit rate

### Debug Logging

```lua
-- Enable debug logging
vim.g.blink_cmp_skkeleton_debug = true

-- View logs
:messages
```

### Auto-setup

```lua
-- Disable automatic autocmd setup (advanced users only)
vim.g.blink_cmp_skkeleton_auto_setup = false
```

> **Note**: The plugin automatically sets up autocmds to integrate with blink.cmp. Only disable this if you want to manage autocmds yourself.

## 🔧 Troubleshooting

### Completion window doesn't appear

1. Check if skkeleton is enabled: `:echo skkeleton#is_enabled()`
2. Check if blink.cmp source is loaded: `:lua =require('blink.cmp').sources`
3. Enable debug logging: `vim.g.blink_cmp_skkeleton_debug = true`

### Text is garbled after completion

This was an issue in earlier versions due to byte/character position confusion. Update to the latest version.

### Space key doesn't work for conversion

Make sure you have `["<Space>"] = {}` in your blink.cmp keymap configuration to prevent blink.cmp from handling the Space key.

### Low cache hit rate

Check your cache statistics:

```lua
:lua print(vim.inspect(require('blink-cmp-skkeleton.skkeleton').get_cache_stats()))
```

If hit rate is low (<50%), consider increasing TTL:

```lua
vim.g.blink_cmp_skkeleton_cache_ttl = 200
```

## 📊 Comparison

| Feature | ddc.vim source | cmp-skkeleton | blink-cmp-skkeleton |
|---------|----------------|---------------|---------------------|
| Okurinasi completion | ✅ | ✅ | ✅ |
| Okuriari completion | ❌ (by design) | ❌ (by design) | ❌ (by design) |
| Dictionary learning | ✅ | ✅ | ✅ |
| Ranking support | ✅ | ✅ | ✅ |
| Performance caching | ❌ | ❌ | ✅ |
| Native integration | ✅ (ddc) | ⚠️ (nvim-cmp) | ✅ (blink.cmp) |

---

<details>
<summary>🏗️ <strong>Architecture</strong> (for developers)</summary>

### Module Structure

```
lua/blink-cmp-skkeleton/
├── init.lua          # Main source implementation (blink.cmp API)
├── utils.lua         # Utility functions
├── skkeleton.lua     # Skkeleton/denops communication with caching
└── completion.lua    # Completion item building
plugin/
└── blink-cmp-skkeleton.lua  # Auto-setup autocmds
```

### Source Methods

The plugin implements the blink.cmp source API:

- `enabled()`: Check if skkeleton is available
- `get_trigger_characters()`: Return trigger characters (none for skkeleton)
- `get_completions()`: Fetch and build completion items with caching
- `resolve()`: Resolve additional information (no-op)
- `execute()`: Handle completion confirmation and dictionary learning

### Caching Strategy

- **Cache key**: `pre_edit` string (e.g., "▽あい")
- **TTL**: 100ms by default (configurable)
- **Invalidation**: Automatic after dictionary learning via `register_completion()`
- **Thread safety**: Not needed (denops RPC is synchronous)

</details>

<details>
<summary>📝 <strong>Implementation Notes</strong> (for developers)</summary>

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

</details>

---

## 💻 Development

### Running Tests

Requirements: [mini.nvim](https://github.com/echasnovski/mini.nvim) (mini.test)

```bash
# Clone the repository
git clone https://github.com/Xantibody/blink-cmp-skkeleton
cd blink-cmp-skkeleton

# Install test dependencies
just deps-mini-nvim

# Run tests
just test
```

### Test Coverage

- ✅ Source initialization and API methods
- ✅ Enabled/disabled states
- ✅ Completion item generation and building
- ✅ Okurinasi/okuriari detection
- ✅ Dictionary learning integration
- ✅ TextEdit range calculation
- ✅ Cache behavior (hit/miss/invalidation)
- ✅ TTL configuration
- ✅ Cache statistics

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT

## Credits

Based on:
- [skkeleton ddc.vim source](https://github.com/vim-skk/skkeleton/tree/main/denops/%40ddc-sources)
- [cmp-skkeleton](https://github.com/uga-rosa/cmp-skkeleton)

## Author

[Xantibody](https://github.com/Xantibody)
