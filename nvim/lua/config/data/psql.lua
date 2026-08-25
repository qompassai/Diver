-- qompassai/Diver/lua/config/data/psql.lua
-- Qompass AI Diver PostGreSQL Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        'sqlite',
        'pgsql',
    },
    callback = function()
        vim.opt_local.expandtab = true
        vim.opt_local.shiftwidth = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.omnifunc = 'vim_dadbod_completion#omni'
    end,
})
function M.psql_cmp(opts)
    opts = opts or {}
    opts.fuzzy = opts.fuzzy or {}
    opts.fuzzy.implementation = 'lua'
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
    opts.sources.per_filetype.pgsql = {
        'vim-dadbod-completion',
        'snippets',
        'lsp',
        'path',
        'buffer',
    }
    return opts
end

function M.psql_keymaps(opts)
    opts = opts or {}
    opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
        ['<leader>dp'] = {
            name = '+postgres',
        },
        ['<leader>dpf'] = {
            function() end,
            'Format PostgreSQL',
        },
        ['<leader>dpt'] = {
            '<cmd>DBUIToggle<cr>',
            'Toggle DBUI',
        },
        ['<leader>dpa'] = {
            '<cmd>DBUIAddConnection<cr>',
            'Add Connection',
        },
        ['<leader>dph'] = {
            '<cmd>DBUIFindBuffer<cr>',
            'Find DB Buffer',
        },
        ['<leader>dpe'] = {
            function()
                if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
                    vim.cmd('\'<,\'>DB')
                else
                    vim.cmd('DB')
                end
            end,
            'Execute Query',
        },
        ['<leader>dpd'] = {
            '<cmd>DB SELECT current_database()<cr>',
            'Current Database',
        },
        ['<leader>dpl'] = {
            '<cmd>DB SELECT * FROM pg_tables WHERE schemaname = \'public\'<cr>',
            'List Tables',
        },
        ['<leader>dps'] = {
            '<cmd>DB SELECT * FROM pg_stat_activity<cr>',
            'Show Processes',
        },
    })
    return opts
end

return M