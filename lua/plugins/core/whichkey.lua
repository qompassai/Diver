-- /qompassai/Diver/lua/plugins/core/whichkey.lua
-- Qompass AI Diver Whichkey Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    {
        'folke/which-key.nvim',
        event = 'VeryLazy',
        config = function()
            require('which-key').setup({})
            if require('which-key').health and require('which-key').health.check then
                require('which-key').health.check = function()
                    return {}
                end
            end
        end
    }
}
