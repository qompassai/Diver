#!/usr/bin/env luajit
---@version >5.1
-- /qompassai/Diver/lua/config/init.lua
-- Qompass AI Diver Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}

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
local notify = vim.notify
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
-- Core submodule loader (folded from lua/config/core/init.lua): the
-- core leaves are required directly, in the aggregator's order, under
-- the same fail-soft envelope safe_require gave the aggregator -- the
-- first failing leaf stops the rest and is reported, never thrown.
local function load_core()
    require('config.core.async')
    require('config.core.filetype')
    -- Deferred: config.core.lint loads on BufReadPre via init.lua (saves ~8ms).
    require('config.core.lsp')
    require('config.core.parser')
    require('config.core.qf')
    require('config.core.refactor')
    require('config.core.tree')
    require('config.core.whichkey')
end
function M.config(opts)
    opts = opts or {}
    local verbose = opts.debug == true
    env.FONTCONFIG_DEBUG = 'none'
    safe_require('utils', verbose)
    local keys = safe_require('config.mappings', verbose)
    if keys and type(keys.setup) == 'function' then
        local ok, err = pcall(keys.setup)
        if not ok and verbose then
            notify(fmt('[Diver] config.mappings.setup failed: %s', err), levels.ERROR)
        end
    end
    safe_require('config.lazy', verbose)
    if opts.core ~= false then
        local ok, err = pcall(load_core)
        if not ok then
            if verbose then
                notify(fmt('[Diver] Failed to load config.core: %s', err), levels.ERROR)
            end
        elseif verbose then
            notify('[Diver] Loaded config.core', levels.INFO)
        end
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
    -- LSP bootstrap: enables servers from lsp/<name>_ls.lua on first FileType.
    -- (lsp/init.lua is not auto-loaded by Neovim; this module is the loader.)
    if opts.lsp ~= false then
        local lsp = safe_require('config.lsp', verbose)
        call_if_present(lsp, 'setup', opts, verbose, 'config.lsp')
    end
end

return M
