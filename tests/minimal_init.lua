--- Minimal init for running tests
--- This sets up the minimal environment needed for testing

-- Add current plugin directory to runtime path
vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- Add plenary to the runtime path (for testing)
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:append(plenary_path)
else
  print("Warning: plenary.nvim not found at " .. plenary_path)
  print("Install it with: git clone https://github.com/nvim-lua/plenary.nvim " .. plenary_path)
end

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
