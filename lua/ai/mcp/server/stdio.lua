-- /qompassai/Diver/lua/ai/mcp/server/stdio.lua
-- Qompass AI MCP Server stdio Transport (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Newline-delimited JSON-RPC over the process's stdio.
--
-- Plain words: bytes arrive on stdin, are split into lines, and each
-- line goes to the protocol engine; responses come back out on stdout.
-- The iron rule: stdout carries ONLY MCP bytes. Logs, warnings, and
-- diagnostics go to stderr. An oversized line is dropped (and logged to
-- stderr) rather than parsed, and the server exits when the client
-- closes stdin.
--
-- The transport is injectable for tests: `start(server, deps)` takes the
-- stdin/stdout/stderr/exit functions as a table, so tests drive the
-- whole stack with fakes. `real_deps()` wires the real vim.uv pipes.
-- Headless entry: `nvim --headless -l <this file> --serve [--root DIR]`.

local M = {}

-- Mirrors ai.mcp.client's framing bound so both sides agree on line size.
local LINE_BYTES_MAX = 8 * 1024 * 1024

---@class McpStdioDeps
---@field open_stdin fun(on_data: fun(data: string?), on_eof: fun()): table?
---@field write_stdout fun(line: string) Writes exactly one MCP line (no newline needed).
---@field log_stderr fun(message: string) All non-MCP output goes here.
---@field exit fun(code: integer)

---@class McpStdioHandle
---@field stop fun() Idempotent teardown.

-- Real vim.uv-backed deps. Asserts Neovim; never called from tests.
---@return McpStdioDeps
function M.real_deps()
    assert(vim ~= nil and vim.uv ~= nil, 'real stdio deps require Neovim')
    local uv = vim.uv
    local deps = {}

    function deps.open_stdin(on_data, on_eof)
        local stdin = uv.new_pipe(false)
        assert(stdin ~= nil, 'cannot create stdin pipe')
        local ok, err = pcall(stdin.open, stdin, 0)
        assert(ok, 'cannot open stdin pipe: ' .. tostring(err))
        stdin:read_start(function(read_err, data)
            if read_err ~= nil then
                io.stderr:write('mcp-server: stdin read error: ' .. tostring(read_err) .. '\n')
                on_eof()
                return
            end
            if data == nil then
                on_eof()
                return
            end
            on_data(data)
        end)
        return stdin
    end

    local stdout = uv.new_pipe(false)
    assert(stdout ~= nil, 'cannot create stdout pipe')
    local ok, err = pcall(stdout.open, stdout, 1)
    assert(ok, 'cannot open stdout pipe: ' .. tostring(err))

    function deps.write_stdout(line)
        -- A failed stdout write means we cannot answer; never crash on it.
        pcall(stdout.write, stdout, line .. '\n')
    end

    function deps.log_stderr(message)
        io.stderr:write(message .. '\n')
    end

    function deps.exit(code)
        os.exit(code, true)
    end

    return deps
end

-- Start pumping stdin lines into the protocol server. Returns an
-- idempotent handle. Never raises after the initial asserts: transport
-- failures are reported on stderr, not thrown.
---@param server table protocol server with handle_line(line)
---@param deps McpStdioDeps
---@return McpStdioHandle
function M.start(server, deps)
    assert(type(server) == 'table' and type(server.handle_line) == 'function', 'server required')
    assert(type(deps) == 'table', 'deps required')
    assert(type(deps.open_stdin) == 'function', 'deps.open_stdin required')
    assert(type(deps.write_stdout) == 'function', 'deps.write_stdout required')
    assert(type(deps.log_stderr) == 'function', 'deps.log_stderr required')
    assert(type(deps.exit) == 'function', 'deps.exit required')

    local buffer = ''
    local stopped = false
    -- Always assigned before handle is returned (or the early-return path
    -- takes a different handle), so no initializer is needed.
    local stdin_handle

    local function on_data(data)
        if stopped or data == nil or data == '' then
            return
        end
        buffer = buffer .. data
        while true do
            local newline = buffer:find('\n', 1, true)
            if newline == nil then
                break
            end
            local line = buffer:sub(1, newline - 1):gsub('\r$', '')
            buffer = buffer:sub(newline + 1)
            if #line > LINE_BYTES_MAX then
                deps.log_stderr('mcp-server: dropped oversized line (' .. #line .. ' bytes)')
            else
                server:handle_line(line)
            end
        end
        -- A peer that never sends a newline cannot grow the buffer forever.
        if #buffer > LINE_BYTES_MAX then
            deps.log_stderr('mcp-server: dropped oversized partial line')
            buffer = ''
        end
    end

    local function on_eof()
        if not stopped then
            stopped = true
            deps.exit(0)
        end
    end

    local ok, handle_or_err = pcall(deps.open_stdin, on_data, on_eof)
    if not ok then
        deps.log_stderr('mcp-server: cannot open stdin: ' .. tostring(handle_or_err))
        deps.exit(1)
        return {
            stop = function() end,
        }
    end
    stdin_handle = handle_or_err

    local handle = {}
    function handle.stop()
        if stopped then
            return
        end
        stopped = true
        if stdin_handle ~= nil and type(stdin_handle.close) == 'function' then
            pcall(stdin_handle.close, stdin_handle)
        end
        stdin_handle = nil
    end
    return handle
end

-- Headless entry: parse `--root DIR` repeats, wire policy + tools +
-- protocol, and pump stdio until the client closes stdin.
---@param argv string[]?
---@return McpStdioHandle
function M.main(argv)
    assert(vim ~= nil, 'mcp-server headless entry requires Neovim')
    argv = argv or {}
    local roots = {}
    local i = 1
    while i <= #argv do
        if argv[i] == '--root' and type(argv[i + 1]) == 'string' then
            roots[#roots + 1] = argv[i + 1]
            i = i + 2
        else
            i = i + 1
        end
    end
    local policy = require('ai.mcp.server.policy')
    local tools = require('ai.mcp.server.tools')
    local protocol = require('ai.mcp.server.protocol')
    policy.setup({ roots = roots })
    tools.setup()
    local deps = M.real_deps()
    local server = protocol.new({
        json = vim.json,
        write = function(line)
            deps.write_stdout(line)
        end,
        tools = tools,
        on_log = function(level, message)
            deps.log_stderr('mcp-server [' .. level .. ']: ' .. message)
        end,
    })
    -- NOTE (unverified in this environment): whether `nvim --headless -l`
    -- keeps the uv loop alive for the stdin pipe, and how a closed stdin
    -- surfaces there, needs a runtime probe on real hardware.
    return M.start(server, deps)
end

-- Entry guard: `nvim --headless -l <this file> --serve [--root DIR]`.
-- When this file is require()d the chunk's `...` is the module name, so
-- the guard never fires from require.
local entry_args = { ... }
if entry_args[1] == '--serve' then
    local rest = {}
    for i = 2, #entry_args do
        rest[#rest + 1] = entry_args[i]
    end
    M.main(rest)
end

return M
