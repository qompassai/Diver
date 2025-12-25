-- /qompassai/Diver/lua/plugins/nav/harpoon.lua
-- Qompass AI Diver Harpoon Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    'ThePrimeagen/harpoon',
    config = function()
        require('config.nav.harpoon').setup()
    end,
}
