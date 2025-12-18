-- /qompassai/Diver/lsp/ziggy_schema.lua
-- Qompass AI Ziggy Schema Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference:  https://ziggy-lang.io/documentation/ziggy-lsp/
local parser_config = require('nvim-treesitter.parsers').get_parser_configs() ---@class parser_config
parser_config.ziggy_schema = {
    install_info = {
        url = 'https://github.com/kristoff-it/ziggy',
        files = { 'tree-sitter-ziggy-schema/src/parser.c' },
        branch = 'main',
        generate_requires_npm = true,
        requires_generate_from_grammar = true,
    },
    filetype = 'ziggy_schema',
}
vim.filetype.add({
    extension = {
        ziggy = 'ziggy',
        ['ziggy-schema'] = 'ziggy_schema',
    },
})
---@type vim.lsp.Config
return {
    cmd = {
        'ziggy', ---@type string[]
        'lsp',
        '--schema',
    },
    filetypes = { ---@type string[]
        'ziggy_schema',
    },
    root_markers = { ---@type string[]
        '.git',
    },
},
    vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('ziggy_schema', {}),
        pattern = 'ziggy_schema',
        callback = function()
            vim.lsp.start({
                name = 'Ziggy LSP',
                cmd = {
                    'ziggy',
                    'lsp',
                    '--schema',
                },
                root_dir = vim.loop.cwd(),
            })
        end,
    })
