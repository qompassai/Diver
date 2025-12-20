-- qompassai/Diver/lua/config/data/psql.lua
-- Qompass AI Diver PostGreSQL Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local common = require('config.data.common')
local M = {}
function M.psql_cmp(opts)
    opts = opts or {}
    opts.fuzzy = opts.fuzzy or {}
    opts.fuzzy.implementation = 'lua'
    opts.sources = opts.sources
        or {
            default = { 'lsp', 'path', 'snippets', 'buffer' },
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
function M.psql_lsp(opts)
    opts = opts or {}
    opts.servers = opts.servers or {}
    opts.servers.sqlls = vim.tbl_deep_extend('force', opts.servers.sqlls or {}, {
        autostart = true,
        filetypes = { 'pgsql' },
        root_dir = common.detect_sql_root_dir,
        settings = { sqlLanguageServer = { dialect = 'postgresql' } },
    })
    return opts
end
function M.nls(opts)
    opts = opts or {}
    local nlsb = require('null-ls').builtins
    local sources = {
        nlsb.diagnostics.sqlfluff.with({
            filetypes = { 'pgsql' },
            command = 'sqlfluff',
            extra_args = { '--dialect', 'postgres' },
        }),
        nlsb.formatting.sqlfluff.with({
            filetypes = { 'pgsql' },
            command = 'sqlfluff',
            extra_args = { '--dialect', 'postgres' },
        }),
        nlsb.formatting.pg_format.with({
            filetypes = { 'sql', 'pgsql' },
            method = 'formatting',
            command = 'pg_format',
        }),
    }
    return sources
end
function M.psql_ftd()
    vim.filetype.add({
        extension = { psql = 'pgsql', pgsql = 'pgsql' },
        pattern = { ['%.pg%.sql$'] = 'pgsql', ['%.postgres%.sql$'] = 'pgsql' },
        filename = { ['pg_dump.sql'] = 'pgsql' },
    })
end
function M.psql_keymaps(opts)
    opts = opts or {}
    opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
        ['<leader>dp'] = { name = '+postgres' },
        ['<leader>dpf'] = {
            function()
                require('conform').format({ async = true })
            end,
            'Format PostgreSQL',
        },
        ['<leader>dpt'] = { '<cmd>DBUIToggle<cr>', 'Toggle DBUI' },
        ['<leader>dpa'] = { '<cmd>DBUIAddConnection<cr>', 'Add Connection' },
        ['<leader>dph'] = { '<cmd>DBUIFindBuffer<cr>', 'Find DB Buffer' },
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
