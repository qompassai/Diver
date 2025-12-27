-- /qompassai/Diver/lua/plugins/edu/scnvim.lua
-- Qompass AI SuperCollider Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type LazyPluginSpec
return {
    'davidgranstrom/scnvim',
    lazy = false,
    dependencies = {},
    ft = 'supercollider',
    config = function()
        local scnvim = require('scnvim')
        scnvim.setup({
            editor = {
                highlight = {
                    color = 'IncSearch',
                },
            },
            postwin = {
                float = {
                    enabled = true,
                },
            },
        })
    end,
}
