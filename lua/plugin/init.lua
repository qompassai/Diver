-- /qompassai/Diver/lua/plugin/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local api = vim.api
local add = vim.pack.add
local update = vim.pack.update

--- @param x string
--- @return string
local gh = function(x)
    return 'https://github.com/' .. x
end

local M = {}

vim.opt.packpath = vim.opt.runtimepath:get()

-- coq_nvim reads vim.g.coq_settings when it loads, so this must be set
-- before M.bootstrap() installs/loads the specs below. A plugin_setup entry
-- would be too late (it runs after the plugin is already loaded).
vim.g.coq_settings = {
    auto_start = false,
}

-- Every spec below sets all four vim.pack.Spec fields explicitly
-- (verified against runtime/lua/vim/pack.lua, NVIM v0.13.0-dev):
--   src     string (required)   clone URI
--   name    string              install directory name (defaults to repo basename)
--   version string|VersionRange branch, tag, or commit hash;
--                              nil tracks the repository's default branch
--   data    any                 arbitrary data, carried through untouched by vim.pack
--
-- NOTE: `branch`, `keys`, `hook`, and `update` are NOT vim.pack.Spec fields and
-- are silently ignored by vim.pack.add. Per-plugin setup lives in the
-- `plugin_setup` table below (keyed by spec src), keymaps are created with
-- vim.keymap.set, and branch pins are expressed with `version`.
local plugins = {
    --[[
{
                src = gh('ms-jpq/coq.artifacts'),
                version = 'artifacts',
                data = nil,
        },
        {
                src = gh('ms-jpq/coq.thirdparty'),
                version = '3p',
                data = nil,
        },
    {
        src = gh('ms-jpq/coq_nvim'),
        version = 'dev',
        data = nil,
    },
    {
        src = gh('nvim-neo-tree/neo-tree.nvim'),
        version = vim.version.range('3.*'),
        data = nil,
    },
    --]]
    {
        src = gh('EdenEast/nightfox.nvim'),
        version = 'main',
        data = nil,
    },
    {
        src = gh('MunifTanjim/nui.nvim'),
        version = 'main',
        data = nil,
    },
    {
        src = gh('nvim-treesitter/nvim-treesitter'),
        version = 'main',
        data = nil,
    },
    {
        src = gh('nvim-treesitter/nvim-treesitter-textobjects'),
        version = 'main',
        data = nil,
    },
    --[[
    {
        src = gh('nvim-lua/plenary.nvim'),
        version = 'master',
        data = nil,
    },
    --]]
    {
        data = nil,
        src = gh('folke/which-key.nvim'),
        version = 'main',
    },
}

-- Lazy-loaded plugins: deferred until after startup to reduce init time.
local lazy_plugins = {
    {
        src = gh('vyfor/cord.nvim'),
        version = 'master',
        data = {
            event = 'BufEnter',
            config = function()
                local opts = {}
                require('config.ui.themes').cord_setup(opts)
            end,
        },
    },
    {
        src = gh('vhyrro/luarocks.nvim'),
        version = 'main',
        data = nil,
    },
}

-- Post-install setup, keyed by spec src. Each entry runs after vim.pack.add
-- has loaded the plugin (see M.setup_plugins). Sorted alphabetically by src.
-- NOTE: md-pdf.nvim and live-preview.nvim have setup entries but no matching
-- specs in `plugins`/`lazy_plugins`, so these two never run (kept as-is).
local plugin_setup = {}

plugin_setup[gh('arminveres/md-pdf.nvim')] = function()
    local ok_cfg, md_cfg = pcall(require, 'config.lang.md')
    if not ok_cfg or type(md_cfg.md_pdf) ~= 'function' then
        vim.notify('md-pdf.nvim setup: config.lang.md.md_pdf missing', vim.log.levels.WARN)
        return
    end
    local ok, err = pcall(md_cfg.md_pdf, {})
    if not ok then
        vim.notify('md-pdf.nvim setup failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
end

plugin_setup[gh('brianhuster/live-preview.nvim')] = function()
    local ok_cfg, md_cfg = pcall(require, 'config.lang.md')
    if not ok_cfg or type(md_cfg.md_livepreview) ~= 'function' then
        vim.notify('live-preview.nvim setup: config.lang.md.md_livepreview missing', vim.log.levels.WARN)
        return
    end

    local ok, err = pcall(md_cfg.md_livepreview, {})
    if not ok then
        vim.notify('live-preview.nvim setup failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
end

plugin_setup[gh('folke/which-key.nvim')] = function()
    -- config.core.whichkey only defines WK.setup(); it does not self-setup
    -- on require, so the call below is required (previously a bare require
    -- meant which-key was installed but never configured).
    require('config.core.whichkey').setup()
end

plugin_setup[gh('nvim-treesitter/nvim-treesitter')] = function()
    require('config.core.tree').treesitter()
end

plugin_setup[gh('nvim-treesitter/nvim-treesitter-textobjects')] = function()
    require('config.core.tree').textobjects()
end

plugin_setup[gh('sudormrfbin/cheatsheet.nvim')] = function()
    -- NOTE: <leader>? is also mapped by config.core.whichkey's setup()
    -- (which runs later, since which-key.nvim sorts after cheatsheet.nvim),
    -- so which-key's mapping wins. Change one of them if that is not intended.
    vim.keymap.set('n', '<leader>?', '<cmd>Cheatsheet<CR>', { desc = 'Open Cheatsheet' })
    require('cheatsheet').setup({
        bundled_cheatsheets = true,
        bundled_plugin_cheatsheets = true,
        include_only_installed_plugins = true,
    })
end

plugin_setup[gh('vhyrro/luarocks.nvim')] = function()
    local ok_cfg, lua_cfg = pcall(require, 'config.lang.lua')
    if not ok_cfg or type(lua_cfg.lua_luarocks) ~= 'function' then
        vim.notify('luarocks setup: config.lang.lua.lua_luarocks missing', vim.log.levels.WARN)
        return
    end
    local ok_opts, opts = pcall(lua_cfg.lua_luarocks, {})
    if not ok_opts then
        vim.notify('luarocks setup failed: ' .. tostring(opts), vim.log.levels.ERROR)
        return
    end
    local ok_lr, lr = pcall(require, 'luarocks-nvim')
    if not ok_lr or type(lr.setup) ~= 'function' then
        vim.notify('luarocks-nvim module missing or invalid', vim.log.levels.ERROR)
        return
    end
    lr.setup(opts)
end

--- Validate every spec in `plugins` and `lazy_plugins` against the real
--- vim.pack.Spec contract: src (required https URL), name (optional string),
--- version (optional string or vim.VersionRange), data (anything).
--- @return boolean ok
--- @return string[] errors
function M.validate_specs()
    local errors = {}

    --- @param spec table
    --- @param i integer
    --- @param label string
    local function check(spec, i, label)
        if type(spec) ~= 'table' then
            errors[#errors + 1] = ('%s[%d] is not a table'):format(label, i)
            return
        end
        if type(spec.src) ~= 'string' or spec.src == '' then
            errors[#errors + 1] = ('%s[%d] is missing a valid src'):format(label, i)
        elseif not spec.src:match('^https://') then
            errors[#errors + 1] = ('%s[%d].src is not a URL: %s'):format(label, i, spec.src)
        end
        if spec.name ~= nil and type(spec.name) ~= 'string' then
            errors[#errors + 1] = ('%s[%d].name must be a string'):format(label, i)
        end
        if spec.version ~= nil and type(spec.version) ~= 'string' and type(spec.version) ~= 'table' then
            errors[#errors + 1] = ('%s[%d].version has invalid type'):format(label, i)
        end
    end

    for i, spec in ipairs(plugins) do
        check(spec, i, 'plugins')
    end
    for i, spec in ipairs(lazy_plugins) do
        check(spec, i, 'lazy_plugins')
    end

    return #errors == 0, errors
end

--- @return table[]
function M.specs()
    return plugins
end

function M.setup_plugins()
    for _, spec in ipairs(plugins) do
        local setup = plugin_setup[spec.src]
        if type(setup) == 'function' then
            local ok, err = pcall(setup)
            if not ok then
                vim.schedule(function()
                    vim.notify('Plugin setup failed for ' .. spec.src .. ': ' .. tostring(err), vim.log.levels.ERROR, {
                        title = 'vim.pack',
                    })
                end)
            end
        end
    end
end

function M.bootstrap()
    local ok, errors = M.validate_specs()
    if not ok then
        for _, err in ipairs(errors) do
            vim.notify(err, vim.log.levels.ERROR, {
                title = 'vim.pack spec validation',
            })
        end
        return
    end

    add(plugins, {
        confirm = false,
        load = true,
    })

    M.setup_plugins()
    -- Defer lazy plugins until after UI is ready (reduces startup time)
    vim.api.nvim_create_autocmd('VimEnter', {
        once = true,
        callback = function()
            vim.schedule(function()
                add(lazy_plugins, {
                    confirm = false,
                    load = true,
                })
                for _, spec in ipairs(lazy_plugins) do
                    local setup = plugin_setup[spec.src]
                    if type(setup) == 'function' then
                        pcall(setup)
                    end
                    if spec.data and type(spec.data.config) == 'function' then
                        pcall(spec.data.config)
                    end
                end
            end)
        end,
        desc = 'Load deferred plugins after startup',
    })
end

api.nvim_create_user_command('PackUpdate', function()
    vim.notify('Opening plugin update confirmation buffer…', vim.log.levels.INFO)
    update()
    api.nvim_create_autocmd('BufWritePost', {
        pattern = '*',
        once = true,
        callback = function(ev)
            if ev.buf and vim.bo[ev.buf].buftype == 'acwrite' then
                vim.notify('Plugins updated successfully!', vim.log.levels.INFO)
            end
        end,
    })
end, {
    desc = 'Update all vim.pack plugins (interactive - :write to confirm)',
})

api.nvim_create_user_command('PackUpdateAuto', function()
    vim.notify('Updating plugins (auto-confirm)…', vim.log.levels.INFO)
    local ok, err = pcall(function()
        update(nil, { confirm = true })
    end)
    if ok then
        vim.notify('Plugins updated successfully!', vim.log.levels.INFO)
    else
        vim.notify('Plugin update failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
end, {
    desc = 'Update all vim.pack plugins (auto-confirm, no interaction)',
})

api.nvim_create_user_command('PackAdd', function(opts)
    if opts.args == '' then
        vim.notify('Usage: :PackAdd <github-user>/<repo>', vim.log.levels.WARN)
        return
    end
    local repo = opts.args
    local spec = {
        src = gh(repo),
    }
    if type(spec.src) ~= 'string' or spec.src == '' then
        vim.notify('PackAdd failed: invalid src for ' .. repo, vim.log.levels.ERROR)
        return
    end
    local ok, err = pcall(function()
        add({
            spec,
        }, {
            confirm = false,
            load = true,
        })
    end)
    if not ok then
        vim.notify('PackAdd failed: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end
    vim.notify('Plugin added: ' .. repo, vim.log.levels.INFO)
end, {
    nargs = 1,
    desc = 'Add a new plugin from GitHub',
})

M.bootstrap()
return M
