-- /qompassai/Diver/lua/ai/a2a/orchestrator.lua
-- Qompass AI A2A Cross-Language Orchestrator (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Fan-out / fan-in across the official A2A SDK drivers: one task is
-- dispatched to one agent per language and a single callback
-- receives every result in language order. Registry lookup and
-- toolchain detection reuse sdks.get / sdks.detect_all; each
-- driver's declared spawn shape (kind, argv, args_via, build,
-- init_argv, managed, cwd) drives a private bounded runner.
--
-- sdks.op is deliberately NOT the dispatch path: it is interactive
-- (it prompts for the base URL and reports through vim.notify) and
-- has no result callback, so a programmatic fan-out cannot observe
-- its results. The runner below mirrors sdks.lua's spawn sequence
-- (temp script or cached project, one-time init, argv/env/file arg
-- passing, pcall-guarded vim.system) and adds per-agent timeouts,
-- generation tokens, and a result callback.
--
-- Every byte of user input (task text, shared context, base URL)
-- reaches a driver as process argv or a small args file, never
-- interpolated into shell text. The dispatched op is always
-- 'send': the JSON payload { task, context } becomes the message.
-- Tool-call confirmation goes through ai.security's
-- confirm_tool_call(server, tool, args, callback) when that module
-- is present (async, default-deny without a UI); when it is
-- absent, dispatch proceeds with a one-time info log
-- (orchestration is read-side fan-out of send ops).
--
-- Wiring: require('ai.a2a.orchestrator').setup() is idempotent and
-- loads ai.a2a.commands, which registers :A2aOrchestrate at
-- require time (the existing commands.lua convention).

local uv = vim.uv

local sdks = require('ai.a2a.sdks')

local M = {}

local ORCHESTRATE_LANGS_MAX = 5
local TASK_BYTES_MAX = 16384
local CONTEXT_BYTES_MAX = 32768
local AGENT_TIMEOUT_MS_DEFAULT = 120000
local AGENT_TIMEOUT_MS_MAX = 300000
local OVERALL_HEADROOM_MS = 30000
local TOTAL_TIMEOUT_MS_MAX = 600000
local OUTPUT_BYTES_MAX = 1048576
local SCRIPT_BYTES_MAX = 65536

---@class A2aOrchestrateOpts
---@field task string Prompt text sent to every agent.
---@field langs string[] Registry langs, e.g. { 'python', 'go' }.
---@field base_url string Agent base URL; every driver resolves the card from it.
---@field context? table Shared context, JSON-encoded into each agent's input.
---@field timeout_ms? integer Per-agent deadline; default 120000, max 300000.
---@field total_timeout_ms? integer Overall deadline; default timeout_ms + 30000, max 600000.
---@field on_partial? fun(result: A2aOrchestratedResult) Called as each agent settles.

---@class A2aOrchestratedResult
---@field lang string
---@field ok boolean
---@field result? string Driver stdout on success (trimmed).
---@field error? string Failure reason on failure.
---@field elapsed_ms integer

---@class A2aOrchestrateNorm Validated, normalized orchestrate() options.
---@field task string
---@field langs string[]
---@field base_url string
---@field payload string JSON { task, context }, shared by every agent.
---@field timeout_ms integer
---@field total_timeout_ms integer
---@field on_partial? fun(result: A2aOrchestratedResult)

---@class A2aRunState
---@field gen integer Generation token of the owning run.
---@field finished boolean
---@field handles table<integer, any> vim.system handles, for deadline kill.
---@field started_ms table<integer, integer> Per-agent dispatch time.

---@class A2aRunCtx
---@field run A2aRunState
---@field gen integer Generation token; async continuations bail when stale.
---@field norm A2aOrchestrateNorm
---@field n integer
---@field results table<integer, A2aOrchestratedResult>
---@field settled integer
---@field timer userdata
---@field callback fun(results: A2aOrchestratedResult[])

---@class A2aSpawnPlan
---@field argv string[]
---@field cwd? string
---@field temp_path? string
---@field project_dir? string

local setup_done = false
local security_logged = false
local run_seq = 0

-- Validation ---------------------------------------------------------

---@param opts A2aOrchestrateOpts
---@return A2aOrchestrateNorm?, string?
local function validate_opts(opts)
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end
    if type(opts.task) ~= 'string' or opts.task == '' then
        return nil, 'task must be a nonempty string'
    end
    if #opts.task > TASK_BYTES_MAX then
        return nil, 'task too long (max ' .. TASK_BYTES_MAX .. ' bytes)'
    end
    if type(opts.langs) ~= 'table' or #opts.langs == 0 then
        return nil, 'langs must be a nonempty list'
    end
    if #opts.langs > ORCHESTRATE_LANGS_MAX then
        return nil, 'too many langs (max ' .. ORCHESTRATE_LANGS_MAX .. ')'
    end
    local seen = {}
    for _, lang in ipairs(opts.langs) do
        if type(lang) ~= 'string' then
            return nil, 'each lang must be a string'
        end
        if seen[lang] then
            return nil, 'duplicate lang: ' .. lang
        end
        if sdks.get(lang) == nil then
            return nil, 'unknown language: ' .. lang
        end
        seen[lang] = true
    end
    if type(opts.base_url) ~= 'string' or opts.base_url == '' then
        return nil, 'base_url must be a nonempty string'
    end
    if opts.base_url:find('[\r\n]') then
        return nil, 'base_url must be a single line'
    end
    local context = opts.context or {}
    if type(context) ~= 'table' then
        return nil, 'context must be a table'
    end
    if #vim.json.encode(context) > CONTEXT_BYTES_MAX then
        return nil, 'context too large (max ' .. CONTEXT_BYTES_MAX .. ' bytes)'
    end
    local timeout_ms = opts.timeout_ms or AGENT_TIMEOUT_MS_DEFAULT
    if type(timeout_ms) ~= 'number' or timeout_ms <= 0 then
        return nil, 'timeout_ms must be a positive number'
    end
    timeout_ms = math.floor(timeout_ms)
    if timeout_ms > AGENT_TIMEOUT_MS_MAX then
        return nil, 'timeout_ms exceeds max ' .. AGENT_TIMEOUT_MS_MAX
    end
    local total_ms = opts.total_timeout_ms or (timeout_ms + OVERALL_HEADROOM_MS)
    if type(total_ms) ~= 'number' or total_ms <= 0 then
        return nil, 'total_timeout_ms must be a positive number'
    end
    total_ms = math.floor(total_ms)
    if total_ms > TOTAL_TIMEOUT_MS_MAX then
        return nil, 'total_timeout_ms exceeds max ' .. TOTAL_TIMEOUT_MS_MAX
    end
    if opts.on_partial ~= nil and type(opts.on_partial) ~= 'function' then
        return nil, 'on_partial must be a function'
    end
    return {
        task = opts.task,
        langs = opts.langs,
        base_url = opts.base_url,
        payload = vim.json.encode({ task = opts.task, context = context }),
        timeout_ms = timeout_ms,
        total_timeout_ms = total_ms,
        on_partial = opts.on_partial,
    },
        nil
end

-- Security gate --------------------------------------------------------
-- ai.security is optional. When present with its confirm_tool_call
-- policy, dispatch waits for the user's decision: confirm_tool_call
-- is asynchronous (server, tool, args, callback) and default-denies
-- when no UI is attached (e.g. --headless). A denial notifies and
-- the result callback is never invoked. When the module is absent,
-- dispatch proceeds with a one-time info log (orchestration only
-- fans out read-side send ops; it never writes, installs, or
-- mutates). A policy error fails closed: notify, no dispatch.

---@param norm A2aOrchestrateNorm
---@param callback fun(results: A2aOrchestratedResult[])
---@param start fun(norm: A2aOrchestrateNorm, callback: fun(results: A2aOrchestratedResult[]))
local function request_dispatch(norm, callback, start)
    local ok, sec = pcall(require, 'ai.security')
    if not ok or sec == nil or type(sec.confirm_tool_call) ~= 'function' then
        if not security_logged then
            security_logged = true
            vim.notify(
                'A2A orchestrate: no ai.security policy module; proceeding (read-side dispatch)',
                vim.log.levels.INFO
            )
        end
        start(norm, callback)
        return
    end
    local args = { task = norm.task, langs = norm.langs, timeout_ms = norm.timeout_ms }
    local function on_decision(allowed, reason)
        if allowed then
            start(norm, callback)
        else
            vim.notify('A2A orchestrate denied: ' .. tostring(reason), vim.log.levels.WARN)
        end
    end
    local pok, perr = pcall(sec.confirm_tool_call, 'a2a', 'orchestrate', args, on_decision)
    if not pok then
        local msg = 'A2A orchestrate: security policy error: ' .. tostring(perr)
        vim.notify(msg, vim.log.levels.ERROR)
    end
end

-- Driver spawn ---------------------------------------------------------
-- Mirrors sdks.lua's spawn sequence (temp script or cached project
-- dir, one-time init_argv, argv/env/file arg passing, pcall around
-- vim.system) with a result callback and per-agent timeout added.

---@param dir string
---@param files table<string, string> relative path -> content
---@return boolean ok
local function write_files(dir, files)
    if vim.fn.mkdir(dir, 'p') == 0 then
        return false
    end
    for rel, content in pairs(files) do
        local path = dir .. '/' .. rel
        if vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p') == 0 then
            return false
        end
        local fh = io.open(path, 'w')
        if fh == nil then
            return false
        end
        fh:write(content)
        fh:close()
    end
    return true
end

---@param plan A2aSpawnPlan
local function cleanup_plan(plan)
    if plan.temp_path ~= nil then
        vim.fn.delete(plan.temp_path)
    end
end

---@param spec A2aSdkSpec
---@param driver A2aSdkDriver
---@return A2aSpawnPlan?, string?
local function build_plan(spec, driver)
    ---@type A2aSpawnPlan
    local plan = { argv = {} }
    if driver.kind == 'script' then
        local source = driver.build()
        if type(source) ~= 'string' or #source > SCRIPT_BYTES_MAX then
            return nil, 'driver source out of bounds'
        end
        plan.temp_path = vim.fn.tempname() .. driver.ext
        local dir = vim.fn.fnamemodify(plan.temp_path, ':h')
        local base = vim.fn.fnamemodify(plan.temp_path, ':t')
        if not write_files(dir, { [base] = source }) then
            return nil, 'cannot write temp script'
        end
        for _, a in ipairs(driver.argv) do
            plan.argv[#plan.argv + 1] = a
        end
        plan.argv[#plan.argv + 1] = plan.temp_path
        if driver.cwd == 'nvim' then
            plan.cwd = vim.fn.getcwd()
        end
        return plan, nil
    end
    local files = driver.build()
    if type(files) ~= 'table' then
        return nil, 'project driver build must return path -> content'
    end
    plan.project_dir = vim.fn.stdpath('cache') .. '/a2a-sdk-drivers/' .. spec.lang
    if driver.managed ~= nil then
        for _, rel in ipairs(driver.managed) do
            if vim.fn.filereadable(plan.project_dir .. '/' .. rel) == 1 then
                files[rel] = nil
            end
        end
    end
    if not write_files(plan.project_dir, files) then
        return nil, 'cannot write driver project'
    end
    plan.cwd = plan.project_dir
    for _, a in ipairs(driver.argv) do
        plan.argv[#plan.argv + 1] = a
    end
    return plan, nil
end

---@param driver A2aSdkDriver
---@param project_dir string
---@param timeout_ms integer
---@param run A2aRunState
---@param gen integer
---@param cb fun(ready: boolean, err: string?)
local function ensure_ready(driver, project_dir, timeout_ms, run, gen, cb)
    local init_argv = driver.init_argv
    if init_argv == nil then
        cb(true, nil)
        return
    end
    local marker = project_dir .. '/.diver-ready'
    if vim.fn.filereadable(marker) == 1 then
        cb(true, nil)
        return
    end
    local init_ok, init_handle = pcall(
        vim.system,
        init_argv,
        { text = true, timeout = timeout_ms, cwd = project_dir },
        function(res)
            vim.schedule(function()
                if gen ~= run.gen or run.finished then
                    return
                end
                if res == nil or res.code ~= 0 then
                    local out = res and ((res.stdout or '') .. (res.stderr or '')) or ''
                    cb(false, 'driver project setup failed: ' .. out:sub(1, 200))
                    return
                end
                local fh = io.open(marker, 'w')
                if fh ~= nil then
                    fh:close()
                end
                cb(true, nil)
            end)
        end
    )
    if not init_ok or init_handle == nil then
        vim.schedule(function()
            cb(false, 'setup failed to start; is the toolchain installed?')
        end)
    end
end

---@param plan A2aSpawnPlan
---@param driver A2aSdkDriver
---@param norm A2aOrchestrateNorm
---@param run A2aRunState
---@param gen integer
---@param index integer
---@param on_done fun(ok: boolean, output: string?, err: string?)
local function launch(plan, driver, norm, run, gen, index, on_done)
    if gen ~= run.gen or run.finished then
        cleanup_plan(plan)
        return
    end
    local argv = {}
    for _, a in ipairs(plan.argv) do
        argv[#argv + 1] = a
    end
    ---@type table<string, string>?
    local spawn_env = nil
    if driver.args_via == 'argv' then
        argv[#argv + 1] = 'send'
        argv[#argv + 1] = norm.base_url
        argv[#argv + 1] = norm.payload
    elseif driver.args_via == 'file' then
        -- The Java driver reads args.txt line by line, so the
        -- payload is flattened to one line on this channel.
        if plan.cwd == nil then
            cleanup_plan(plan)
            on_done(false, nil, 'file arg passing needs a project dir')
            return
        end
        local fh = io.open(plan.cwd .. '/args.txt', 'w')
        if fh == nil then
            cleanup_plan(plan)
            on_done(false, nil, 'cannot write driver args')
            return
        end
        fh:write('send\n' .. norm.base_url .. '\n' .. norm.payload:gsub('\r?\n', ' ') .. '\n')
        fh:close()
    elseif driver.args_via == 'env' then
        spawn_env = { A2A_OP = 'send', A2A_BASE = norm.base_url, A2A_EXTRA = norm.payload }
    else
        cleanup_plan(plan)
        on_done(false, nil, 'unknown args_via: ' .. tostring(driver.args_via))
        return
    end
    local sys_opts = { text = true, timeout = norm.timeout_ms }
    if plan.cwd ~= nil then
        sys_opts.cwd = plan.cwd
    end
    if spawn_env ~= nil then
        sys_opts.env = spawn_env
    end
    local ok, handle = pcall(vim.system, argv, sys_opts, function(res)
        cleanup_plan(plan)
        local output = ''
        local succeeded = res ~= nil and res.code == 0
        if res ~= nil then
            output = (res.stdout or '') .. (res.stderr or '')
        end
        if #output > OUTPUT_BYTES_MAX then
            output = output:sub(1, OUTPUT_BYTES_MAX) .. '\n…[truncated]'
        end
        local err = nil
        if not succeeded then
            err = 'driver failed (exit ' .. tostring(res and res.code or '?') .. ')'
            if output ~= '' then
                err = err .. ': ' .. output:sub(1, 200)
            end
        end
        vim.schedule(function()
            if gen ~= run.gen or run.finished then
                return -- stale: the run already settled without us
            end
            on_done(succeeded, output, err)
        end)
    end)
    if not ok or handle == nil then
        cleanup_plan(plan)
        vim.schedule(function()
            on_done(false, nil, 'failed to start; is the toolchain installed?')
        end)
        return
    end
    run.handles[index] = handle
end

---@param run A2aRunState
---@param gen integer
---@param norm A2aOrchestrateNorm
---@param index integer
---@param lang string
---@param on_done fun(ok: boolean, output: string?, err: string?)
local function dispatch_agent(run, gen, norm, index, lang, on_done)
    local spec = sdks.get(lang)
    assert(spec ~= nil, 'lang validated before dispatch')
    local driver = spec.driver
    if driver == nil or not spec.verified then
        on_done(false, nil, 'unavailable: ' .. lang .. ' (driver not verified)')
        return
    end
    local plan, perr = build_plan(spec, driver)
    if plan == nil then
        on_done(false, nil, perr)
        return
    end
    local function go()
        launch(plan, driver, norm, run, gen, index, on_done)
    end
    if plan.project_dir ~= nil then
        ensure_ready(driver, plan.project_dir, norm.timeout_ms, run, gen, function(ready, rerr)
            if not ready then
                cleanup_plan(plan)
                on_done(false, nil, rerr)
                return
            end
            go()
        end)
        return
    end
    go()
end

-- Fan-in ---------------------------------------------------------------

---@param ctx A2aRunCtx
local function finish_run(ctx)
    if ctx.gen ~= ctx.run.gen or ctx.run.finished then
        return
    end
    ctx.run.finished = true
    ctx.timer:stop()
    ctx.timer:close()
    local ordered = {}
    for i = 1, ctx.n do
        ordered[i] = ctx.results[i]
    end
    vim.schedule(function()
        ctx.callback(ordered)
    end)
end

---@param ctx A2aRunCtx
---@param index integer
---@param lang string
---@param ok boolean
---@param output? string
---@param err? string
---@param elapsed_ms integer
local function settle_agent(ctx, index, lang, ok, output, err, elapsed_ms)
    if ctx.gen ~= ctx.run.gen or ctx.run.finished then
        return -- stale or already finished: late result rejected
    end
    if ctx.results[index] ~= nil then
        return -- duplicate settle: rejected
    end
    local result = { lang = lang, ok = ok, result = output, error = err, elapsed_ms = elapsed_ms }
    ctx.results[index] = result
    ctx.settled = ctx.settled + 1
    if ctx.norm.on_partial ~= nil then
        ctx.norm.on_partial(result)
    end
    if ctx.settled >= ctx.n then
        finish_run(ctx)
    end
end

---@param ctx A2aRunCtx
local function on_deadline(ctx)
    if ctx.gen ~= ctx.run.gen or ctx.run.finished then
        return
    end
    for i, lang in ipairs(ctx.norm.langs) do
        if ctx.results[i] == nil then
            local handle = ctx.run.handles[i]
            if handle ~= nil then
                pcall(function()
                    handle:kill()
                end)
            end
            local started = ctx.run.started_ms[i] or uv.now()
            settle_agent(ctx, i, lang, false, nil, 'overall deadline exceeded', uv.now() - started)
        end
    end
    finish_run(ctx)
end

---@param ctx A2aRunCtx
---@param detected table<string, { installed: boolean, detail: string }>
local function begin_dispatch(ctx, detected)
    if ctx.gen ~= ctx.run.gen or ctx.run.finished then
        return
    end
    for i, lang in ipairs(ctx.norm.langs) do
        local d = detected[lang]
        if d == nil or not d.installed then
            -- Graceful degradation: a missing toolchain settles this
            -- agent immediately; the rest still run.
            local why = 'unavailable: ' .. lang
            if d ~= nil and d.detail ~= '' then
                why = why .. ' (' .. d.detail .. ')'
            end
            settle_agent(ctx, i, lang, false, nil, why, 0)
        else
            local started = uv.now()
            ctx.run.started_ms[i] = started
            dispatch_agent(ctx.run, ctx.gen, ctx.norm, i, lang, function(ok, output, err)
                settle_agent(ctx, i, lang, ok, output, err, uv.now() - started)
            end)
        end
    end
end

-- Public API -------------------------------------------------------------

---@param norm A2aOrchestrateNorm
---@param callback fun(results: A2aOrchestratedResult[]) Called once, langs order.
local function start_run(norm, callback)
    run_seq = run_seq + 1
    local gen = run_seq
    ---@type A2aRunCtx
    local ctx = {
        run = { gen = gen, finished = false, handles = {}, started_ms = {} },
        gen = gen,
        norm = norm,
        n = #norm.langs,
        results = {},
        settled = 0,
        timer = uv.new_timer(),
        callback = callback,
    }
    ctx.timer:start(norm.total_timeout_ms, 0, function()
        vim.schedule(function()
            on_deadline(ctx)
        end)
    end)
    -- Detection reuses sdks.detect_all's graceful pattern: a probe
    -- that fails to spawn reports installed = false, never a crash.
    sdks.detect_all(function(detected)
        begin_dispatch(ctx, detected)
    end)
end

---@param opts A2aOrchestrateOpts
---@param callback fun(results: A2aOrchestratedResult[]) Called once, langs order.
---  When the ai.security policy denies dispatch, the callback is
---  not invoked and a warning is shown.
---@return boolean ok, string? err False plus reason only when opts
---  are invalid; the callback is not invoked then.
function M.orchestrate(opts, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local norm, verr = validate_opts(opts)
    if norm == nil then
        return false, verr
    end
    request_dispatch(norm, callback, start_run)
    return true, nil
end

function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    -- Registers :A2aOrchestrate (and the other A2A commands) at
    -- require time, per the commands.lua convention.
    require('ai.a2a.commands')
end

return M
