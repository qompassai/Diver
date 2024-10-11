local M = {}

-- Import each mapping module
M.buffmap = require("mappings.buffmap")
M.ensure_installed = require("mappings.ensure_installed")
M.format = require("mappings.format")
M.genmap = require("mappings.genmap")
M.jupymap = require("mappings.jupymap")
M.langmap = require("mappings.langmap")
M.lsp = require("mappings.lsp")
M.rustmap = require("mappings.rustmap")
M.settings = require("mappings.settings")
M.source = require("mappings.source")
vim.api.nvim_set_keymap('n', '<leader>th', '<cmd>Telescope colorscheme<CR>', { noremap = true, silent = true })

-- Automatically load/setup necessary mappings
M.automatic_setup = require("mappings.automatic_setup")

-- Return the module table to be used in other configurations
return M

