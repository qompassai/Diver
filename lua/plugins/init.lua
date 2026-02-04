-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@param repo string
---@return string|vim.pack.Spec
_G.gh = function(repo, opts)
    if opts then
        ---@cast opts vim.pack.Spec
        opts.src = 'https://github.com/' .. repo
        return opts
    end
    return 'https://github.com/' .. repo
end
local add = vim.pack.add
local api = vim.api
local sops = require('config.cicd.sops')
local tree = require('config.core.tree')
local update = vim.pack.update
local range = vim.version.range
vim.opt.packpath = vim.opt.runtimepath:get()
api.nvim_create_user_command('PackUpdate', function()
    api.nvim_echo({
        {
            'Updating plugins…',
            'None',
        },
    }, false, {})
    update()
    api.nvim_echo({
        {
            'Plugins updated!',
            'None',
        },
    }, false, {})
end, {
    desc = 'Update all vim.pack plugins',
})
add({
    gh('trixnz/sops.nvim', {
        event = { 'BufEnter' },
        hook = function()
            sops.sops()
        end,
        update = true,
        version = 'main',
    }),
    gh('vhyrro/luarocks.nvim', {
        branch = 'main',
        hook = function()
            local lua_cfg = require('config.lang.lua')
            local opts = lua_cfg.lua_luarocks({})
            require('luarocks').setup(opts)
        end,
        update = true,
    }),
    gh('Saghen/blink.cmp', {
        event = { 'InsertEnter' },
        hook = function()
            local cmp_cfg = require('config.lang.cmp').blink_cmp()
            require('blink.cmp').setup(cmp_cfg)
        end,
        update = true,
        version = range('1.*'),
    }),
    gh('nvim-treesitter/nvim-treesitter', {
        hook = function()
            tree.treesitter({})
        end,
        update = true,
    }),
    gh('nvim-treesitter/nvim-treesitter-textobjects', {
        version = 'main',
    }),
    gh('L3MON4D3/LuaSnip', {
        version = range('2.*'),
    }),
    gh('rafamadriz/friendly-snippets', {
        update = true,
        version = 'main',
    }),
    gh('hrsh7th/cmp-nvim-lua', {
        update = true,
        version = 'main',
    }),
    gh('hrsh7th/cmp-buffer'),
    gh('moyiz/blink-emoji.nvim', {
        version = 'master',
    }),
    gh('Kaiser-Yang/blink-cmp-dictionary', {
        update = true,
        version = range('2.*'),
    }),
    gh('Saghen/blink.compat', {
        update = true,
        version = range('2.*'),
    }),
    gh('folke/flash.nvim', {
        hook = function()
            require('config.core.flash').flash_cfg()
        end,
        update = true,
        version = range('2.*'),
    }),
    gh('echasnovski/mini.nvim', {
        hook = function()
            require('mini.ai').setup()
        end,
        opts = {
            custom_textobjects = {},
            n_lines = 500,
            search_method = 'cover_or_next',
        },
        update = true,
        version = range('0.*'),
    }),
    gh('folke/trouble.nvim', {
        cmd = {
            'TroubleToggle',
            'Trouble',
        },
        hook = function(spec)
            require('trouble').setup(spec.opts)
        end,
        opts = require('config.core.trouble')(),
        version = 'main',
    }),
}, {
    confirm = false,
    load = true,
})
require('plugins.nav')
return {
    {
        import = 'plugins.core',
    },
    {
        {
            import = 'plugins.cloud',
        },
        {
            import = 'plugins.data',
        },
        {
            import = 'plugins.edu',
        },
        {
            import = 'plugins.cicd',
        },
        {
            import = 'plugins.lang',
        },
        {
            import = 'plugins.ui',
        },
    },
}
--[[
local specs = {}
local function add(mod)
    local ok, t = pcall(require, mod)
    if not ok then
        error(('require(%s) failed: %s'):format(mod, t))
    end
    if type(t) ~= 'table' then
        error(('module %s must return a table of vim.pack specs, got %s'):format(mod, type(t)))
    end
    for _, s in ipairs(t) do
        specs[#specs + 1] = s
    end
end

add('plugins.core')
add('plugins.data')
add('plugins.edu')
add('plugins.cloud')
add('plugins.cicd')
add('plugins.lang')
add('plugins.nav')
add('plugins.ui')
vim.pack.add(specs, {
    confirm = true,
    load = true,
})
return specs
--]]