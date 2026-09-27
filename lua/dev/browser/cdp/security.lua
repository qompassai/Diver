-- lua/dev/browser/cdp/security.lua
-- CDP security policy: localhost-only gate, isolated-profile rule, and
-- explicit per-invocation confirmation for privileged operations.
-- Plain words: this module says "no" for you. Non-loopback hosts are a
-- hard error with no override flag in the MVP; launched browsers always
-- get a fresh throwaway profile; JS evaluation and attaching to a
-- running browser each require the user to say yes with full context.
-- Copyright (C) 2026 Qompass AI. All rights reserved.
-- SPDX-License-Identifier: Apache-2.0
---@module 'dev.browser.cdp.security'

local M = {}

local HOST_DISPLAY_MAX = 64 -- cap on host text echoed in errors
local EVAL_EXPRESSION_MAX = 65536 -- 64 KiB cap on expressions sent for confirmation
local PROFILE_RANDOM_DIGITS = 6

-- Exact-match allowlist. No suffix games: "127.0.0.1.evil.com" is out.
local LOOPBACK_HOSTS = {
    ['127.0.0.1'] = true,
    ['::1'] = true,
    ['localhost'] = true,
}

---@param host any
---@return boolean
function M.is_loopback(host)
    if type(host) ~= 'string' then
        return false
    end
    return LOOPBACK_HOSTS[host:lower()] == true
end

---Hard gate: non-loopback hosts are refused with no override flag.
---@param host any
---@return boolean|nil ok
---@return string|nil err
function M.check_host(host)
    if not M.is_loopback(host) then
        local shown = tostring(host)
        if #shown > HOST_DISPLAY_MAX then
            shown = shown:sub(1, HOST_DISPLAY_MAX) .. '...'
        end
        return nil, "refusing non-loopback host '" .. shown .. "': CDP client is localhost-only"
            .. ' (no override in MVP)'
    end
    return true
end

---Fresh throwaway profile directory for :BrowserOpen. Never the user's
---real Chrome profile; the caller creates the directory if needed.
---@return string|nil path
---@return string|nil err
function M.new_temp_profile()
    local v = rawget(_G, 'vim')
    if v == nil or v.fn == nil or v.fn.tempname == nil then
        return nil, 'vim.fn.tempname unavailable'
    end
    local base = v.fn.tempname()
    if type(base) ~= 'string' or base == '' then
        return nil, 'vim.fn.tempname returned nothing usable'
    end
    local suffix = ''
    for _ = 1, PROFILE_RANDOM_DIGITS do
        suffix = suffix .. tostring(math.random(0, 9))
    end
    local stamp = 0
    if v.uv ~= nil and v.uv.hrtime ~= nil then
        stamp = v.uv.hrtime()
    end
    return base .. '-cdp-profile-' .. tostring(stamp) .. '-' .. suffix
end

---Remove a throwaway profile created by new_temp_profile. Idempotent:
---a missing path is a success. Paths without the '-cdp-profile-'
---marker are refused, so a real Chrome profile is never touched.
---@param path any
---@return boolean|nil ok
---@return string|nil err
function M.remove_temp_profile(path)
    if type(path) ~= 'string' or path == '' then
        return nil, 'no profile path'
    end
    if path:find('-cdp-profile-', 1, true) == nil then
        return nil, 'refusing to delete a non-diver profile path'
    end
    local v = rawget(_G, 'vim')
    if v == nil or v.fn == nil or v.fn.delete == nil then
        return nil, 'vim.fn.delete unavailable'
    end
    local ok, err = pcall(v.fn.delete, path, 'rf')
    if not ok then
        return nil, 'profile cleanup failed: ' .. tostring(err)
    end
    return true
end

---@class CdpConfirmEvalOpts
---@field expression string exact JS to evaluate
---@field url string target page URL for context
---@field ui? { select: fun(items: string[], opts: table, on_choice: fun(choice: string|nil)) }

---Per-invocation eval confirmation, mirroring ai/mcp/tools.lua: the
---decision is async via on_decision(allowed, reason). The prompt shows
---the exact expression plus the target URL; expressions over
---EVAL_EXPRESSION_MAX bytes are refused before any prompt. UI failure denies.
---@param opts CdpConfirmEvalOpts
---@param on_decision fun(allowed: boolean, reason: string)
function M.confirm_eval(opts, on_decision)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(on_decision) == 'function', 'on_decision must be a function')
    if type(opts.expression) ~= 'string' or opts.expression == '' then
        on_decision(false, 'empty expression')
        return
    end
    if #opts.expression > EVAL_EXPRESSION_MAX then
        on_decision(false, 'expression exceeds 64 KiB')
        return
    end
    if type(opts.url) ~= 'string' or opts.url == '' then
        on_decision(false, 'missing target url')
        return
    end
    -- The prompt carries the exact expression: nothing is truncated,
    -- so what the user approves is byte-for-byte what gets evaluated.
    local prompt = 'Evaluate JavaScript in the attached page?\n\nURL: '
        .. opts.url
        .. '\n\nExpression:\n'
        .. opts.expression
    local ui = opts.ui
    if ui == nil then
        local v = rawget(_G, 'vim')
        ui = v and v.ui or nil
    end
    if ui == nil or type(ui.select) ~= 'function' then
        on_decision(false, 'confirmation UI unavailable')
        return
    end
    local choices = { 'Evaluate', 'Cancel' }
    local function on_choice(choice)
        if choice == 'Evaluate' then
            on_decision(true, 'confirmed in prompt')
        else
            on_decision(false, 'cancelled')
        end
    end
    local ui_ok, ui_err = pcall(ui.select, choices, { prompt = prompt }, on_choice)
    if not ui_ok then
        on_decision(false, 'confirmation UI unavailable: ' .. tostring(ui_err))
    end
end

---@class CdpConfirmAttachOpts
---@field title string target title for context
---@field url string target URL for context
---@field ui? { select: fun(items: string[], opts: table, on_choice: fun(choice: string|nil)) }

---Attaching to a running browser can read all its tabs, so it needs an
---explicit yes naming the target. Same async on_decision contract.
---@param opts CdpConfirmAttachOpts
---@param on_decision fun(allowed: boolean, reason: string)
function M.confirm_attach(opts, on_decision)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(on_decision) == 'function', 'on_decision must be a function')
    if type(opts.url) ~= 'string' or opts.url == '' then
        on_decision(false, 'missing target url')
        return
    end
    local prompt = 'Attach to this running browser target?\n\nTitle: '
        .. tostring(opts.title)
        .. '\nURL: '
        .. opts.url
        .. '\n\nAttaching can observe every open tab.'
    local ui = opts.ui
    if ui == nil then
        local v = rawget(_G, 'vim')
        ui = v and v.ui or nil
    end
    if ui == nil or type(ui.select) ~= 'function' then
        on_decision(false, 'confirmation UI unavailable')
        return
    end
    local choices = { 'Attach', 'Cancel' }
    local function on_choice(choice)
        if choice == 'Attach' then
            on_decision(true, 'confirmed in prompt')
        else
            on_decision(false, 'cancelled')
        end
    end
    local ui_ok, ui_err = pcall(ui.select, choices, { prompt = prompt }, on_choice)
    if not ui_ok then
        on_decision(false, 'confirmation UI unavailable: ' .. tostring(ui_err))
    end
end

return M
