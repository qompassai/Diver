-- /qompassai/Diver/lua/plugins/data.lua
-- Qompass AI Diver Data Plugins
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
---@param repo string
---@return string|vim.pack.Spec
_G.gh = function(repo, opts)
    if opts then
        ---@cast opts vim.pack.Spec
        opts.src = 'https://github.com/' .. repo
        return opts
    end
    return 'https://github.com/' .. repo
end
local g = vim.g
local range = vim.version.range
vim.pack.add({
    gh('kkharji/sqlite.lua', {
        version = 'master',
        hook = function()
            vim.g.sqlite_clib_path = '/usr/lib/libsqlite3.so'
        end,
    }),
    gh('akinsho/toggleterm.nvim', {
        version = range('2.*'),
        event = { 'VeryLazy' },
        cmd = { 'ToggleTerm' },
        hook = function()
            require('toggleterm').setup({
                direction = 'float',
                open_mapping = [[<c-\>]],
                size = 20,
            })
        end,
    }),
    gh('tpope/vim-dadbod', {
        version = 'master',
    }),
    gh('kristijanhusak/vim-dadbod-completion', {
        version = 'master',
        filetypes = {
            'pgsql',
            'sqlite',
        },
    }),
    gh('kristijanhusak/vim-dadbod-ui', {
        version = 'master',
        filetypes = {
            'pgsql',
            'sqlite',
        },
        cmd = {
            'DBUI',
            'DBUIAddConnection',
            'DBUIFindBuffer',
            'DBUIToggle',
        },
        hook = function()
            g.db_ui_auto_execute_table_helpers = 1
            g.db_ui_auto_format_results = 1
            g.db_ui_show_help = 1
            g.db_ui_use_nerd_fonts = 1
            g.db_ui_win_position = 'right'
            g.db_ui_winwidth = 40
            g.db_ui_connections = {
                zotero = 'sqlite:///' .. vim.fn.expand('$XDG_DATA_HOME/zotero/zotero.sqlite'),
            }
            require('config.data.common').setup_dadbod_connections('$XDG_CONFIG_HOME/nvim/dbx.lua')
            require('config.data.sqlite').sqlite_ftd()
        end,
    }),
}, {
    confirm = false,
    load = true,
})