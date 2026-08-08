--- Completion backend registration for skkeleton
---
--- skkeleton needs to know which completion engine is currently showing
--- candidates so that `eggLikeNewline` can confirm the selected item with
--- `<CR>`. Since skkeleton no longer auto-detects the engine, it exposes
--- `skkeleton#register_completion_backend()` and lets the user pick one by
--- name via `completionBackend`. We register the blink.cmp definition here so
--- users only have to write:
---
---     call skkeleton#config(#{ completionBackend: 'blink.cmp' })
---
--- Registering is a no-op for users who do not select this backend, and it is
--- silently skipped when the installed skkeleton predates the API.
--- @module blink-cmp-skkeleton.backend

local utils = require("blink-cmp-skkeleton.utils")

local M = {}

--- Name to be given to |skkeleton-config-completionBackend|
M.name = "blink.cmp"

--- Report the state of blink.cmp's completion menu to skkeleton.
--- `selected` follows skkeleton's convention: a negative value means no
--- candidate is selected.
--- @return { pum_visible: boolean, selected: integer }
function M.complete_info()
  local ok, blink_cmp = pcall(require, "blink.cmp")
  if not ok or not blink_cmp.is_menu_visible() then
    return { pum_visible = false, selected = -1 }
  end
  return {
    pum_visible = true,
    selected = blink_cmp.get_selected_item() ~= nil and 1 or -1,
  }
end

--- Register the blink.cmp backend with skkeleton, unconditionally.
--- Calling the function is what pulls in skkeleton's autoload script, so this
--- works without checking `exists()` first.
--- @return boolean registered false when skkeleton lacks the API
function M.register()
  local ok, err = pcall(vim.fn["skkeleton#register_completion_backend"], M.name, {
    complete_info = M.complete_info,
    confirm_key = "<Cmd>lua require('blink.cmp').select_and_accept()",
  })
  if not ok then
    utils.debug_log("skkeleton#register_completion_backend() failed, skipped: " .. tostring(err))
    return false
  end
  utils.debug_log("registered completion backend: " .. M.name)
  return true
end

--- Register the backend once skkeleton is about to be enabled.
--- This is the point skkeleton documents for setting itself up, and it is early
--- enough: skkeleton only consults the backend while a completion menu is open.
function M.setup()
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("blink-cmp-skkeleton-backend", { clear = true }),
    pattern = "skkeleton-enable-pre",
    once = true,
    callback = M.register,
    desc = "Register blink.cmp as a skkeleton completion backend",
  })
end

return M
