-- qompassai/Diver/lua/config/data/sqlite.lua
-- Qompass AI Diver SQLite Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local common = require('config.data.common')
local M = {}
function M.sqlite_conform(opts)
    opts.formatters_by_ft = vim.tbl_deep_extend('force',
                                                opts.formatters_by_ft or {}, {
        sqlite = {'sqlfluff', 'sql-formatter'}
    })
    opts.formatters = vim.tbl_deep_extend('force', opts.formatters or {}, {
        sqlfluff = {args = {'fix', '--dialect', 'sqlite', '-'}, stdin = true},
        ['sql-formatter'] = {args = {'--language', 'sqlite'}}
    })
    return opts
end
function M.sqlite_lsp(opts)
    if not opts.servers then opts.servers = {} end
    opts.servers.sqlls = vim.tbl_deep_extend('force', opts.servers.sqlls or {},
                                             {
        autostart = true,
        filetypes = {'sqlite'},
        root_dir = common.detect_sql_root_dir,
        settings = {sqlLanguageServer = {dialect = 'sqlite'}}
    })
    return opts
end
function M.sqlite_nls(opts)
    local null_ls = require('null-ls')
    opts.sources = vim.list_extend(opts.sources or {}, {
        null_ls.builtins.diagnostics.sqlfluff.with({
            filetypes = {'sqlite'},
            extra_args = {'--dialect', 'sqlite'}
        })
    })
        null_ls.builtins.formatting.sqlfluff.with({
            filetypes = {'sqlite'},
            extra_args = {'--dialect', 'sqlite'}
        }) null_ls.builtins.formatting.sql_formatter.with({
            filetypes = {'sqlite'},
            extra_args = {'--language', 'sqlite'}
        })
    return opts
end
function M.sqlite_ftd()
    vim.filetype.add({
        extension = {sqlite = 'sqlite', sqlite3 = 'sqlite', db = 'sqlite'},
        pattern = {['%.lite%.sql$'] = 'sqlite', ['%.sqlite%.sql$'] = 'sqlite'}
    })
end
function M.sqlite_keymaps(opts)
    opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
        ['<leader>Ds'] = {name = '+sqlite'},
        ['<leader>Dsf'] = {
            "<cmd>lua require('conform').format()<cr>", 'Format SQLite'
        },
        ['<leader>Dst'] = {'<cmd>DBUIToggle<cr>', 'Toggle DBUI'},
        ['<leader>Dsa'] = {'<cmd>DBUIAddConnection<cr>', 'Add Connection'},
        ['<leader>Dsh'] = {'<cmd>DBUIFindBuffer<cr>', 'Find DB Buffer'},
        ['<leader>Dse'] = {
            function()
                if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
                    vim.cmd("'<,'>DB")
                else
                    vim.cmd('DB')
                end
            end, 'Execute Query'
        },
        ['<leader>Dsst'] = {
            "<cmd>DB SELECT name FROM sqlite_master WHERE type='table'<cr>",
            'List Tables'
        },
        ['<leader>Dssi'] = {
            "<cmd>DB SELECT * FROM sqlite_master WHERE type='index'<cr>",
            'List Indexes'
        },
        ['<leader>Dssv'] = {
            '<cmd>DB PRAGMA schema_version<cr>', 'Schema Version'
        }
    })
    return opts
end
return M
