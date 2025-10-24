--- Minimal init for running tests with mini.test

-- Add current plugin directory to runtime path
vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- Add mini.nvim to the runtime path
local mini_path = vim.fn.getcwd() .. "/.deps/mini.nvim"
if vim.fn.isdirectory(mini_path) == 1 then
  vim.opt.runtimepath:append(mini_path)
else
  print("Warning: mini.nvim not found at " .. mini_path)
  print("Install it with: just deps-mini-nvim")
  vim.cmd("cquit 1")
end

-- Set up mini.test
require("mini.test").setup()

-- Mock LSP protocol if not available
if not vim.lsp or not vim.lsp.protocol then
  vim = vim or {}
  vim.lsp = vim.lsp or {}
  vim.lsp.protocol = vim.lsp.protocol or {}
  vim.lsp.protocol.CompletionItemKind = {
    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
  }
end
