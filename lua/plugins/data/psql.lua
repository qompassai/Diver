-- /qompassai/Diver/lua/plugins/data/psql.lua
-- Qompass AI Diver PSQL Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    {
        'kristijanhusak/vim-dadbod-ui',
        ft = {'pgsql'},
        dependencies = {
            {'tpope/vim-dadbod'},
            {'kristijanhusak/vim-dadbod-completion', ft = {'pgsql'}}
        },
        cmd = {'DBUI', 'DBUIToggle', 'DBUIAddConnection', 'DBUIFindBuffer'},
        init = function()
            vim.g.db_ui_use_nerd_fonts = 1
            vim.g.db_ui_auto_format_results = 1
            vim.g.db_ui_win_position = 'right'
            vim.g.db_ui_winwidth = 40
            vim.g.db_ui_show_help = 0
            vim.g.db_ui_auto_execute_table_helpers = 1
            require('config.data.common').setup_dadbod_connections(
                '~/.config/nvim/dbx.lua')
            require('config.data.psql').setup_filetype_detection()
            vim.api.nvim_create_autocmd('FileType', {
                pattern = {'pgsql'},
                callback = function()
                    vim.opt_local.expandtab = true
                    vim.opt_local.shiftwidth = 2
                    vim.opt_local.softtabstop = 2
                    vim.opt_local.omnifunc = 'vim_dadbod_completion#omni'
                end
            })
        end,
        keys = {
            {
                '<leader>dpt',
                '<cmd>DBUIToggle<CR>',
                desc = 'Toggle PostgreSQL UI'
            },
            {
                '<leader>dpf',
                '<cmd>DBUIFindBuffer<CR>',
                desc = 'Find PostgreSQL Buffer'
            }, {
                '<leader>dpe',
                function()
                    if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
                        vim.cmd("'<,'>DB")
                    else
                        vim.cmd('DB')
                    end
                end,
                desc = 'Execute PostgreSQL Query'
            }
        }
    }, {
        'neovim/nvim-lspconfig',
        opts = function(_, opts)
            return require('config.data.psql').psql_lsp(opts)
        end
    }, {
        'nvimtools/none-ls.nvim',
        opts = function(_, opts)
            opts = require('config.data.psql').psql_linter(opts)
            opts = require('config.data.psql').psql_formatter(opts)
            return opts
        end
    }, {
        'stevearc/conform.nvim',
        opts = function(_, opts)
            return require('config.data.psql').psql_conform(opts)
        end
    }, {
        'folke/which-key.nvim',
        optional = true,
        opts = function(_, opts)
            return require('config.data.psql').psql_keymaps(opts)
        end
    }
}
