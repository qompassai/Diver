-- /qompassai/Diver/lua/ai/debugbridge/init.lua
-- Qompass AI Debug Bridge Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Top-level wiring for ai.debugbridge: one managed bridge over
-- diver's lua/dap/ full DAP client suite and lua/bsp/ build client so
-- AI agents can drive debugging and builds with session reuse (no
-- repeat adapter processes), security scanning on every launch, and
-- malicious-process quarantine.
--
-- M.setup() spawns NOTHING at startup: no timers, no adapter
-- processes, no socket listener. The socket API starts only when
-- opts.api is true, and only through ai.debugbridge.api.start(). All
-- sibling modules are required inside setup(), never at load time.
--
-- The backend table injected into ai.debugbridge.api closes over the
-- sibling modules so remote/API callers never touch module state
-- directly. Nine functions, each fn(params) -> ok, result_or_err:
-- session_acquire/release/kill, set_breakpoint, launch_scanned (the
-- audited scan -> acquire -> stop-hook pipeline), bsp_build/bsp_targets
-- (callback-style BSP ops adapted to sync via a bounded vim.wait),
-- quarantine, status.

local M = {}

local setup_done = false

---@class DebugbridgeSetupOpts
---@field api boolean? Start the local socket listener via api.start(). Default false.

-- Bound for blocking on callback-style BSP ops inside backend fns.
local BSP_WAIT_MS_MAX = 120000

---Resolve an adapter name to its dap.ExecutableAdapter table.
---@param adapter_name string
---@return table? adapter
---@return string? err
local function resolve_adapter(adapter_name)
    local ok, dap_core = pcall(require, 'dap.dap')
    if not ok or type(dap_core) ~= 'table' then
        return nil, 'dap core unavailable'
    end
    if type(dap_core.adapters) ~= 'table' then
        return nil, 'dap.adapters registry unavailable'
    end
    local adapter = dap_core.adapters[adapter_name]
    if type(adapter) ~= 'table' then
        return nil, 'unknown adapter: ' .. adapter_name
    end
    return adapter, nil
end

---Validate an absolute, traversal-free path. The sibling modules
---re-validate; this is the API boundary's first refusal.
---@param path any
---@return string? valid
---@return string? err
local function validate_abs_path(path)
    if type(path) ~= 'string' or path == '' then
        return nil, 'path must be a non-empty string'
    end
    if path:sub(1, 1) ~= '/' then
        return nil, 'path must be absolute: ' .. path
    end
    if path:find('%.%.') ~= nil then
        return nil, 'path must not contain ..: ' .. path
    end
    if path:find('%z') ~= nil then
        return nil, 'path must not contain NUL'
    end
    return path, nil
end

---Run a callback-style op to completion with a bound. The callback
---fires on the main loop, which vim.wait pumps.
---@param label string Op name for timeout errors
---@param starter fun(cb: fun(err: string?, result: any?))
---@return boolean ok
---@return any result_or_err
local function await_callback_op(label, starter)
    local done = false
    local op_err = nil
    local op_result = nil
    starter(function(err, result)
        op_err = err
        op_result = result
        done = true
    end)
    local finished = vim.wait(BSP_WAIT_MS_MAX, function()
        return done
    end, 50)
    if not finished then
        return false, label .. ' timed out after ' .. tostring(BSP_WAIT_MS_MAX) .. 'ms'
    end
    if op_err ~= nil then
        return false, tostring(op_err)
    end
    return true, op_result
end

---Build the backend table the socket API expects: nine functions, each
---`fn(params) -> ok, result_or_err`. Every entry closes over the
---sibling module passed in so API callers never touch module state
---directly. Arities mirror the sibling modules exactly:
---sessions.acquire(opts) -> key, session, err (spawns the adapter;
---there is no separate launch step), scanbreak.gate(files, opts) ->
---result, err, scanbreak.install_stop_hook(key, flagged, ctx),
---bsp.ensure/build_targets/list_targets(root, ..., callback) adapted
---to sync via await_callback_op, log.append(kind, detail).
---@param sessions table ai.debugbridge.sessions module.
---@param scanbreak table ai.debugbridge.scanbreak module.
---@param bsp table ai.debugbridge.bsp module.
---@return table backend
local function build_backend(sessions, scanbreak, bsp)
    assert(type(sessions) == 'table', 'build_backend requires the sessions module')
    assert(type(scanbreak) == 'table', 'build_backend requires the scanbreak module')
    assert(type(bsp) == 'table', 'build_backend requires the bsp module')
    ---Quarantine an artifact path via ai.security for the scanbreak
    ---stop hook. Without this the hook kills a flagged session but
    ---reports "no artifact quarantined: ctx.quarantine_fn missing".
    ---@param path string
    ---@return string? dest, string? err
    local function quarantine_artifact(path)
        local ok, sec = pcall(require, 'ai.security')
        if not ok or type(sec) ~= 'table' or type(sec.quarantine) ~= 'function' then
            return nil, 'ai.security quarantine unavailable'
        end
        local qok, dest, qerr = pcall(sec.quarantine, path)
        if not qok then
            return nil, 'quarantine raised: ' .. tostring(dest)
        end
        if dest == nil then
            return nil, qerr
        end
        return dest, nil
    end
    return {
        session_acquire = function(params)
            local adapter, aerr = resolve_adapter(params.adapter_name)
            if adapter == nil then
                return false, aerr
            end
            local key, _, err = sessions.acquire({
                lang = params.lang,
                adapter = adapter,
                config = {
                    type = params.adapter_name,
                    request = 'launch',
                    name = 'debugbridge: ' .. params.target,
                    program = params.target,
                },
                target = params.target,
                project_root = params.project_root,
            })
            if key == nil then
                return false, err
            end
            return true, { key = key }
        end,
        session_release = function(params)
            local ok, err = sessions.release(params.key)
            if not ok then
                return false, err
            end
            return true, { released = true }
        end,
        session_kill = function(params)
            local ok, err = sessions.kill(params.key)
            pcall(scanbreak.remove_stop_hook, params.key)
            if not ok then
                return false, err
            end
            return true, { killed = true }
        end,
        set_breakpoint = function(params)
            local path, perr = validate_abs_path(params.file)
            if path == nil then
                return false, perr
            end
            local ok, bp = pcall(require, 'dap.breakpoints')
            if not ok or type(bp) ~= 'table' or type(bp.set) ~= 'function' then
                return false, 'dap.breakpoints unavailable'
            end
            local bufnr_ok, bufnr = pcall(vim.fn.bufadd, path)
            if not bufnr_ok or type(bufnr) ~= 'number' then
                return false, 'bufadd failed: ' .. tostring(bufnr)
            end
            local set_ok, set_err = pcall(bp.set, {}, bufnr, params.line)
            if not set_ok then
                return false, 'breakpoints.set failed: ' .. tostring(set_err)
            end
            return true, { file = path, line = params.line }
        end,
        launch_scanned = function(params)
            local target, terr = validate_abs_path(params.target)
            if target == nil then
                return false, terr
            end
            local adapter, aerr = resolve_adapter(params.adapter_name)
            if adapter == nil then
                return false, aerr
            end
            local files = params.files
            if files == nil then
                files = { target }
            end
            local gate_ok, result, gate_err = pcall(scanbreak.gate, files, { project_root = params.project_root })
            if not gate_ok then
                return false, 'scanbreak.gate raised: ' .. tostring(result)
            end
            if result == nil then
                return false, 'refused by scanbreak.gate: ' .. tostring(gate_err)
            end
            local verdict = type(result) == 'table' and result.verdict or nil
            if verdict ~= 'clean' and verdict ~= 'suspicious' then
                return false, 'refused: scanbreak verdict ' .. tostring(verdict)
            end
            local key, _, acquire_err = sessions.acquire({
                lang = params.lang,
                adapter = adapter,
                config = {
                    type = params.adapter_name,
                    request = 'launch',
                    name = 'debugbridge: ' .. target,
                    program = target,
                },
                target = target,
                project_root = params.project_root,
            })
            if key == nil then
                return false, acquire_err
            end
            local flagged = (type(result) == 'table') and result.flagged or {}
            local hook_ok, hooked, hook_err = pcall(
                scanbreak.install_stop_hook,
                key,
                flagged,
                { sessions_module = sessions, quarantine_fn = quarantine_artifact }
            )
            return true,
                {
                    key = key,
                    verdict = verdict,
                    stop_hook = hook_ok and hooked == true,
                    hook_error = (not hook_ok or not hooked) and tostring(hook_err or hooked) or nil,
                }
        end,
        bsp_build = function(params)
            return await_callback_op('bsp_build', function(cb)
                bsp.ensure(params.root, function(ensure_err)
                    if ensure_err ~= nil then
                        cb(ensure_err)
                        return
                    end
                    bsp.build_targets(params.root, params.targets, cb)
                end)
            end)
        end,
        bsp_targets = function(params)
            return await_callback_op('bsp_targets', function(cb)
                bsp.ensure(params.root, function(ensure_err)
                    if ensure_err ~= nil then
                        cb(ensure_err)
                        return
                    end
                    bsp.list_targets(params.root, cb)
                end)
            end)
        end,
        quarantine = function(params)
            local path, perr = validate_abs_path(params.path)
            if path == nil then
                return false, perr
            end
            local ok, sec = pcall(require, 'ai.security')
            if not ok or type(sec) ~= 'table' or type(sec.quarantine) ~= 'function' then
                return false, 'ai.security quarantine unavailable'
            end
            local qok, dest, qerr = pcall(sec.quarantine, path)
            if not qok then
                return false, 'quarantine raised: ' .. tostring(dest)
            end
            if dest == nil then
                return false, qerr
            end
            return true, { quarantined_to = dest }
        end,
        status = function(_params)
            local entry = {}
            local list_ok, list = pcall(sessions.list)
            entry.sessions = (list_ok and type(list) == 'table') and list or {}
            local bsp_ok, bsp_layer = pcall(require, 'bsp')
            if bsp_ok and type(bsp_layer) == 'table' and type(bsp_layer.state) == 'table' then
                local live_sessions = bsp_layer.state.sessions
                if type(live_sessions) == 'table' then
                    local roots = {}
                    for root in pairs(live_sessions) do
                        roots[#roots + 1] = root
                    end
                    table.sort(roots)
                    entry.bsp_roots = roots
                end
            end
            return true, entry
        end,
    }
end

---Wire the debug bridge. Idempotent: a second call returns true
---without re-registering anything.
---@param opts? DebugbridgeSetupOpts
---@return boolean ok
function M.setup(opts)
    if setup_done then
        return true
    end
    assert(opts == nil or type(opts) == 'table', 'debugbridge.setup expects a table or nil')

    local sessions = require('ai.debugbridge.sessions')
    local scanbreak = require('ai.debugbridge.scanbreak')
    local bsp = require('ai.debugbridge.bsp')
    local api = require('ai.debugbridge.api')
    assert(type(api.set_backend) == 'function', 'ai.debugbridge.api has no set_backend()')
    api.set_backend(build_backend(sessions, scanbreak, bsp))

    require('ai.debugbridge.log').setup()
    require('ai.debugbridge.commands').register()

    if opts ~= nil and opts.api == true then
        assert(type(api.start) == 'function', 'ai.debugbridge.api has no start()')
        api.start()
    end

    setup_done = true
    return true
end

return M
