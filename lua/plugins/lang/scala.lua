-- /qompassai/Diver/lua/plugins/lang/scala.lua
-- Qompass AI Diver Scala Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    {
        'scalameta/nvim-metals',
        ft = {'scala', 'sbt', 'java'},
        dependencies = {
            'nvim-lua/plenary.nvim', 'mfussenegger/nvim-dap',
            'rcarriga/nvim-dap-ui', 'nvimtools/none-ls.nvim', 'nvim-cmp',
            'L3MON4D3/LuaSnip', 'nvim-treesitter/nvim-treesitter'
        },
        config = function()
            local M = require('config.lang.scala')
            local setup = M.scala_setup()
            setup.lsp()
            local ok_nls, none_ls = pcall(require, 'null-ls')
            if ok_nls then none_ls.setup({sources = setup.nls}) end
            local ok_dapui, dapui = pcall(require, 'dapui')
            if ok_dapui then dapui.setup() end
        end
    }
}
