-- /qompassai/Diver/lua/plugins/lang/ts.lua
-- Qompass AI Diver Typescript Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local ts = require('config.lang.ts')
return {
    {
        'neovim/nvim-lspconfig',
        dependencies = {'jose-elias-alvarez/typescript.nvim'},
        ft = {'typescript', 'typescriptreact'},
        opts = function(_, opts) return ts.lsp(opts) end
    }, {
        'nvimtools/none-ls.nvim',
        ft = {'typescript', 'typescriptreact'},
        dependencies = {
            'nvim-lua/plenary.nvim', 'nvimtools/none-ls-extras.nvim'
        },
        opts = function(_, opts) return ts.formatter(opts) end
    }, {
        'mfussenegger/nvim-lint',
        ft = {'typescript', 'typescriptreact'},
        config = function()
            require('config.lang.ts').linter({})
            vim.api.nvim_create_autocmd({
                'BufWritePost', 'BufReadPost', 'InsertLeave'
            }, {
                pattern = {'*.ts', '*.tsx'},
                callback = function() require('lint').try_lint() end
            })
        end
    }, {
        'nvim-treesitter/nvim-treesitter',
        opts = function(_, opts)
            if type(opts.ensure_installed) == 'table' then
                vim.list_extend(opts.ensure_installed, {'typescript', 'tsx'})
            end
        end
    }, {
        'stevearc/conform.nvim',
        ft = {'typescript', 'typescriptreact'},
        opts = function(_, opts) return ts.conform(opts) end
    }, {
        'folke/which-key.nvim',
        optional = true,
        ft = {'typescript', 'typescriptreact'},
        opts = function(_, opts) return ts.keymaps(opts) end
    }, {
        'jose-elias-alvarez/typescript.nvim',
        ft = {'typescript', 'typescriptreact'},
        config = function() ts.commands() end
    }
}
