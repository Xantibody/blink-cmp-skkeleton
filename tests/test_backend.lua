--- Tests for blink-cmp-skkeleton.backend module
--- Run with: just test

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local backend = require("blink-cmp-skkeleton.backend")

--- Replace `require("blink.cmp")` with a stub for the duration of `fn`
--- @param stub table|nil nil to simulate blink.cmp being unavailable
--- @param fn fun()
local function with_blink_cmp(stub, fn)
  local saved = package.loaded["blink.cmp"]
  local saved_loader = package.preload["blink.cmp"]
  package.loaded["blink.cmp"] = stub
  if stub == nil then
    -- Stop require() from finding the real module on the runtimepath
    package.preload["blink.cmp"] = function()
      error("blink.cmp is not installed")
    end
  end
  local ok, err = pcall(fn)
  package.loaded["blink.cmp"] = saved
  package.preload["blink.cmp"] = saved_loader
  if not ok then
    error(err)
  end
end

local T = new_set()

T["complete_info"] = new_set()

T["complete_info"]["reports not visible when blink.cmp is unavailable"] = function()
  with_blink_cmp(nil, function()
    local info = backend.complete_info()
    expect.equality(info.pum_visible, false)
    expect.equality(info.selected, -1)
  end)
end

T["complete_info"]["reports not visible when the menu is closed"] = function()
  with_blink_cmp({
    is_menu_visible = function()
      return false
    end,
    get_selected_item = function()
      return nil
    end,
  }, function()
    local info = backend.complete_info()
    expect.equality(info.pum_visible, false)
    expect.equality(info.selected, -1)
  end)
end

T["complete_info"]["reports no selection while the menu is open"] = function()
  with_blink_cmp({
    is_menu_visible = function()
      return true
    end,
    get_selected_item = function()
      return nil
    end,
  }, function()
    local info = backend.complete_info()
    expect.equality(info.pum_visible, true)
    expect.equality(info.selected, -1)
  end)
end

T["complete_info"]["reports a selection while the menu is open"] = function()
  with_blink_cmp({
    is_menu_visible = function()
      return true
    end,
    get_selected_item = function()
      return { label = "愛" }
    end,
  }, function()
    local info = backend.complete_info()
    expect.equality(info.pum_visible, true)
    expect.equality(info.selected, 1)
  end)
end

--- Replace `vim.fn` with a stub that pretends skkeleton's API does (not) exist.
--- Autoload functions cannot be defined outside their own script (E746), so
--- the registration call itself has to be intercepted on the Lua side. When
--- `available` is false the key is simply absent, so the call falls through to
--- the real `vim.fn` and raises E117 just like an uninstalled skkeleton would.
--- @param available boolean
--- @param fn fun(captured: table)
local function with_skkeleton_api(available, fn)
  local api = "skkeleton#register_completion_backend"
  local saved = vim.fn
  local captured = {}
  local stub = {}
  captured.count = 0
  if available then
    stub[api] = function(name, definition)
      captured.count = captured.count + 1
      captured.name = name
      captured.definition = definition
    end
  end
  vim.fn = setmetatable(stub, { __index = saved })
  local ok, err = pcall(fn, captured)
  vim.fn = saved
  if not ok then
    error(err)
  end
end

T["register"] = new_set()

T["register"]["is skipped when skkeleton lacks the API"] = function()
  with_skkeleton_api(false, function(captured)
    expect.equality(backend.register(), false)
    expect.equality(captured.name, nil)
  end)
end

T["register"]["passes the backend definition to skkeleton"] = function()
  with_skkeleton_api(true, function(captured)
    with_blink_cmp({
      is_menu_visible = function()
        return true
      end,
      get_selected_item = function()
        return { label = "藍" }
      end,
    }, function()
      expect.equality(backend.register(), true)
      expect.equality(captured.name, "blink.cmp")
      expect.equality(captured.definition.confirm_key, "<Cmd>lua require('blink.cmp').select_and_accept()")
      local info = captured.definition.complete_info()
      expect.equality(info.pum_visible, true)
      expect.equality(info.selected, 1)
    end)
  end)
end

T["setup"] = new_set({
  hooks = {
    post_case = function()
      pcall(vim.api.nvim_del_augroup_by_name, "blink-cmp-skkeleton-backend")
    end,
  },
})

T["setup"]["registers once from skkeleton-enable-pre"] = function()
  with_skkeleton_api(true, function(captured)
    backend.setup()
    -- Nothing happens until skkeleton is about to be enabled
    expect.equality(captured.count, 0)
    vim.api.nvim_exec_autocmds("User", { pattern = "skkeleton-enable-pre" })
    expect.equality(captured.count, 1)
    expect.equality(captured.name, "blink.cmp")
    -- The autocmd is `once`, so a second enable does not register again
    vim.api.nvim_exec_autocmds("User", { pattern = "skkeleton-enable-pre" })
    expect.equality(captured.count, 1)
  end)
end

T["setup"]["does not pile up autocmds when called twice"] = function()
  with_skkeleton_api(true, function(captured)
    backend.setup()
    backend.setup()
    vim.api.nvim_exec_autocmds("User", { pattern = "skkeleton-enable-pre" })
    expect.equality(captured.count, 1)
  end)
end

T["register"]["hands skkeleton a definition Vim script can call"] = function()
  -- skkeleton stores `complete_info` in a Vim script dictionary and calls it on
  -- every key press, so the Lua function has to survive the conversion into a
  -- |Funcref|. Use a plain global function since autoload names are rejected
  -- outside their script (E746).
  vim.cmd([[
    function! g:BlinkCmpSkkeletonTestRegister(name, backend) abort
      let g:blink_cmp_skkeleton_test_backend = #{
      \   is_func: type(a:backend.complete_info) == v:t_func,
      \   info: a:backend.complete_info(),
      \ }
    endfunction
  ]])

  with_blink_cmp({
    is_menu_visible = function()
      return true
    end,
    get_selected_item = function()
      return { label = "藍" }
    end,
  }, function()
    vim.fn.BlinkCmpSkkeletonTestRegister(backend.name, {
      complete_info = backend.complete_info,
      confirm_key = "<Cmd>lua require('blink.cmp').select_and_accept()",
    })
  end)

  local got = vim.g.blink_cmp_skkeleton_test_backend
  expect.equality(got.is_func, 1)
  expect.equality(got.info.pum_visible, true)
  expect.equality(got.info.selected, 1)

  vim.cmd("delfunction g:BlinkCmpSkkeletonTestRegister")
  vim.g.blink_cmp_skkeleton_test_backend = nil
end

return T
