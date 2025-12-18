-- /qompassai/Diver/lsp/vim_ls.lua
-- Qompass AI Vim LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference:  https://github.com/iamcco/vim-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
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
        isNeovim = true,
        iskeyword = '@,48-57,_,192-255,-#',
        vimruntime = '',
        runtimepath = '',
        diagnostic = {
            enable = true,
        },
        indexes = {
            runtimepath = true,
            gap = 100,
            count = 3,
            projectRootPatterns = {
                'runtime',
                'nvim',
                '.git',
                'autoload',
                'plugin',
            },
        },
        suggest = {
            fromVimruntime = true,
            fromRuntimepath = true,
        },
    },
}
