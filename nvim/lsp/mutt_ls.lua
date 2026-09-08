-- /qompassai/Diver/lsp/mutt_ls.lua
-- Qompass AI  Mutt LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'mutt-language-server',
        '--color=always',
    },
    filetypes = { ---@type string[]
        'muttrc',
        'neomuttrc',
    },
    root_markers = { ---@type string[]
        '.git',
        '.mutt',
        '.neomutt',
        '.config/mutt',
        '.config/neomutt',
    },
}
