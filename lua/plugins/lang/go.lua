-- /qompassai/Diver/lua/plugins/lang/go.lua
-- Qompass AI Go Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local lang_go = require('config.lang.go')
return {
    {
        'ray-x/go.nvim',
        ft = {'go', 'gomod'},
        config = function() require('go').setup({}) end,
        dependencies = {'ray-x/guihua.lua', 'ray-x/navigator.lua'}
    }, {
        'neovim/nvim-lspconfig',
        ft = {'go', 'gomod'},
        config = function() lang_go.go_lsp() end
    }, {
        'nvimtools/none-ls.nvim',
        ft = {'go'},
        config = function()
            local null_ls = require('null-ls')
            null_ls.setup({sources = lang_go.go_nls()})
        end
    }, {
        'stevearc/conform.nvim',
        ft = {'go'},
        config = function() lang_go.go_conform() end,
        {
            'leoluz/nvim-dap-go',
            ft = {'go'},
            config = function() require('config.lang.go').go_dap() end
        },
        {'rcarriga/nvim-dap-ui', ft = {'go'}},
        {'igorlfs/nvim-dap-view', ft = {'go'}, opts = {}}
    }
}
