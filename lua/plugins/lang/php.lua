-- /qompassai/Diver/lua/plugins/lang/php.lua
-- Qompass AI Diver PHP Plugin Spec
-- ---------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
    {
        'nvimtools/none-ls.nvim',
        ft = {'php'},
        config = function()
            local php = require('config.lang.php')
            require('null-ls').setup({sources = php.php_nls()})
            php.php()
        end
    }, {
        'mfussenegger/nvim-dap',
        ft = {'php'},
        config = function()
            local php = require('config.lang.php')
            php.php_dap()
        end
    }
}
