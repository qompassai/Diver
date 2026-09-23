-- /qompassai/Diver/lua/plugins/cloud/distant.lua
-- Qompass AI Diver Distant Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    'chipsenkbeil/distant.nvim',
    branch = 'v0.3',
    config = function()
        require('distant'):setup()
    end,
}
