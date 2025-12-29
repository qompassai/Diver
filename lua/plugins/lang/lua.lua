-- /qompassai/Diver/lua/plugins/lang/lua.lua
-- Qompass AI Diver Lua Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'plugins.lang.lua'
return {
    {
        'folke/lazydev.nvim',
        ft = {
            'lua',
            'luau',
        },
        dependencies = {
            'folke/neodev.nvim',
            'Bilal2453/luvit-meta',
        },
        config = function(_, opts)
            require('config.lang.lua').lua_lazydev(opts)
        end,
        -- init = function(_, opts)
        -- require('lazydev').setup(opts)
        {
            'vhyrro/luarocks.nvim',
            lazy = false,
            priority = 1000,
            config = function(_, opts)
                lua_conf = require('config.lang.lua').lua_luarocks(opts)
            end,
        },
    },
}
