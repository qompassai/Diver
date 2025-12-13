-- /qompassai/Diver/lua/plugins/core/cheatsheet.lua
-- Qompass AI Diver CheatSheet Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    'sudormrfbin/cheatsheet.nvim',
    keys = { { '<leader>?', '<cmd>Cheatsheet<CR>', desc = 'Open Cheatsheet' } },
    dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'ibhagwan/fzf-lua',
        'nvim-lua/plenary.nvim',
        'folke/which-key.nvim',
    },
    config = function()
        require('cheatsheet').setup({
            bundled_cheatsheets = true,
            bundled_plugin_cheatsheets = true,
            include_only_installed_plugins = true,
        })
    end,
}
