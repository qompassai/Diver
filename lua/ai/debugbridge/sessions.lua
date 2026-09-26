-- /qompassai/Diver/lua/ai/debugbridge/sessions.lua
-- Qompass AI Debug Bridge: session registry (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Plain-language version: one debug adapter process per
-- language+adapter+target. This registry makes sure AI agents reuse an
-- already-running adapter instead of spawning a second one, counts how
-- many callers share each session, and tears the adapter down when the
-- last caller lets go. Debug targets are validated as absolute paths
-- under the project root; secrets are scrubbed from the launched env.
--
-- Spawn boundary note: this module spawns through
-- require('dap.dap').launch, which funnels into
-- require('dap.session').spawn (the adapter process boundary). The
-- literal require('dap') resolves in this repo to lua/dap/init.lua,
-- Matt's native-debug front end, which has no `launch` -- the nvim-dap
-- core lives at lua/dap/dap.lua (module 'dap.dap').
---@module 'ai.debugbridge.sessions'

local M = {}

---Max env entries accepted from a caller config before refusing (DoS guard).
---@type integer
local ENV_ENTRIES_MAX = 1024

---Env names matching any of these patterns are dropped from config.env
---before launch unless the caller passes keep_env = true.
---@type string[]
local SENSITIVE_ENV_PATTERNS = {
    '^AWS_',
    '_TOKEN$',
    '_SECRET$',
    '_PASSWORD$',
    '_KEY$',
}

---@class ai.debugbridge.sessions.Adapter : dap.ExecutableAdapter
---@field name string|nil human-readable adapter name used in the session key

---@class ai.debugbridge.sessions.Opts
---@field lang string language id, e.g. 'python'
---@field adapter ai.debugbridge.sessions.Adapter executable adapter definition
---@field config dap.Configuration launch configuration (deep-copied, never mutated)
---@field target string absolute path of the debug target
---@field project_root string absolute path; target must sit under it
---@field keep_env boolean? when true, skip env scrubbing

---@class ai.debugbridge.sessions.Entry
---@field session dap.Session live debug session
---@field refcount integer number of active acquire() holders
---@field lang string language id from the acquire opts
---@field target string normalized absolute target path
---@field adapter_name string name or command used in the key

---@class ai.debugbridge.sessions.Info
---@field key string registry key: lang|adapter|target
---@field lang string language id
---@field target string normalized absolute target path
---@field refcount integer current holder count
---@field closed boolean whether the underlying session reports closed

---@type table<string, ai.debugbridge.sessions.Entry>
local registry = {}

--- Best-effort structured logging. Never crashes the caller.
---@param kind string event kind, e.g. 'session_acquire'
---@param detail table<string, any> event payload
---@return boolean logged true when the log module accepted the event
local function log_event(kind, detail)
    local ok, log = pcall(require, 'ai.debugbridge.log')
    if not ok or type(log) ~= 'table' then
        return false
    end
    if type(log.append) == 'function' then
        -- Best-effort by contract: capture the result and return it so a
        -- broken log module never breaks session management.
        local logged = pcall(log.append, kind, detail)
        return logged
    end
    return false
end

---@param path string
---@return boolean
local function is_absolute(path)
    if vim.startswith(path, '/') then
        return true
    end
    return path:match('^[A-Za-z]:[\\/]') ~= nil
end

--- Validate an external target path. Never asserts: all failures are
--- returned as (nil, err). Both sides are resolved with fs_realpath
--- before the containment check, so a symlink inside the project
--- cannot smuggle a target outside of it (proven 2026-09-26:
--- proj/link/secret.py with link -> /outside passed the lexical
--- check). Missing or unresolvable paths are refused: a debug target
--- must exist.
---@param target any caller-supplied target
---@param project_root any caller-supplied project root
---@return string? normalized_target, string? err
local function validate_target(target, project_root)
    if type(target) ~= 'string' or target == '' then
        return nil, 'target must be a non-empty string'
    end
    if type(project_root) ~= 'string' or project_root == '' then
        return nil, 'project_root must be a non-empty string'
    end
    -- Control characters (newlines, escapes) are never legitimate in
    -- a debug target path: besides being un-renderable, they would
    -- ride into the session key and break line-oriented consumers.
    if target:find('[%c]') ~= nil then
        return nil, 'target must not contain control characters'
    end
    if project_root:find('[%c]') ~= nil then
        return nil, 'project_root must not contain control characters'
    end
    local norm_root = vim.fs.normalize(project_root)
    if not is_absolute(norm_root) then
        return nil, 'project_root must be an absolute path'
    end
    -- Scan for '..' BEFORE normalizing: vim.fs.normalize resolves '..'
    -- lexically, which would hide an escape attempt from the check.
    for segment in target:gmatch('[^/\\]+') do
        if segment == '..' then
            return nil, 'target must not contain ".." segments'
        end
    end
    local norm_target = vim.fs.normalize(target)
    if not is_absolute(norm_target) then
        return nil, 'target must be an absolute path'
    end
    local real_root = vim.uv.fs_realpath(norm_root)
    if real_root == nil then
        return nil, 'project_root does not resolve'
    end
    local real_target = vim.uv.fs_realpath(norm_target)
    if real_target == nil then
        return nil, 'target does not exist or resolve'
    end
    -- Re-normalize separators only (never resolves again): realpath
    -- may return backslashes on Windows, which would break the '/'
    -- anchored prefix check below.
    real_root = vim.fs.normalize(real_root)
    real_target = vim.fs.normalize(real_target)
    local under_root = real_target == real_root or vim.startswith(real_target, real_root .. '/')
    if not under_root then
        return nil, 'target must sit under project_root'
    end
    return real_target, nil
end

---@param name string
---@return boolean
local function is_sensitive_env_name(name)
    -- Case-insensitive: a lowercase 'aws_secret_access_key' leaks past
    -- uppercase-only patterns (proven 2026-09-26), and mixed-case
    -- variants are equally secret.
    local upper = name:upper()
    for _, pattern in ipairs(SENSITIVE_ENV_PATTERNS) do
        if upper:match(pattern) then
            return true
        end
    end
    return false
end

--- Deep-copy the caller's config and, unless keep_env, drop sensitive
--- env entries. The caller's table is never mutated.
---@param config dap.Configuration
---@param keep_env boolean
---@return dap.Configuration? config_copy, integer dropped_count, string? err
local function with_scrubbed_env(config, keep_env)
    local copy = vim.deepcopy(config)
    local env = copy.env
    if keep_env or type(env) ~= 'table' then
        return copy, 0, nil
    end
    local count = 0
    local scrubbed = {}
    for name, value in pairs(env) do
        count = count + 1
        if count > ENV_ENTRIES_MAX then
            return nil, 0, 'config.env exceeds ' .. tostring(ENV_ENTRIES_MAX) .. ' entries'
        end
        -- Sensitive names are dropped: secrets stay out of the wire
        -- payload and the dap log.
        local sensitive = type(name) == 'string' and is_sensitive_env_name(name)
        if not sensitive then
            scrubbed[name] = value
        end
    end
    local dropped_count = count - vim.tbl_count(scrubbed)
    copy.env = scrubbed
    return copy, dropped_count, nil
end

--- Ask the adapter to terminate the debuggee over the wire (best
--- effort), then close our side so the adapter process is reaped NOW.
--- There is no Session:terminate in lua/dap/session.lua; the raw
--- uv_process_t lives in Session.spawn's closure and is not exposed on
--- the session object, so close() -> client.close (the sigint/escalate
--- to sigkill onexit closure) is the only kill mechanism available.
---@param session dap.Session
---@return string? first_error
local function teardown(session)
    local first_err = nil
    local ok, err = pcall(session.disconnect, session, { terminateDebuggee = true })
    if not ok then
        first_err = tostring(err)
    end
    local ok_close, err_close = pcall(session.close, session)
    if not ok_close and first_err == nil then
        first_err = tostring(err_close)
    end
    return first_err
end

--- Acquire the shared session for a language+adapter+target.
--- Reuses the live session when one exists (refcount++); otherwise
--- spawns exactly one adapter via the dap layer.
---@param opts ai.debugbridge.sessions.Opts
---@return string? key, dap.Session? session, string? err
function M.acquire(opts)
    if type(opts) ~= 'table' then
        return nil, nil, 'opts must be a table'
    end
    if type(opts.lang) ~= 'string' or opts.lang == '' then
        return nil, nil, 'opts.lang must be a non-empty string'
    end
    -- The session key joins lang, adapter name, and target with '|':
    -- a lang containing '|' would let two different (lang, adapter)
    -- pairs collide on one key and steal each other's session.
    if opts.lang:match('[^A-Za-z0-9_%-]') ~= nil then
        return nil, nil, 'opts.lang must match [A-Za-z0-9_-]+'
    end
    if type(opts.adapter) ~= 'table' then
        return nil, nil, 'opts.adapter must be a dap.ExecutableAdapter table'
    end
    local adapter_name = opts.adapter.name or opts.adapter.command
    if type(adapter_name) ~= 'string' or adapter_name == '' then
        return nil, nil, 'opts.adapter needs a name or command for the session key'
    end
    if type(opts.config) ~= 'table' then
        return nil, nil, 'opts.config must be a dap.Configuration table'
    end
    local target, target_err = validate_target(opts.target, opts.project_root)
    if target == nil then
        return nil, nil, target_err
    end
    local key = opts.lang .. '|' .. adapter_name .. '|' .. target
    local entry = registry[key]
    if entry then
        if entry.session ~= nil and not entry.session.closed then
            -- Live entry: reuse. This branch returns before any spawn,
            -- so a second adapter process for the same key is impossible.
            assert(entry.session ~= nil, 'registry entry must hold a session')
            assert(not entry.session.closed, 'reuse requires a live session')
            entry.refcount = entry.refcount + 1
            log_event('session_reuse', { key = key, refcount = entry.refcount })
            return key, entry.session, nil
        end
        -- Stale entry: the session died underneath us; discard it so a
        -- fresh adapter spawns below.
        registry[key] = nil
    end
    local config_copy, dropped_count, scrub_err = with_scrubbed_env(opts.config, opts.keep_env == true)
    if config_copy == nil then
        return nil, nil, scrub_err
    end
    -- Fail closed when the DAP event-dispatch path is shadowed: the
    -- session layer reads require('dap').listeners on every adapter
    -- event, but in this repo require('dap') resolves to the native
    -- wrapper (lua/dap/init.lua), which has no listeners table -- so a
    -- spawned adapter's first event would crash inside vim.schedule
    -- and strand the process. Refusing here keeps the failure loud
    -- and early instead of spawning a doomed adapter.
    local dap_ok, dap_main = pcall(require, 'dap')
    local listeners_ok = dap_ok
        and type(dap_main) == 'table'
        and type(dap_main.listeners) == 'table'
        and type(dap_main.listeners.before) == 'table'
        and type(dap_main.listeners.after) == 'table'
    if not listeners_ok then
        return nil, nil, "DAP event dispatch unavailable: require('dap').listeners is not a table"
    end
    -- See the module header: 'dap.dap' is the nvim-dap core here.
    local session = require('dap.dap').launch(opts.adapter, config_copy, {})
    if session == nil then
        return nil, nil, 'dap.launch failed to start the adapter for ' .. key
    end
    registry[key] = {
        session = session,
        refcount = 1,
        lang = opts.lang,
        target = target,
        adapter_name = adapter_name,
    }
    log_event('session_acquire', {
        key = key,
        lang = opts.lang,
        target = target,
        refcount = 1,
        env_dropped = dropped_count,
    })
    return key, session, nil
end

--- Release one hold on a session. At refcount 0 the session is torn
--- down and the entry removed.
---@param key string registry key from M.acquire
---@return boolean? ok, string? err
function M.release(key)
    if type(key) ~= 'string' or key == '' then
        return nil, 'key must be a non-empty string'
    end
    local entry = registry[key]
    if entry == nil then
        return nil, 'unknown session key: ' .. key
    end
    entry.refcount = entry.refcount - 1
    if entry.refcount > 0 then
        log_event('session_release', { key = key, refcount = entry.refcount })
        return true, nil
    end
    registry[key] = nil
    local first_err = teardown(entry.session)
    log_event('session_release', { key = key, refcount = 0, terminated = true, error = first_err })
    return true, nil
end

--- Kill a session NOW regardless of refcount: terminate the
--- adapter+debuggee and drop the registry entry.
---@param key string registry key from M.acquire
---@return boolean? ok, string? err
function M.kill(key)
    if type(key) ~= 'string' or key == '' then
        return nil, 'key must be a non-empty string'
    end
    local entry = registry[key]
    if entry == nil then
        return nil, 'unknown session key: ' .. key
    end
    registry[key] = nil
    local first_err = teardown(entry.session)
    log_event('session_kill', { key = key, refcount = entry.refcount, error = first_err })
    return true, nil
end

--- Snapshot of the registry for UI/status. Sorted by key.
---@return ai.debugbridge.sessions.Info[]
function M.list()
    local infos = {}
    for key, entry in pairs(registry) do
        infos[#infos + 1] = {
            key = key,
            lang = entry.lang,
            target = entry.target,
            refcount = entry.refcount,
            closed = entry.session.closed == true,
        }
    end
    table.sort(infos, function(a, b)
        return a.key < b.key
    end)
    return infos
end

--- Fetch the session for a key (e.g. for scanbreak's stop hook).
--- Returns nil for unknown keys; the caller checks .closed itself.
---@param key string registry key from M.acquire
---@return dap.Session?
function M.get(key)
    local entry = type(key) == 'string' and registry[key] or nil
    if entry then
        return entry.session
    end
    return nil
end

return M
