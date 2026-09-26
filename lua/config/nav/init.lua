#!/usr/bin/env luajit
---@version >5.1
-- /qompassai/Diver/lua/config/nav/init.lua
-- Qompass AI Diver Nav Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}

local notify = vim.notify
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
    if type(mod) ~= 'table' then
        if verbose then
            notify(
                fmt(
                    "[Diver] %s loaded but returned %s instead of a table (missing 'return M'?); skipping setup",
                    name,
                    type(mod)
                ),
                levels.WARN
            )
        end
        return nil
    end
    if verbose then
        notify(fmt('[Diver] Loaded %s', name), levels.INFO)
    end
    return mod
end

local function call_if_present(mod, method, opts, verbose, label)
    if type(mod) ~= 'table' then
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

local SUBMODULES = {
    'config.nav.fzf',
    'config.nav.nt',
    'config.nav.ripgrep',
    'config.nav.searxng',
}

---@param opts table?
function M.nav_config(opts)
    opts = opts or {}
    local verbose = opts.debug == true
    for _, name in ipairs(SUBMODULES) do
        local mod = safe_require(name, verbose)
        call_if_present(mod, 'setup', opts, verbose, name)
    end
end

return M
