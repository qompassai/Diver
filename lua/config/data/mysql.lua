-- qompassai/Diver/lua/config/data/mysql.lua
-- Qompass AI Diver MySQL Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.setup_completion(opts)
    opts = opts or {}
    opts.fuzzy = opts.fuzzy or {}
    opts.fuzzy.implementation = 'lua' ---@type string
    opts.sources = opts.sources
        or {
            default = {
                'lsp',
                'path',
                'snippets',
                'buffer',
            },
            per_filetype = {},
        }
    opts.sources.per_filetype = opts.sources.per_filetype or {}
    opts.sources.per_filetype.mysql = {
        'vim-dadbod-completion',
        'snippets',
        'lsp',
        'path',
        'buffer',
    }
    return opts
end

function M.setup_filetype_detection()
    vim.filetype.add({
        extension = {
            mysql = 'mysql',
        },
        pattern = {
            ['%.my%.sql$'] = 'mysql',
        },
        filename = {
            ['mysqldump.sql'] = 'mysql',
        },
    })
end

function M.setup_keymaps(opts)
    opts = opts or {}
    opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, { ---@type table[]
        ['<leader>dmt'] = {
            '<cmd>DBUIToggle<cr>',
            'Toggle DBUI',
        },
        ['<leader>dma'] = { '<cmd>DBUIAddConnection<cr>', 'Add Connection' },
        ['<leader>dmh'] = { '<cmd>DBUIFindBuffer<cr>', 'Find DB Buffer' },
        ['<leader>dme'] = {
            function()
                if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
                    vim.cmd('\'<,\'>DB')
                else
                    vim.cmd('DB')
                end
            end,
            'Execute Query',
        },
        ['<leader>dmsd'] = { '<cmd>DB SHOW DATABASES<cr>', 'Show Databases' },
        ['<leader>dmst'] = { '<cmd>DB SHOW TABLES<cr>', 'Show Tables' },
        ['<leader>dmsp'] = { '<cmd>DB SHOW PROCESSLIST<cr>', 'Show Processes' },
    })
    return opts
end

return M
