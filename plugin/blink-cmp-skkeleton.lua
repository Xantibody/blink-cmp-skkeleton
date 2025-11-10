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
      if vim.g.blink_cmp_skkeleton_debug then
        vim.notify("[blink-cmp-skkeleton] skkeleton-enable-pre: calling blink_cmp.show()", vim.log.levels.DEBUG)
      end
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
      if vim.g.blink_cmp_skkeleton_debug then
        -- Get current line and cursor position for debugging
        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local char_before_cursor = col > 0 and line:sub(col, col) or ""
        vim.notify(
          string.format(
            "[blink-cmp-skkeleton] TextChangedI: line='%s', col=%d, char_before='%s', calling blink_cmp.show()",
            line,
            col,
            char_before_cursor
          ),
          vim.log.levels.DEBUG
        )
      end
      vim.schedule(function()
        blink_cmp.show()
      end)
    end
  end,
  desc = "Show blink.cmp when text changes while skkeleton is enabled",
})
