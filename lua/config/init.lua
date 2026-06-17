-- /qompassai/Diver/lua/config/init.lua
-- Qompass AI Diver Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}

local notify = vim.notify
local env = vim.env
local fmt = string.format
local levels = (vim.log and vim.log.levels)
    or {
        TRACE = 0,
        DEBUG = 1,
        INFO = 2,
        WARN = 3,
        ERROR = 4,
        OFF = 5,
    }
local function safe_require(name, verbose)
    local ok, mod = pcall(require, name)
    if not ok then
        if verbose then
            notify(fmt('[Diver] Failed to load %s: %s', name, mod), levels.ERROR)
        end
        return nil
    end
    if verbose then
        notify(fmt('[Diver] Loaded %s', name), levels.INFO)
    end
    return mod
end
local function call_if_present(mod, method, opts, verbose, label)
    if not mod then
        return
    end
    local fn = mod[method]
    if type(fn) ~= 'function' then
        return
    end
    local ok, err = pcall(fn, opts)
    if not ok and verbose then
        notify(fmt('[Diver] %s.%s failed: %s', label or 'module', method, err), levels.ERROR)
    end
end
function M.config(opts)
    opts = opts or {}
    local verbose = opts.debug == true
    env.FONTCONFIG_DEBUG = 'none'
    safe_require('utils', verbose)
    local keys = safe_require('config.keymaps', verbose)
    if keys and type(keys.setup) == 'function' then
        local ok, err = pcall(keys.setup)
        if not ok and verbose then
            notify(fmt('[Diver] config.keymaps.setup failed: %s', err), levels.ERROR)
        end
    end
    safe_require('config.lazy', verbose)
    if opts.core ~= false then
        safe_require('config.core', verbose)
    end
    if opts.cicd ~= false then
        local cicd = safe_require('config.cicd', verbose)
        call_if_present(cicd, 'cicd_config', opts, verbose, 'config.cicd')
    end
    if opts.cloud ~= false then
        local cloud = safe_require('config.cloud', verbose)
        call_if_present(cloud, 'cloud_config', opts, verbose, 'config.cloud')
    end
    if opts.edu ~= false then
        local edu = safe_require('config.edu', verbose)
        call_if_present(edu, 'edu_config', opts, verbose, 'config.edu')
    end
    if opts.lang ~= false then
        local lang = safe_require('config.lang', verbose)
        call_if_present(lang, 'lang_config', opts, verbose, 'config.lang')
    end
    if opts.nav ~= false then
        local nav = safe_require('config.nav', verbose)
        call_if_present(nav, 'nav_config', opts, verbose, 'config.nav')
    end
    if opts.ui ~= false then
        local ui = safe_require('config.ui', verbose)
        call_if_present(ui, 'ui_config', opts, verbose, 'config.ui')
    end
end

return M
