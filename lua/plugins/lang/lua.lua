-- /qompassai/Diver/lua/plugins/lang/lua.lua
-- Qompass AI Diver Lua Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'plugins.lang.lua'
local lua_conf = require('config.lang.lua')
local lua_ft = {
    'lua',
    'luau',
}

return {
    {
        'folke/lazydev.nvim',
        ft = lua_ft,
        dependencies = {
            'folke/neodev.nvim',
            'Bilal2453/luvit-meta',
        },
        config = function(_, opts)
            lua_conf.lua_lazydev(opts)
        end,
        init = function(_, opts)
            require('lazydev').setup(opts)
        end,
    },
    {
        'vhyrro/luarocks.nvim',
        lazy = false,
        priority = 1000,
        config = function(_, opts)
            lua_conf = require('config.lang.lua').lua_luarocks(opts)
        end,
    },
}
