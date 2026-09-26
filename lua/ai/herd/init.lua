-- /qompassai/Diver/lua/ai/herd/init.lua
-- Qompass AI Herd Agent Runtime (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Top-level wiring for herd: a Herdr-like persistent agent runtime. Each
-- agent is a tmux session running an agent CLI; a watch timer tracks agent
-- status and a local socket API exposes spawn/prompt/status/wait_blocked/
-- kill/list to remote drivers.
--
-- M.setup() spawns NO tmux sessions and starts NO agents. It only wires
-- the socket backend closures, starts the local socket listener
-- (best-effort) and the watch timer (best-effort), and registers the
-- :Herd* user commands. Agents are created explicitly via M.spawn_agent /
-- :HerdSpawn, or revived from the persisted layout via M.restore_layout /
-- :HerdRestore.
--
-- Layout (session names, CLIs, tasks) persists as JSON at
-- stdpath('data')/herd/layout.json with atomic tmp+rename writes.

local M = {}

local catalog = require('ai.herd.catalog')

local NAME_PATTERN = '^[A-Za-z0-9._-]+$'
local NAME_LENGTH_MAX = 64
local AGENT_COUNT_MAX = 32
local TEXT_SIZE_BYTES_MAX = 256 * 1024
local READY_TIMEOUT_MS = 15000
local READY_POLL_MS = 500
local READY_CAPTURE_LINES = 20
local LAYOUT_FILENAME = 'layout.json'
local LAYOUT_FILE_SIZE_BYTES_MAX = 256 * 1024
local LAYOUT_ENTRY_COUNT_MAX = 64
local WATCH_INTERVAL_MS_DEFAULT = 5000
local WAIT_BLOCKED_TIMEOUT_MS_DEFAULT = 60000
local WAIT_BLOCKED_TIMEOUT_MS_MIN = 1000
local WAIT_BLOCKED_TIMEOUT_MS_MAX = 300000
local WAIT_BLOCKED_POLL_MS = 200

---@class HerdAgentRecord
---@field name string Agent and tmux session name.
---@field cli string Catalog CLI name (e.g. 'claude').
---@field target string tmux session target (same as name for local).
---@field task string First task text, '' when none.
---@field cwd string? Working directory the session started in.
---@field machine string Always 'local' for agents spawned here.
---@field created_at integer os.time() when the agent was spawned.

---@class HerdAgentInfo
---@field name string
---@field cli string
---@field machine string
---@field status string Watch status, or 'unknown' when untracked.
---@field task string

---@class HerdSetupOpts
---@field socket boolean? Start the local socket listener. Default true.
---@field watch_interval_ms integer? Watch poll interval. Default 5000.

local agents = {} ---@type table<string, HerdAgentRecord>
local setup_done = false
local spawn_counter = 0 ---@type integer

---@param value number
---@param lower number
---@param upper number
---@return number
local function clamp(value, lower, upper)
    if value < lower then
        return lower
    end
    if value > upper then
        return upper
    end
    return value
end

---Kill a tmux session, tolerating an already-dead one.
---@param name string tmux session name
local function kill_session_quiet(name)
    local tmux = require('ai.herd.tmux')
    pcall(tmux.kill_session, name)
end

---Wait until the session pane shows non-blank output (CLI is up).
---@param name string tmux session name
---@return boolean ready
local function wait_for_output(name)
    local tmux = require('ai.herd.tmux')
    local ready = vim.wait(READY_TIMEOUT_MS, function()
        local ok, out = pcall(tmux.capture_pane, name, READY_CAPTURE_LINES)
        return ok and out ~= nil and out:gsub('%s', '') ~= ''
    end, READY_POLL_MS)
    return ready == true
end

---Validate one decoded layout entry.
---@param raw any
---@return boolean ok
---@return string? name
---@return string? cli_name
---@return string? task
---@return string? cwd
local function parse_layout_entry(raw)
    if type(raw) ~= 'table' then
        return false
    end
    local name = raw.name
    local cli_name = raw.cli
    if type(name) ~= 'string' or name:match(NAME_PATTERN) == nil then
        return false
    end
    if type(cli_name) ~= 'string' or cli_name == '' then
        return false
    end
    local task = type(raw.task) == 'string' and raw.task or nil
    local cwd = type(raw.cwd) == 'string' and raw.cwd or nil
    return true, name, cli_name, task, cwd
end

---Register a still-live tmux session as a herd agent without spawning.
---@param name string
---@param cli_name string
---@param task string?
---@param cwd string?
local function retrack_agent(name, cli_name, task, cwd)
    local watch = require('ai.herd.watch')
    watch.track(name, name, cli_name, task)
    agents[name] = {
        name = name,
        cli = cli_name,
        target = name,
        task = task or '',
        cwd = cwd,
        machine = 'local',
        created_at = os.time(),
    }
end

---Revive one layout entry: re-track it when its tmux session is still
---alive, otherwise spawn it again.
---@param raw any decoded layout entry
---@param index integer entry position, for error messages
---@param live table<string, boolean> live tmux session names
---@return boolean revived
---@return string? err
local function revive_entry(raw, index, live)
    local entry_ok, name, cli_name, task, cwd = parse_layout_entry(raw)
    if not entry_ok then
        return false, 'entry #' .. index .. ' invalid; skipped'
    end
    if agents[name] ~= nil then
        return false, nil
    end
    if live[name] then
        retrack_agent(name, cli_name, task, cwd)
        return true, nil
    end
    local spawned, spawn_err = M.spawn_agent(name, cli_name, task, cwd)
    if spawned then
        return true, nil
    end
    return false, name .. ': ' .. tostring(spawn_err)
end

---Data directory shared by the herd modules.
---@return string
function M.data_dir()
    return vim.fn.stdpath('data') .. '/herd'
end

---@return string? path absolute path of the layout file
---@return string? err
local function layout_path()
    local dir = M.data_dir()
    -- mkdir's mode argument only applies at creation time (and only as
    -- a string); always inspect and enforce owner-only permissions so
    -- a pre-existing loose directory cannot keep them. 448 is 0o700.
    local mkdir_ok, made = pcall(vim.fn.mkdir, dir, 'p', '0700')
    if not mkdir_ok then
        return nil, 'cannot create herd data dir: ' .. tostring(made)
    end
    local stat = vim.uv.fs_stat(dir)
    if stat == nil or stat.type ~= 'directory' then
        return nil, 'not a directory: ' .. dir
    end
    local perms = (stat.mode or 511) % 512
    if perms % 64 ~= 0 then
        -- pcall only guards Lua errors: fs_chmod returns nil+err on
        -- failure without throwing, so both results must be checked.
        local pcall_ok, chmod_ok, chmod_err = pcall(vim.uv.fs_chmod, dir, 448)
        if not pcall_ok or not chmod_ok then
            return nil, 'cannot tighten permissions on ' .. dir .. ': ' .. tostring(chmod_err)
        end
    end
    return dir .. '/' .. LAYOUT_FILENAME, nil
end

---Atomically persist the local agent layout, sorted by name.
---@return boolean ok
---@return string? err
local function persist_layout()
    local names = {}
    for name, agent in pairs(agents) do
        if agent.machine == 'local' then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local entries = {}
    for _, name in ipairs(names) do
        local agent = agents[name]
        entries[#entries + 1] = {
            name = agent.name,
            cli = agent.cli,
            task = agent.task,
            cwd = agent.cwd,
        }
    end
    local ok, text = pcall(vim.json.encode, entries)
    if not ok or type(text) ~= 'string' then
        return nil, 'cannot encode layout'
    end
    local path, path_err = layout_path()
    if path == nil then
        return nil, path_err
    end
    local tmp = path .. '.tmp'
    local file, file_err = io.open(tmp, 'w')
    if file == nil then
        return nil, 'cannot write layout: ' .. tostring(file_err)
    end
    file:write(text)
    file:close()
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then
        return nil, 'cannot replace layout: ' .. tostring(rename_err)
    end
    return true
end

---Spawn a persistent agent: a tmux session running the catalog CLI, with
---an optional first task pasted once the CLI shows output. The session is
---killed on any failure after it is created, so a failed spawn never leaks
---a tmux session.
---@param name string agent/session name; must match NAME_PATTERN
---@param cli_name string catalog entry name (e.g. 'claude')
---@param task string? first prompt; sent only when non-blank
---@param cwd string? working directory for the session
---@return boolean ok
---@return string? err
function M.spawn_agent(name, cli_name, task, cwd)
    if type(name) ~= 'string' or #name < 1 or #name > NAME_LENGTH_MAX then
        return nil, 'invalid agent name'
    end
    if name:match(NAME_PATTERN) == nil then
        return nil, 'invalid agent name'
    end
    if agents[name] ~= nil then
        return nil, 'agent exists'
    end
    if vim.tbl_count(agents) >= AGENT_COUNT_MAX then
        return nil, 'agent limit reached'
    end
    if type(cli_name) ~= 'string' then
        return nil, 'unknown cli'
    end
    local entry = catalog.get(cli_name)
    if entry == nil then
        return nil, 'unknown cli'
    end
    if task ~= nil and type(task) ~= 'string' then
        return nil, 'task must be a string'
    end
    if cwd ~= nil and (type(cwd) ~= 'string' or cwd == '') then
        return nil, 'cwd must be a non-empty string'
    end
    local tmux = require('ai.herd.tmux')
    if not tmux.available() then
        return nil, 'tmux not available'
    end
    local started, start_err = tmux.new_session(name, entry.launch_argv(), cwd)
    if not started then
        return nil, start_err
    end
    if not wait_for_output(name) then
        kill_session_quiet(name)
        return nil, 'agent did not produce output'
    end
    if task ~= nil and task:match('%S') ~= nil then
        local sent, send_err = tmux.send_keys_pane(name, task)
        if not sent then
            kill_session_quiet(name)
            return nil, send_err
        end
    end
    local watch = require('ai.herd.watch')
    watch.track(name, name, cli_name, task)
    agents[name] = {
        name = name,
        cli = cli_name,
        target = name,
        task = task or '',
        cwd = cwd,
        machine = 'local',
        created_at = os.time(),
    }
    local saved, save_err = persist_layout()
    if not saved then
        agents[name] = nil
        watch.untrack(name)
        kill_session_quiet(name)
        return nil, save_err
    end
    return true
end

---Send text to a local agent's tmux pane (pasted verbatim + Enter).
---@param name string
---@param text string non-empty, at most 256KB
---@return boolean ok
---@return string? err
function M.prompt_agent(name, text)
    local agent = type(name) == 'string' and agents[name] or nil
    if agent == nil or agent.machine ~= 'local' then
        return nil, 'unknown agent'
    end
    if type(text) ~= 'string' or text == '' then
        return nil, 'text must be a non-empty string'
    end
    if #text > TEXT_SIZE_BYTES_MAX then
        return nil, 'text exceeds size limit'
    end
    local tmux = require('ai.herd.tmux')
    return tmux.send_keys_pane(agent.target, text)
end

---Stop a local agent: untrack, kill its tmux session (already-dead is
---fine), drop it from the registry and persist the layout.
---@param name string
---@return boolean ok
---@return string? err
function M.kill_agent(name)
    if type(name) ~= 'string' or agents[name] == nil then
        return nil, 'unknown agent'
    end
    local watch = require('ai.herd.watch')
    watch.untrack(name)
    kill_session_quiet(name)
    agents[name] = nil
    local saved, save_err = persist_layout()
    if not saved then
        return nil, save_err
    end
    return true
end

---Snapshot of tracked agents, sorted by name, with live watch status.
---@return HerdAgentInfo[]
function M.agents()
    local watch = require('ai.herd.watch')
    local states = watch.state()
    local names = {}
    for name in pairs(agents) do
        names[#names + 1] = name
    end
    table.sort(names)
    local list = {}
    for _, name in ipairs(names) do
        local agent = agents[name]
        local state = states[name]
        list[#list + 1] = {
            name = agent.name,
            cli = agent.cli,
            machine = agent.machine,
            status = (state ~= nil and state.status) or 'unknown',
            task = agent.task,
        }
    end
    return list
end

---Revive the persisted layout: sessions still alive in tmux are re-tracked
---without spawning; missing ones are spawned again. Per-entry failures are
---collected and the loop continues.
---@return integer restored
---@return string[] errors
function M.restore_layout()
    local path, path_err = layout_path()
    if path == nil then
        return 0, { path_err or 'cannot resolve layout path' }
    end
    local file = io.open(path, 'r')
    if file == nil then
        return 0, {}
    end
    local text = file:read(LAYOUT_FILE_SIZE_BYTES_MAX + 1)
    file:close()
    if type(text) ~= 'string' or text == '' then
        return 0, {}
    end
    if #text > LAYOUT_FILE_SIZE_BYTES_MAX then
        return 0, { 'layout file exceeds size bound' }
    end
    local ok, decoded = pcall(vim.json.decode, text)
    if not ok or not vim.islist(decoded) then
        return 0, { 'layout file is not a JSON array' }
    end
    local tmux = require('ai.herd.tmux')
    local sessions, sessions_err = tmux.list_sessions()
    if sessions == nil then
        return 0, { 'cannot list tmux sessions: ' .. tostring(sessions_err) }
    end
    assert(type(sessions) == 'table', 'list_sessions must return a table')
    local live = {}
    for _, session in ipairs(sessions) do
        if type(session) == 'string' then
            live[session] = true
        end
    end
    local restored = 0
    local errors = {}
    for index, raw in ipairs(decoded) do
        if index > LAYOUT_ENTRY_COUNT_MAX then
            errors[#errors + 1] = 'layout has too many entries; rest ignored'
            break
        end
        local revived, revive_err = revive_entry(raw, index, live)
        if revive_err ~= nil then
            errors[#errors + 1] = revive_err
        elseif revived then
            restored = restored + 1
        end
    end
    if restored > 0 then
        local saved, save_err = persist_layout()
        if not saved then
            local msg = 'layout persist failed: ' .. tostring(save_err)
            errors[#errors + 1] = msg
        end
    end
    return restored, errors
end

---@param params table socket request params
---@return boolean ok
---@return string? err
local function backend_spawn(params)
    if type(params) ~= 'table' then
        return nil, 'params must be a table'
    end
    if type(params.cli) ~= 'string' then
        return nil, 'params.cli must be a string'
    end
    spawn_counter = spawn_counter + 1
    local name = params.name or (params.cli .. '-' .. tostring(spawn_counter))
    return M.spawn_agent(name, params.cli, params.task, params.cwd)
end

---@param params table socket request params
---@return boolean ok
---@return string? err
local function backend_prompt(params)
    if type(params) ~= 'table' then
        return nil, 'params must be a table'
    end
    return M.prompt_agent(params.agent, params.text)
end

---@param params table socket request params
---@return boolean ok
---@return HerdAgentInfo|HerdAgentInfo[]|string result_or_err
local function backend_status(params)
    if type(params) ~= 'table' then
        return nil, 'params must be a table'
    end
    if params.agent == nil then
        return true, M.agents()
    end
    if type(params.agent) ~= 'string' then
        return nil, 'params.agent must be a string'
    end
    for _, agent in ipairs(M.agents()) do
        if agent.name == params.agent then
            return true, agent
        end
    end
    return nil, 'unknown agent'
end

---True when a watched agent reached a state the caller can stop waiting
---for: blocked on input, or dead.
---@param state table? watch state entry
---@return boolean
local function is_settled(state)
    if state == nil then
        return false
    end
    return state.status == 'blocked' or state.status == 'dead'
end

---@param params table socket request params
---@return boolean ok
---@return string? err
local function backend_wait_blocked(params)
    if type(params) ~= 'table' then
        return nil, 'params must be a table'
    end
    if type(params.agent) ~= 'string' then
        return nil, 'params.agent must be a string'
    end
    local timeout_ms = params.timeout_ms
    if type(timeout_ms) ~= 'number' then
        timeout_ms = WAIT_BLOCKED_TIMEOUT_MS_DEFAULT
    end
    local lower = WAIT_BLOCKED_TIMEOUT_MS_MIN
    local upper = WAIT_BLOCKED_TIMEOUT_MS_MAX
    timeout_ms = clamp(timeout_ms, lower, upper)
    local watch = require('ai.herd.watch')
    local done = vim.wait(timeout_ms, function()
        return is_settled(watch.state()[params.agent])
    end, WAIT_BLOCKED_POLL_MS)
    if done == true then
        return true
    end
    return nil, 'timeout waiting for agent to block'
end

---@param params table socket request params
---@return boolean ok
---@return string? err
local function backend_kill(params)
    if type(params) ~= 'table' then
        return nil, 'params must be a table'
    end
    return M.kill_agent(params.agent)
end

---@param _params any unused
---@return boolean ok
---@return HerdAgentInfo[] agents
local function backend_list(_params)
    return true, M.agents()
end

---Wire the herd runtime. Idempotent: repeat calls are a no-op returning
---true. Starts NO tmux sessions and NO agents; only the local socket
---listener (unless opts.socket == false) and the watch timer are started,
---then the :Herd* commands are registered. Socket and watch startup are
---best-effort: failures notify at WARN and setup continues.
---@param opts HerdSetupOpts?
---@return boolean ok
---@return string? err
function M.setup(opts)
    if setup_done then
        return true
    end
    if opts ~= nil and type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    local options = opts or {}
    if options.socket ~= nil and type(options.socket) ~= 'boolean' then
        return nil, 'opts.socket must be a boolean'
    end
    local interval_ms = options.watch_interval_ms
    if interval_ms == nil then
        interval_ms = WATCH_INTERVAL_MS_DEFAULT
    elseif type(interval_ms) ~= 'number' or interval_ms < 1 then
        return nil, 'opts.watch_interval_ms must be a positive number'
    end
    setup_done = true
    local api = require('ai.herd.api')
    api.set_backend({
        spawn = backend_spawn,
        prompt = backend_prompt,
        status = backend_status,
        wait_blocked = backend_wait_blocked,
        kill = backend_kill,
        list = backend_list,
    })
    if options.socket ~= false then
        local started, start_err = api.start()
        if not started then
            local msg = 'herd: socket listener failed: ' .. tostring(start_err)
            vim.notify(msg, vim.log.levels.WARN)
        end
    end
    local watch = require('ai.herd.watch')
    local watching, watch_err = watch.start(math.floor(interval_ms))
    if not watching then
        local msg = 'herd: watch timer failed: ' .. tostring(watch_err)
        vim.notify(msg, vim.log.levels.WARN)
    end
    require('ai.herd.commands').setup()
    return true
end

return M
