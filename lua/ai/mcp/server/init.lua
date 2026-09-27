-- /qompassai/Diver/lua/ai/mcp/server/init.lua
-- Qompass AI MCP Server Setup (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- In-editor wiring for the MCP server. `setup()` is idempotent and
-- registers the `:McpServer` command; requiring this module has no side
-- effects. The server itself runs as a separate headless process
-- (`nvim --headless -l lua/ai/mcp/server/stdio.lua --serve`); `:McpServer
-- start` spawns that child with pipes held open, `stop` terminates it,
-- and `status` reports on it.

local M = {}

local started = false
local child = nil ---@type { proc: any, pid: integer, roots: string[] }?

---@return string absolute path of the headless entry script
local function script_path()
    local source = debug.getinfo(1, 'S').source:sub(2)
    local dir = source:match('^(.*)/[^/]*$')
    assert(dir ~= nil, 'cannot locate server script directory')
    return dir .. '/stdio.lua'
end

-- Start the headless server as a child process. Stdin is held open (never
-- EOF) so the child lives until stopped; stdout is drained; stderr goes
-- to the editor's stderr.
---@param roots string[]
local function cmd_start(roots)
    if child ~= nil then
        local msg = 'McpServer: already running (pid ' .. tostring(child.pid) .. ')'
        vim.notify(msg, vim.log.levels.WARN)
        return
    end
    local argv = { vim.v.progpath, '--headless', '-l', script_path(), '--serve' }
    for _, root in ipairs(roots) do
        argv[#argv + 1] = '--root'
        argv[#argv + 1] = root
    end
    local proc_holder = {}
    local proc = vim.system(argv, {
        stdin = true,
        stdout = function() end,
        stderr = function(_, data)
            if data ~= nil then
                io.stderr:write('[mcp-server] ' .. data)
            end
        end,
    }, function(result)
        if proc_holder.proc ~= nil and child ~= nil and child.proc == proc_holder.proc then
            child = nil
        end
        vim.schedule(function()
            vim.notify('McpServer: exited with code ' .. tostring(result.code), vim.log.levels.WARN)
        end)
    end)
    proc_holder.proc = proc
    child = { proc = proc, pid = proc.pid, roots = roots }
    vim.notify('McpServer: started (pid ' .. tostring(proc.pid) .. ')', vim.log.levels.INFO)
end

local function cmd_stop()
    if child == nil then
        vim.notify('McpServer: not running', vim.log.levels.WARN)
        return
    end
    local proc = child.proc
    child = nil
    pcall(proc.kill, proc, 'sigterm')
    vim.notify('McpServer: stopped', vim.log.levels.INFO)
end

local function cmd_status()
    if child == nil then
        vim.notify('McpServer: not running', vim.log.levels.INFO)
        return
    end
    local msg = 'McpServer: running (pid ' .. tostring(child.pid) .. ', roots: '
        .. table.concat(child.roots, ', ')
        .. ')'
    vim.notify(msg, vim.log.levels.INFO)
end

---@param fargs string[]
local function dispatch(fargs)
    local sub = fargs[1]
    if sub == 'start' then
        local roots = {}
        local i = 2
        while i <= #fargs do
            if fargs[i] == '--root' and fargs[i + 1] ~= nil then
                roots[#roots + 1] = fargs[i + 1]
                i = i + 2
            else
                i = i + 1
            end
        end
        if #roots == 0 then
            roots[1] = vim.fn.getcwd()
        end
        cmd_start(roots)
    elseif sub == 'stop' then
        cmd_stop()
    elseif sub == 'status' then
        cmd_status()
    else
        vim.notify('McpServer: usage: start [--root DIR] | stop | status', vim.log.levels.ERROR)
    end
end

-- Idempotent setup: policy + tool registration and the :McpServer
-- command. Safe to call more than once; requiring this module alone
-- changes nothing.
---@return boolean
function M.setup()
    if started then
        return true
    end
    assert(vim ~= nil and vim.api ~= nil, 'McpServer setup requires Neovim')
    local policy = require('ai.mcp.server.policy')
    local tools = require('ai.mcp.server.tools')
    policy.setup({})
    tools.setup()
    vim.api.nvim_create_user_command('McpServer', function(opts)
        dispatch(opts.fargs)
    end, {
        nargs = '*',
        desc = 'Manage the diver MCP server (start [--root DIR] | stop | status)',
        complete = function(arg_lead)
            local subs = { 'start', 'stop', 'status' }
            local out = {}
            for _, sub in ipairs(subs) do
                if sub:sub(1, #arg_lead) == arg_lead then
                    out[#out + 1] = sub
                end
            end
            return out
        end,
    })
    started = true
    return true
end

return M
