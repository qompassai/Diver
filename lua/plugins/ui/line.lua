-- /qompassai/Diver/lua/plugins/ui/line.lua
-- Qompass AI Illum Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    {
        'nvim-lualine/lualine.nvim',
        lazy = false,
        dependencies = {'nvim-tree/nvim-web-devicons', 'folke/tokyonight.nvim'},
        config = function(opts)
            require('config.ui.line').line_setup(opts)
        end
    }
}
