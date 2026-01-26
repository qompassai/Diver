-- /qompassai/Diver/lua/config/ui/illuminate.lua
-- Qompass AI Diver Illuminate Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
require('illuminate').configure({
    providers = {
        'lsp',
        'treesitter',
        'regex',
    },
    delay = 100,
    filetype_overrides = {},
    filetypes_denylist = {
        'dirbuf',
        'dirvish',
        'fugitive',
    },
    filetypes_allowlist = {},
    modes_denylist = {},
    modes_allowlist = {},
    providers_regex_syntax_denylist = {},
    providers_regex_syntax_allowlist = {},
    under_cursor = true,
    large_file_cutoff = 10000,
    large_file_overrides = nil,
    min_count_to_highlight = 1,
    should_enable = function()
        return true
    end,
    case_insensitive_regex = true,
    disable_keymaps = false,
})
return M