-- qompassai/Diver/lua/config/data/mysql.lua
-- Qompass AI Diver MySQL Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local common = require('config.data.common')
local M = {}

function M.setup_completion(opts)
    opts = opts or {}
    opts.fuzzy = opts.fuzzy or {}
    opts.fuzzy.implementation = 'lua' -- can be "lua" or "prefer_rust"

    opts.sources = opts.sources or
                       {
            default = {'lsp', 'path', 'snippets', 'buffer'},
            per_filetype = {}
        }

    opts.sources.per_filetype = opts.sources.per_filetype or {}
    opts.sources.per_filetype.mysql = {
        'vim-dadbod-completion', 'snippets', 'lsp', 'path', 'buffer'
    }

    local lsp_source = {
        name = 'nvim-lsp',
        group_index = 1,
        priority = 100,
        option = {additional_trigger_characters = {'.', ',', '(', ':'}},
        entry_filter = function(_, ctx) return ctx.filetype == 'mysql' end
    }
    if type(opts.sources.default) == 'table' then
        table.insert(opts.sources.default, lsp_source)
    end
    return opts
end
function M.setup_conform(opts)
    opts = opts or {}
    opts.formatters_by_ft = vim.tbl_deep_extend('force',
                                                opts.formatters_by_ft or {}, {
        mysql = {'sqlfluff', 'sql-formatter'}
    })
    opts.formatters = vim.tbl_deep_extend('force', opts.formatters or {}, {
        sqlfluff = {args = {'fix', '--dialect', 'mysql', '-'}, stdin = true},
        ['sql-formatter'] = {args = {'--language', 'mysql'}, stdin = true}
    })
    return opts
end
function M.setup_lsp(opts)
    opts = opts or {}
    opts.servers = opts.servers or {}
    opts.servers.sqlls = vim.tbl_deep_extend('force', opts.servers.sqlls or {},
                                             {
        autostart = true,
        filetypes = {'mysql'},
        root_dir = common.detect_sql_root_dir,
        settings = {sqlLanguageServer = {dialect = 'mysql'}}
    })

    return opts
end
function M.setup_linter(opts)
    opts = opts or {}
    local ok, null_ls = pcall(require, 'null-ls')
    if not ok then
        vim.notify('null-ls not available', vim.log.levels.WARN)
        return opts
    end

    opts.sources = vim.list_extend(opts.sources or {}, {
        null_ls.builtins.diagnostics.sqlfluff.with({
            filetypes = {'mysql'},
            extra_args = {'--dialect', 'mysql'}
        })
    })

    return opts
end
function M.setup_formatter(opts)
    opts = opts or {}
    local ok, null_ls = pcall(require, 'null-ls')
    if not ok then
        vim.notify('null-ls not available', vim.log.levels.WARN)
        return opts
    end
    opts.sources = vim.list_extend(opts.sources or {}, {
        null_ls.builtins.formatting.sqlfluff.with({
            filetypes = {'mysql'},
            extra_args = {'--dialect', 'mysql'}
        }), null_ls.builtins.formatting.sql_formatter.with({
            filetypes = {'mysql'},
            extra_args = {'--language', 'mysql'}
        })
    })
    return opts
end
function M.setup_filetype_detection()
    vim.filetype.add({
        extension = {mysql = 'mysql'},
        pattern = {['%.my%.sql$'] = 'mysql'},
        filename = {['mysqldump.sql'] = 'mysql'}
    })
end
function M.setup_keymaps(opts)
    opts = opts or {}
    opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
        ['<leader>dm'] = {name = '+mysql'},
        ['<leader>dmf'] = {
            function() require('conform').format({async = true}) end,
            'Format MySQL'
        },
        ['<leader>dmt'] = {'<cmd>DBUIToggle<cr>', 'Toggle DBUI'},
        ['<leader>dma'] = {'<cmd>DBUIAddConnection<cr>', 'Add Connection'},
        ['<leader>dmh'] = {'<cmd>DBUIFindBuffer<cr>', 'Find DB Buffer'},
        ['<leader>dme'] = {
            function()
                if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
                    vim.cmd("'<,'>DB")
                else
                    vim.cmd('DB')
                end
            end, 'Execute Query'
        },
        ['<leader>dmsd'] = {'<cmd>DB SHOW DATABASES<cr>', 'Show Databases'},
        ['<leader>dmst'] = {'<cmd>DB SHOW TABLES<cr>', 'Show Tables'},
        ['<leader>dmsp'] = {'<cmd>DB SHOW PROCESSLIST<cr>', 'Show Processes'}
    })

    return opts
end

return M
