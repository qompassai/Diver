-- /qompassai/Diver/lua/plugins/core/neoconf.lua
-- Qompass AI Diver Neoconf Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------
-- Copyright (C) 2025 Qompass AI
return {
    'folke/neoconf.nvim',
    priority = 1000,
    lazy = false,
    config = function() require('neoconf').setup() end
}
