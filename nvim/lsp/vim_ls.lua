-- /qompassai/Diver/lsp/vim_ls.lua
-- Qompass AI Vim LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/iamcco/vim-language-server
---@type vim.lsp.Config
return {
    cmd = {
        'vim-language-server',
        '--stdio',
    },
    filetypes = {
        'vim',
    },
    root_markers = {
        '.git',
    },
    init_options = {
        diagnostic = {
            enable = true,
        },
        indexes = {
            count = 3,
            gap = 100,
            runtimepath = true,
            projectRootPatterns = {
                'autoload',
                '.git',
                'runtime',
                'nvim',
                'plugin',
            },
        },
        iskeyword = '@,48-57,_,192-255,-#',
        isNeovim = true,
        runtimepath = '',
        suggest = {
            fromRuntimepath = true,
            fromVimruntime = true,
        },
        vimruntime = '',
    },
}
