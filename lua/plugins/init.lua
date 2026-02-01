-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local a = vim.api
local p = vim.pack
local r = require
local v = vim.version
vim.opt.packpath = vim.opt.runtimepath:get() ---@type string[]
a.nvim_create_user_command('PackUpdate', function()
    a.nvim_echo({
        {
            'Updating plugins…',
            'None',
        },
    }, false, {})
    p.update()
    a.nvim_echo({
        {
            'Plugins updated!',
            'None',
        },
    }, false, {})
end, {
    desc = 'Update all vim.pack plugins',
})
p.add({
    {
        event = {
            'BufEnter',
        },
        hook = function()
            r('config.cicd.sops').sops()
        end,
        src = 'https://github.com/trixnz/sops.nvim',
        update = true,
        version = 'main',
    },
    {
        branch = 'main',
        hook = function()
            local lua_cfg = r('config.lang.lua')
            local opts = lua_cfg.lua_luarocks({})
            --require('luarocks-nvim').setup(opts)
            r('luarocks').setup(opts)
        end,
        src = 'https://github.com/vhyrro/luarocks.nvim',
        update = true,
        version = nil,
    },
    {
        branch = 'main',
        event = {
            'InsertEnter',
        },
        hook = function()
            local cmp_cfg = r('config.lang.cmp').blink_cmp()
            r('blink.cmp').setup(cmp_cfg)
        end,
        src = 'https://github.com/Saghen/blink.cmp',
        update = true,
        version = v.range('1.*'),
    },
    {
        branch = 'main',
        hook = function()
            require('config.core.tree').treesitter({})
        end,
        src = 'https://github.com/nvim-treesitter/nvim-treesitter',
        update = true,
        version = nil,
    },
    {
        src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
        version = 'main',
    },
    {
        branch = 'master',
        src = 'https://github.com/L3MON4D3/LuaSnip',
        version = v.range('2.*'),
    },
    {
        src = 'https://github.com/rafamadriz/friendly-snippets',
        update = true,
        version = 'main',
    },
    {
        src = 'https://github.com/hrsh7th/cmp-nvim-lua',
        update = true,
        version = 'main',
    },
    {
        src = 'https://github.com/hrsh7th/cmp-buffer',
        version = 'main',
    },
    {
        branch = 'master',
        src = 'https://github.com/moyiz/blink-emoji.nvim',
        version = 'master',
    },
    {
        branch = 'master',
        src = 'https://github.com/Kaiser-Yang/blink-cmp-dictionary',
        update = true,
        version = v.range('2.*'),
    },
    {
        branch = 'main',
        src = 'https://github.com/Saghen/blink.compat',
        update = true,
        version = v.range('2.*'),
    },
    {
        branch = 'main',
        hook = function()
            r('config.core.flash').flash_cfg()
        end,
        src = 'https://github.com/folke/flash.nvim',
        update = true,
        version = v.range('2.*'),
    },
    {
        branch = 'main',
        hook = function()
            r('mini.ai').setup()
        end,
        opts = {
            custom_textobjects = {},
            n_lines = 500,
            search_method = 'cover_or_next',
        },
        src = 'https://github.com/echasnovski/mini.nvim',
        update = true,
        version = v.range('0.*'),
    },
    {
        cmd = {
            'TroubleToggle',
            'Trouble',
        },
        hook = function(spec)
            r('trouble').setup(spec.opts)
        end,
        opts = r('config.core.trouble')(),
        src = 'https://github.com/folke/trouble.nvim',
        version = 'main',
    },
})
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
            import = 'plugins.nav',
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