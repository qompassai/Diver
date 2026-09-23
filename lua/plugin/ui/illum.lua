-- /qompassai/Diver/lua/plugins/ui/illum.lua
-- Qompass AI Illum Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    'RRethy/vim-illuminate',
    opts = {
        delay = 200,
        large_file_cutoff = 2000,
        large_file_overrides = {
            providers = { 'lsp', 'treesitter', 'regex' },
        },
    },
    config = function(_, opts)
        require('illuminate').configure(opts)
    end,
}
