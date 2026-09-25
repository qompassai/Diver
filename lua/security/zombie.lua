--- Zombie-process guard — the "clean up your toys" rule.
---
--- Plain-language version: when Neovim starts a helper program in the
--- background (a "job"), that program should go away when we are done with it.
--- Sometimes it does not -- it keeps running invisibly, eating memory, and
--- piling up. Those leftovers are called zombie processes. This module keeps a
--- small guest list (at most JOB_MAX entries) of every background job it
--- starts, can tell you who is still at the party, and its reap() function
--- politely asks stragglers to leave (SIGTERM) and, if they refuse, shows
--- them the door (SIGKILL), then crosses them off the list.
---
--- Sources: `:h vim.system` (SystemObj fields .pid, methods :kill(),
--- :is_closing(), :wait()), `:h uv` (vim.uv.kill for signal-0 liveness
--- probes, vim.uv.now for ages).
---@module 'security.zombie'

local uv = vim.uv

local M = {}

local JOB_MAX = 64 -- hard cap on tracked background jobs.
local KILL_WAIT_MS_MAX = 2000 -- how long to wait for SIGTERM to take effect.
local KILL_POLL_MS = 50 -- liveness re-check interval while waiting.
local SIGNAL_ZERO = 0 -- signal 0: liveness probe, delivers nothing.

---@class security.ZombieEntry
---@field pid integer OS process id.
---@field cmd string Human-readable command line (for reports only).
---@field obj vim.SystemObj Owning handle; killing goes through this.
---@field started_ms integer vim.uv.now() timestamp at spawn.

---@type security.ZombieEntry[]
local registry = {}

---@param pid integer
---@return boolean alive True when the OS still has this process.
local function process_alive(pid)
    return uv.kill(pid, SIGNAL_ZERO) == 0
end

---@param entry security.ZombieEntry
---@return boolean alive
local function entry_alive(entry)
    -- A defunct-but-unreaped child still answers signal 0, so also require
    -- the libuv handle to be open.
    return process_alive(entry.pid) and not entry.obj:is_closing()
end

---Wait (bounded) for a process to die after being signalled.
---@param entry security.ZombieEntry
---@return boolean died
local function wait_for_death(entry)
    local waited_ms = 0
    while waited_ms < KILL_WAIT_MS_MAX do
        if not entry_alive(entry) then
            return true
        end
        vim.wait(KILL_POLL_MS)
        waited_ms = waited_ms + KILL_POLL_MS
    end
    return not entry_alive(entry)
end

---@param argv any
---@return string[]|nil argv_copy
---@return string|nil err
local function validate_argv(argv)
    if type(argv) ~= 'table' or #argv < 1 then
        return nil, 'spawn expects a non-empty argv table'
    end
    local argv_copy = {}
    for index = 1, #argv do
        if type(argv[index]) ~= 'string' then
            return nil, 'spawn argv[' .. index .. '] must be a string'
        end
        argv_copy[index] = argv[index]
    end
    return argv_copy, nil
end

---Spawn a background job and register it. The registry is bounded: when it
---is full the spawn is refused (explicitly, not silently) until reap()
---frees space. argv form only -- no shell is ever involved.
---@param argv string[] Command name plus arguments.
---@param opts? { cwd?: string, env?: table<string,string> }
---@return integer|nil pid Process id on success.
---@return string|nil err
function M.spawn(argv, opts)
    local spawn_argv, argv_err = validate_argv(argv)
    if argv_err ~= nil then
        return nil, argv_err
    end
    assert(spawn_argv ~= nil, 'validate_argv returned no error but no argv')
    if #registry >= JOB_MAX then
        return nil, 'job registry full (' .. JOB_MAX .. '): call reap() before spawning more'
    end
    opts = opts or {}
    -- vim.system throws when the command cannot be started.
    local spawn_ok, system_obj = pcall(vim.system, spawn_argv, {
        text = true,
        cwd = opts.cwd,
        env = opts.env,
    })
    if not spawn_ok or system_obj == nil then
        return nil, 'spawn failed: ' .. tostring(system_obj)
    end
    local pid = system_obj.pid
    if type(pid) ~= 'number' then
        pcall(function()
            system_obj:kill('sigkill')
        end)
        return nil, 'spawned process has no pid'
    end
    registry[#registry + 1] = {
        pid = pid,
        cmd = table.concat(spawn_argv, ' '),
        obj = system_obj,
        started_ms = uv.now(),
    }
    return pid, nil
end

---Snapshot of currently tracked jobs. Returns copies, never the live entries.
---@return { pid: integer, cmd: string, age_ms: integer }[]
function M.list()
    local now_ms = uv.now()
    local snapshot = {}
    for index, entry in ipairs(registry) do
        snapshot[index] = { pid = entry.pid, cmd = entry.cmd, age_ms = now_ms - entry.started_ms }
    end
    return snapshot
end

---@return integer count
function M.count()
    return #registry
end

---Drop registry entries whose processes are already gone. Returns how many
---were pruned.
---@return integer pruned_count
function M.prune()
    local pruned_count = 0
    for index = #registry, 1, -1 do
        if not entry_alive(registry[index]) then
            table.remove(registry, index)
            pruned_count = pruned_count + 1
        end
    end
    return pruned_count
end

---@class security.ZombieReapOptions
---@field older_than_ms? integer Only kill jobs at least this old (default 0: all tracked live jobs).

---@class security.ZombieReapReport
---@field killed integer[] Pids that were alive and are now dead.
---@field reaped integer[] Pids already dead; registry entries dropped.
---@field errors { pid: integer, err: string }[] Pids that would not die.

---Kill tracked jobs that are still alive (oldest decision: entries at least
---older_than_ms old, default 0 = every live tracked job), then drop every
---entry from the registry. SIGTERM first; SIGKILL for the stubborn; anything
---still alive afterwards is reported, not hidden.
---@param opts? security.ZombieReapOptions
---@return security.ZombieReapReport report
function M.reap(opts)
    opts = opts or {}
    local older_than_ms = opts.older_than_ms or 0
    local now_ms = uv.now()
    ---@type security.ZombieReapReport
    local report = { killed = {}, reaped = {}, errors = {} }
    for index = #registry, 1, -1 do
        local entry = registry[index]
        if not entry_alive(entry) then
            report.reaped[#report.reaped + 1] = entry.pid
            table.remove(registry, index)
        elseif now_ms - entry.started_ms >= older_than_ms then
            entry.obj:kill('sigterm')
            local died = wait_for_death(entry)
            if not died then
                entry.obj:kill('sigkill')
                died = wait_for_death(entry)
            end
            table.remove(registry, index)
            if died then
                report.killed[#report.killed + 1] = entry.pid
            else
                report.errors[#report.errors + 1] = { pid = entry.pid, err = 'process survived SIGKILL' }
            end
        end
    end
    return report
end

return M
