local lspmap = {}

local map = vim.keymap.set
local bufopts = { noremap = true, silent = true }

-- Nerd Translate Legend:
--
-- 'LSP': Language Server Protocol, an intelligence tool providing auto-completion and error checking
-- 'null-ls': A tool that brings additional LSP-like features to Neovim
-- 'diagnostics': Information about potential problems or errors in your code
-- 'Mason': A package manager for Neovim that helps install and manage LSP servers and other tools
-- 'source': In this context, a tool or service that provides code analysis or formatting
-- 'package': A software bundle that can be installed and managed by Mason

-- nabla.nvim mappings
map(
  "n",
  "<leader>qm",
  ':lua require("nabla").toggle_virt()<CR>',
  vim.tbl_extend("force", bufopts, { desc = "toggle [m]ath equations" })
)
-- In normal mode, press 'Space' + 'Toggle LaTeX math equations in Markdown .

-- Mason LSP diagnostics toggling
map("n", "<leader>ml", function()
  local clients = vim.lsp.get_clients()
  if #clients > 0 then
    vim.diagnostic.enable(false)
    for _, client in ipairs(clients) do
      client.stop()
    end
    print "LSP diagnostics disabled"
  else
    vim.diagnostic.enable()
    vim.cmd "LspStart"
    print "LSP diagnostics enabled"
  end
end, { desc = "Toggle LSP diagnostics" })
-- In normal mode, press 'Space' + 'm' + 'l' to toggle LSP diagnostics on or off

-- The following code sets up mappings between null-ls sources and Mason packages
local _ = require "mason-core.functional"
local Optional = require "mason-core.optional"

local null_ls_to_package = {
  ["cmake_lint"] = "cmakelint",
  ["cmake_format"] = "cmakelang",
  ["eslint_d"] = "eslint_d",
  ["goimports_reviser"] = "goimports_reviser",
  ["phpcsfixer"] = "php-cs-fixer",
  ["verible_verilog_format"] = "verible",
  ["lua_format"] = "luaformatter",
  ["ansiblelint"] = "ansible-lint",
  ["deno_fmt"] = "deno",
  ["ruff_format"] = "ruff",
  ["xmlformat"] = "xmlformatter",
}

local package_to_null_ls = _.invert(null_ls_to_package)

-- Function to get Mason package name from null-ls source name
lspmap.getPackageFromNullLs = _.memoize(function(source)
  return Optional.of_nilable(null_ls_to_package[source]):or_else_get(_.always(source:gsub("%_", "-")))
end)

-- Function to get null-ls source name from Mason package name
lspmap.getNullLsFromPackage = _.memoize(function(package)
  return Optional.of_nilable(package_to_null_ls[package]):or_else_get(_.always(package:gsub("%-", "_")))
end)

return lspmap
