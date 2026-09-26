-- /qompassai/Diver/lua/ai/rose/flow.lua
-- Flow MCP workflow client with writer-ownership fencing (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Spawns the configured Flow binary over MCP stdio and routes tool calls
-- to it. Cancellation never silently downgrades protection: the writer
-- slot is released only after the owned Flow process has exited.

local M = {}

---@param config table resolved Rose config
function M.setup(config)
    assert(type(config) == 'table', 'flow.setup: config must be a table')
    M.stop()
    M.config = config
end

---@param callback fun(err: string?, client: table?)
function M.connect(callback)
    assert(type(callback) == 'function', 'flow.connect: callback must be a function')
    if M.stopping then
        callback('Flow is still stopping; writer ownership has not been released')
        return
    end
    if M.client and M.client.ready and not M.client.closed then
        callback(nil, M.client)
        return
    end
    if M.connecting then
        table.insert(M.waiters, callback)
        return
    end
    M.connecting, M.waiters = true, { callback }
    local epoch, config = M.epoch, M.config
    local function connected(err, client)
        if epoch ~= M.epoch then
            if client then
                client:close('Flow superseded')
            end
            return
        end
        M.connecting = false
        local waiters = M.waiters or {}
        M.waiters = {}
        for _, waiter in ipairs(waiters) do
            waiter(err, client)
        end
    end
    local argv = vim.deepcopy(config.flow.cmd)
    if type(argv) ~= 'table' or #argv == 0 then
        connected('flow.cmd must be an explicit argv array')
        return
    end
    vim.list_extend(argv, { '--workspace', config.workspace })
    if config.trusted then
        argv[#argv + 1] = '--trusted'
    end
    M.bridge_error = nil
    if config.flow.bridge ~= false then
        local socket, err = require('ai.rose.bridge').start()
        if not socket then
            M.bridge_error = err or 'private editor bridge unavailable'
            connected('Flow editor bridge required: ' .. M.bridge_error)
            return -- Never silently downgrade to unprotected trusted disk writes.
        end
        vim.list_extend(argv, { '--nvim', socket })
    end
    M.client = require('ai.rose.mcp').start({
        cmd = argv,
        cwd = config.workspace,
        timeout = config.flow.timeout,
    }, connected)
end

-- Extract the JSON report from an MCP tool result: structuredContent first, then the first
-- text part that decodes as JSON. Returns nil when no report is present.
---@param result table
---@return table? report
local function result_report(result)
    if type(result.structuredContent) == 'table' then
        return result.structuredContent
    end
    if type(result.content) ~= 'table' then
        return nil
    end
    for _, part in ipairs(result.content or {}) do
        if type(part) == 'table' and part.type == 'text' and type(part.text) == 'string' then
            local ok, decoded = pcall(vim.json.decode, part.text)
            if ok and type(decoded) == 'table' then
                return decoded
            end
        end
    end
    return nil
end

---@param name string tool name
---@param args table?
---@param callback fun(err: string?, report: table?)
---@return table token
function M.call(name, args, callback)
    assert(type(name) == 'string', 'flow.call: name must be a string')
    assert(type(callback) == 'function', 'flow.call: callback must be a function')
    local token, finished, stopping = {}, false, false
    local function finish(err, result)
        if finished then
            return
        end
        finished = true
        callback(err, result)
    end
    local function halt(err, result)
        if finished or stopping then
            return
        end
        stopping = true
        -- A cancellation notification is not an execution fence. Revoke the socket
        -- and wait for the owned Flow process to exit before completing the caller.
        M.stop(function()
            finish(err, result)
        end)
    end
    function token.cancel()
        halt('cancelled')
    end
    local function called(call_err, result)
        if finished or stopping then
            return
        end
        if call_err then
            halt(call_err)
            return
        end
        if type(result) ~= 'table' then
            halt('Flow returned invalid MCP result')
            return
        end
        local report = result_report(result)
        if type(report) ~= 'table' then
            halt('Flow result does not contain a JSON report')
            return
        end
        if result.isError then
            finish('Flow tool failed: ' .. tostring(report.error or report.status or 'unknown error'), report)
        else
            finish(nil, report)
        end
    end
    M.connect(function(err, client)
        if finished or stopping then
            return
        end
        if err or not client then
            halt(err or 'Flow connected without an MCP client')
            return
        end
        client:call_tool(name, args, called, M.config.flow.timeout)
    end)
    return token
end

local EXIT_CONFIRM_POLL_MS = 10
local EXIT_WARN_AFTER_MS = 2500

---@param callback fun()? run when the writer fence is released
function M.stop(callback)
    if M.stopping then
        if callback then
            table.insert(M.stopping.callbacks, callback)
        end
        return
    end
    M.epoch = (M.epoch or 0) + 1
    local client = M.client
    M.client, M.connecting = nil, false
    local waiters = M.waiters or {}
    M.waiters = {}
    local bridge = package.loaded['ai.rose.bridge']
    if bridge then
        bridge.stop()
    end
    local callbacks, state = callback and { callback } or {}, nil
    local function complete()
        if state and M.stopping == state then
            M.stopping = nil
        end
        for _, waiter in ipairs(waiters) do
            waiter('Flow stopped')
        end
        for _, done in ipairs(callbacks) do
            done()
        end
    end
    if not client or client.exited or not client.process then
        if client then
            client:close('Flow stopped')
        end
        vim.schedule(complete)
        return
    end
    state = { client = client, callbacks = callbacks }
    M.stopping = state
    client:close('Flow stopped') -- EOF + TERM; MCP escalates to KILL after 500ms.
    local uv, elapsed, warned = vim.uv or vim.loop, 0, false
    local timer = uv.new_timer()
    M.stopping.timer = timer
    if not timer then
        -- Preserve the writer fence: only the MCP exit callback may release it.
        client.on_exit = complete
        return
    end
    timer:start(
        0,
        EXIT_CONFIRM_POLL_MS,
        vim.schedule_wrap(function()
            if client.exited then
                timer:stop()
                timer:close()
                complete()
                return
            end
            elapsed = elapsed + EXIT_CONFIRM_POLL_MS
            if elapsed >= EXIT_WARN_AFTER_MS and not warned then
                warned = true
                vim.notify(
                    'Rose: cannot yet confirm Flow exit; writer remains locked for safety.',
                    vim.log.levels.ERROR
                )
            end
        end)
    )
end

return M
