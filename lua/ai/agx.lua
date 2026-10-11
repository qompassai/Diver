-- /qompassai/Diver/lua/ai/agx.lua
-- Qompass AI agx Trace Inspector (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- The agx agent-trace inspector, folded into a single module: entry point,
-- commands, and health check. Nothing runs at require-time; :Agx opens the
-- TUI lazily in a terminal split.

local M = {}

local configured = false

-- :Agx opens the `agx` step-through debugger for AI agent traces in a
-- terminal split. agx replays Claude Code / Codex / Gemini session files
-- (tool calls, timeline, cost); it is trace inspection, not a DAP adapter,
-- and never touches program execution.
--
--   :Agx                       Browse recent sessions interactively
--   :Agx corpus                 Aggregate stats across saved sessions
--   :Agx --summary <session>    Print a session timeline and exit
--   :Agx --scan-pii <session>   Heuristic credential/PII scan of a trace
--
-- Arguments after :Agx pass straight through to agx as argv (never a
-- shell string). They are split on whitespace; paths containing spaces
-- are not supported.

local api = vim.api

local ARGV_MAX = 32

--- Split raw command args on whitespace into an argv tail.
---@param raw string command.args as given
---@return string[]? args
---@return string? err
local function split_args(raw)
    local args = {}
    for token in raw:gmatch('%S+') do
        if #args >= ARGV_MAX then
            return nil, 'too many arguments (max ' .. ARGV_MAX .. ')'
        end
        args[#args + 1] = token
    end
    return args, nil
end

---@param extra string[] argv tail appended after 'agx'
local function open_terminal(extra)
    assert(type(extra) == 'table', 'open_terminal expects an argv table')
    local argv = { 'agx' }
    for _, token in ipairs(extra) do
        argv[#argv + 1] = token
    end
    vim.cmd('botright split')
    vim.fn.jobstart(argv, { term = true })
    vim.cmd('startinsert')
end

local function register_commands()
    api.nvim_create_user_command('Agx', function(command)
        if vim.fn.executable('agx') ~= 1 then
            vim.notify('Agx: `agx` not found on PATH (paru -S aur/agx)', vim.log.levels.ERROR)
            return
        end
        local args, err = split_args(command.args)
        if err ~= nil then
            vim.notify('Agx: ' .. err, vim.log.levels.ERROR)
            return
        end
        assert(args ~= nil, 'split_args returned no args without error')
        open_terminal(args)
    end, {
        nargs = '*',
        complete = 'file',
        desc = 'Open the agx agent-trace inspector in a terminal split (args pass through)',
    })
end

-- Health check; run via require('ai.agx').check().
function M.check()
    local health = vim.health

    health.start('agx: trace inspector')
    if vim.fn.executable('agx') == 1 then
        health.ok('agx found (:Agx opens the session browser)')
    else
        health.warn('agx not found on PATH; :Agx will refuse (paru -S aur/agx)')
    end

    health.start('agx: session sources')
    local found_any = false
    for _, dir in ipairs({ '.claude', '.codex', '.gemini' }) do
        local home = vim.fn.expand('~/' .. dir)
        if vim.fn.isdirectory(home) == 1 then
            health.ok(dir .. '/ exists — agx can browse its sessions')
            found_any = true
        end
    end
    if not found_any then
        health.info('no ~/.claude, ~/.codex, or ~/.gemini dirs yet; nothing to inspect')
    end
end

---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'agx.setup expects a table or nil')
    if configured then
        return
    end
    configured = true
    register_commands()
end

return M
