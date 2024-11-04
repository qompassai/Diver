local lspmap = {}
local map = vim.keymap.set
local opts = { noremap = true, silent = true }


-- Nerd Translate Legend:
--
-- 'LSP': Language Server Protocol, an intelligence tool providing auto-completion and error checking
-- 'null-ls': A tool that brings additional LSP-like features to Neovim
-- 'diagnostics': Information about potential problems or errors in your code
-- 'Mason': A package manager for Neovim that helps install and manage LSP servers and other tools
-- 'source': In this context, a tool or service that provides code analysis or formatting
-- 'package': A software bundle that can be installed and managed by Mason

-- nabla.nvim mappings
-- Nabla toggle math equations
map(
  "n",
  "<leader>jm",
  ':lua require("nabla").toggle_virt()<CR>',
  vim.tbl_extend("force", opts, { desc = "Nabla toggle [m]ath equations" })
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
    print "Mason LSP diagnostics disabled"
  else
    vim.diagnostic.enable()
    vim.cmd "LspStart"
    print "LSP diagnostics enabled"
  end
end, { desc = "Mason Toggle LSP diagnostics" })
-- In normal mode, press 'Space' + 'm' + 'l' to toggle LSP diagnostics on or off

local _ = require "mason-core.functional"
local Optional = require "mason-core.optional"

local null_ls_to_package = {
  ["cmake_lint"] = "cmakelint",
  ["cmake_format"] = "cmakelang",
  ["eslint_d"] = "eslint_d",
  ["goimports_reviser"] = "goimports_reviser",
  ["phpcsfixer"] = "php-cs-fixer",
  ["verible_verilog_format"] = "verible",
  ["lua_format"] = "lua_ls",
  ["ansiblelint"] = "ansible-lint",
  ["deno_fmt"] = "deno",
  ["ruff_format"] = "ruff",
  ["xmlformat"] = "xmlformatter",
}

local package_to_null_ls = _.invert(null_ls_to_package)

lspmap.getPackageFromNullLs = _.memoize(function(source)
  return Optional.of_nilable(null_ls_to_package[source]):or_else_get(_.always(source:gsub("%_", "-")))
end)

lspmap.getNullLsFromPackage = _.memoize(function(package)
  return Optional.of_nilable(package_to_null_ls[package]):or_else_get(_.always(package:gsub("%-", "_")))
end)

local attach_enabled = false

local function toggle_null_ls()
    attach_enabled = not attach_enabled
    if attach_enabled then
        require("null-ls").enable({})
        vim.notify("null-ls enabled", vim.log.levels.INFO)
    else
        require("null-ls").disable({})
        vim.notify("null-ls disabled", vim.log.levels.INFO)
    end
end

map("n", "<leader>ln", toggle_null_ls, {
    desc = "Toggle null-ls",
    silent = true,
    noremap = true
})

map("n", "<leader>lf", function()
    if attach_enabled then
        require("null-ls").enable({ filter = function(source)
            return source.method == require("null-ls").methods.FORMATTING
        end})
        vim.notify("null-ls formatters enabled", vim.log.levels.INFO)
    end
end, { desc = "Toggle null-ls formatters" })

map("n", "<leader>ld", function()
    if attach_enabled then
        require("null-ls").enable({ filter = function(source)
            return source.method == require("null-ls").methods.DIAGNOSTICS
        end})
        vim.notify("null-ls diagnostics enabled", vim.log.levels.INFO)
    end
end, { desc = "Toggle null-ls diagnostics" })
return lspmap
