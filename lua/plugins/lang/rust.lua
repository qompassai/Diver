-- /qompassai/Diver/lua/plugins/lang/rust.lua
-- Qompass AI Diver Rust Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local rust_cfg = require('config.lang.rust')
return {
    {
        'mrcjkb/rustaceanvim',
        ft = {'rust'},
        version = '^6',
        config = function()

            local capabilities = require('cmp_nvim_lsp').default_capabilities()
            vim.g.rustaceanvim = {
                tools = {float_win_config = {border = 'rounded'}},
                server = {
                    on_attach = rust_cfg.rust_on_attach,
                    capabilities = capabilities,
                    settings = {['rust-analyzer'] = rust_cfg.rust_settings()}
                }
            }
            require('null-ls').setup({sources = rust_cfg.rust_nls()})
            vim.lsp.set_log_level('INFO')
            rust_cfg.rust_dap()
            rust_cfg.rust_crates()
            rust_cfg.rust_cfg()
        end,
        dependencies = {
            'nvim-lua/plenary.nvim', 'nvim-treesitter/nvim-treesitter',
            {
                'L3MON4D3/LuaSnip',
                dependencies = {'rafamadriz/friendly-snippets'}
            }, 'nvimtools/none-ls.nvim', 'nvimtools/none-ls-extras.nvim', {
                'mfussenegger/nvim-dap',
                dependencies = {
                    'rcarriga/nvim-dap-ui', {'igorlfs/nvim-dap-view', opts = {}}
                }
            }
        }
    }, {
        'saecki/crates.nvim',
        event = {'BufRead Cargo.toml'},
        config = function() rust_cfg.rust_crates() end
    }, {
        'nvim-neotest/neotest',
        ft = {'rust'},
        dependencies = {
            'nvim-neotest/nvim-nio', 'rouge8/neotest-rust',
            'mfussenegger/nvim-dap'
        },
        config = function()
            local neotest = require('neotest')
            neotest.setup({
                adapters = {
                    require('neotest-rust')({
                        args = {'--no-capture'},
                        dap_adapter = 'codelldb'
                    })
                }
            })
            local map = vim.keymap.set
            map('n', '<leader>rtt', neotest.run.run, {desc = 'Run nearest test'})
            map('n', '<leader>rtf',
                function() neotest.run.run(vim.fn.expand('%')) end,
                {desc = 'Run file tests'})
            map('n', '<leader>rtd',
                function() neotest.run.run({strategy = 'dap'}) end,
                {desc = 'Debug nearest test'})
        end
    }
}
