-- /qompassai/Diver/lua/plugins/lang/php.lua
-- Qompass AI Diver PHP Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    {
        'nvimtools/none-ls.nvim',
        ft = {'php'},
        dependencies = {
            'mfussenegger/nvim-dap', 'rcarriga/nvim-dap-ui',
            'jay-babu/mason-null-ls.nvim', 'nvim-neotest/neotest',
            'olimorris/neotest-phpunit'
        },
        config = function()
            local php = require('config.lang.php')
            php.php_autocmds()
            php.php_dap()
            require('null-ls').register({sources = php.php_nls()})
            local ok, neotest = pcall(require, 'neotest')
            if ok then
                neotest.setup({
                    adapters = {
                        require('neotest-phpunit')({
                            phpunit_cmd = 'vendor/bin/phpunit'
                        })
                    }
                })
            end
        end
    }
}
