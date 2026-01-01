-- next_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'nextls', '--stdio' },
    filetypes = { 'elixir', 'eelixir', 'heex', 'surface' },
    root_markers = { 'mix.exs', '.git' },
}
