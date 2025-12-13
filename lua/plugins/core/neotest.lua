-- /qompassai/Diver/lua/plugins/core/neotest.lua
-- Qompass AI Diver NeoTest Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    'nvim-neotest/neotest',
    dependencies = {
        'nvim-neotest/nvim-nio',
        'nvim-lua/plenary.nvim',
        'nvim-neotest/neotest-plenary',
        'antoinemadec/FixCursorHold.nvim',
        'nvim-treesitter/nvim-treesitter',
        'ibhagwan/fzf-lua',
    },
    opts = {
        adapters = {
            'neotest-plenary',
        },
    },
}
