--- Auto-setup autocmds for blink.cmp integration with skkeleton
--- Set vim.g.blink_cmp_skkeleton_auto_setup = false to disable

-- Check if user wants to disable auto-setup
if vim.g.blink_cmp_skkeleton_auto_setup == false then
  return
end

-- Integration with blink.cmp
vim.api.nvim_create_autocmd("User", {
  pattern = "skkeleton-enable-pre",
  callback = function()
    local ok, blink_cmp = pcall(require, "blink.cmp")
    if ok then
      vim.schedule(function()
        blink_cmp.show()
      end)
    end
  end,
  desc = "Show blink.cmp when skkeleton is enabled",
})

vim.api.nvim_create_autocmd("TextChangedI", {
  callback = function()
    if vim.fn.exists("*skkeleton#is_enabled") == 0 then
      return
    end
    if vim.fn["skkeleton#is_enabled"]() ~= 1 then
      return
    end

    local ok, blink_cmp = pcall(require, "blink.cmp")
    if ok then
      vim.schedule(function()
        blink_cmp.show()
      end)
    end
  end,
  desc = "Show blink.cmp when text changes while skkeleton is enabled",
})

-- Sync keymap if enabled (opt-in, default: false)
if vim.g.blink_cmp_skkeleton_sync_keymap == true then
  vim.schedule(function()
    require("blink-cmp-skkeleton.keymaps").sync_to_skkeleton()
  end)
end
