-- /qompassai/Diver/lua/dev/sf/trailhead.lua
-- Qompass AI Diver Salesforce Trailhead Async Agent Jobs
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Plain words: this module is the diver-side orchestration shell that lets
-- AI agents work Trailhead modules asynchronously. It is a bounded job
-- queue with resumable sessions: enqueue a job, attach steps, start it,
-- watch progress, read the log, cancel, and resume later. Job state is
-- persisted to disk, so sessions survive restarts.
--
-- What this module does NOT do: drive Trailhead in a browser. Trailhead
-- exposes no public completion API, so completing modules or units in the
-- browser is an explicit integration point for whoever owns the browser
-- automation (a browser task, an MCP tool, a rose.nvim bridge). That
-- automation reports finished units back through complete_step() and
-- fail_step(), or a step carries an `argv` list that runs locally -- for
-- example `sf` CLI commands backing a hands-on playground challenge.
--
-- ai/ integration points (see lua/ai/init.lua, lua/ai/sched.lua):
--   * on_event() subscribers (for example ai.a2a.orchestrator) receive
--     every job and step transition and can mirror Trailhead job state
--     into agent supervision UIs.
--   * Step argv always runs in argv form through vim.system, never
--     through a shell, matching the ai/ subprocess discipline.
--   * Anything that would drive a real browser on the user's behalf must
--     pass the ai.security tool-call confirmation policy first; this
--     module never performs browser actions itself.
--
-- Free certification vouchers: SfTrailheadQuests prints the researched
-- voucher sources with every claim labeled VERIFIED (confirmed against an
-- official Salesforce source) or SPECULATIVE (third-party or unconfirmed).
---@module 'dev.sf.trailhead'

local api = vim.api
local fn = vim.fn

local core = require('dev.sf.core')

local M = {}

local JOB_COUNT_MAX = 128
local ACTIVE_JOB_COUNT_MAX = 4
local STEPS_PER_JOB_MAX = 256
local LOG_LINE_COUNT_MAX = 500
local LOG_LINE_BYTES_MAX = 1024
local PERSIST_LOG_LINES_MAX = 50
local STEP_LOG_LINES_MAX = 100
local TITLE_BYTES_MAX = 200
local STEP_NAME_BYTES_MAX = 200
local NOTE_BYTES_MAX = 4096
local RESULT_BYTES_MAX = 4096
local STEP_ARGV_COUNT_MAX = 32
local STEP_ARGV_BYTES_MAX = 2048
local SUBSCRIBER_COUNT_MAX = 16
local JOB_ID_BYTES_MAX = 128
local STATE_READ_BYTES_MAX = 16777216
local STEP_TIMEOUT_MS = 15 * 60 * 1000

---@class TrailheadStep
---@field name string
---@field argv? string[]
---@field note? string
---@field status 'pending'|'running'|'done'|'failed'|'skipped'
---@field detail? string

---@class TrailheadJob
---@field id string
---@field kind string
---@field title string
---@field status 'queued'|'running'|'paused'|'done'|'failed'|'cancelled'
---@field steps TrailheadStep[]
---@field created_at integer
---@field updated_at integer
---@field log string[]
---@field result? string
---@field error? string
---@field generation integer
---@field handle? vim.SystemObj

---@class TrailheadEvent
---@field type 'job'|'step'
---@field job_id string
---@field status string
---@field step? string

---@class TrailheadEnqueueOpts
---@field kind string one of trailmix|quest|study|shell|note
---@field title string

---@class TrailheadStepOpts
---@field name string
---@field argv? string[] shell step: local command in argv form
---@field note? string note step: recorded text, completes immediately

---@class TrailheadVoucherSource
---@field name string
---@field summary string
---@field eligibility string
---@field verified boolean true = confirmed against an official Salesforce source
---@field source string

local JOB_KINDS = {
    trailmix = true,
    quest = true,
    study = true,
    shell = true,
    note = true,
}

---@type TrailheadVoucherSource[]
local VOUCHER_SOURCES = {
    {
        name = 'Trailhead Quests',
        summary = 'Monthly themed challenges at trailhead.salesforce.com/quests: complete the listed'
            .. ' modules before the deadline for a chance at prizes that include certification vouchers.',
        eligibility = 'Anyone with a free Trailhead account. The voucher is a prize, not guaranteed.',
        verified = true,
        source = 'https://www.salesforce.com/blog/what-is-trailhead/?bc=HL',
    },
    {
        name = 'Trailhead Coach',
        summary = 'Guided pathway with free exam vouchers for 18 or more Salesforce certifications.',
        eligibility = 'Only participants of the Workforce Partner Program or Talent Alliance Career'
            .. ' Cohorts (underrepresented job seekers). Not open enrollment.',
        verified = true,
        source = 'https://www.salesforce.com/news/stories/trailhead-coach-news/?ref=hutte.io&bc=OTH',
    },
    {
        name = 'Trailhead Military',
        summary = 'Full exam fee waiver voucher after completing the chosen career-path modules'
            .. ' and required training.',
        eligibility = 'Active duty, reserve, guard, veterans, and military spouses.',
        verified = true,
        source = 'https://trailhead.salesforce.com/content/learn/modules/vetforce/know-vetforce',
    },
    {
        name = 'AI Associate / AI Specialist free first attempts',
        summary = 'Salesforce offered free first-time attempts for the AI Associate and AI Specialist exams.',
        eligibility = 'Time-bound promotion: re-verify on the official Certification page before planning around it.',
        verified = true,
        source = 'https://www.salesforce.com/blog/small-business/ai-trailhead-certifications/?bc=OTH',
    },
    {
        name = 'Certification Days',
        summary = 'Free exam-prep webinars; attendees historically received a 50%-off voucher'
            .. ' (a discount, not a free exam).',
        eligibility = 'Webinar attendance. Whether the program still runs is unconfirmed.',
        verified = false,
        source = 'https://www.apexhours.com/salesforce-certification-days/',
    },
    {
        name = 'Community group meetups',
        summary = 'Trailblazer Community Group leaders sometimes receive vouchers for quiz or raffle'
            .. ' prizes at local events.',
        eligibility = 'Attend local meetups; availability varies by event.',
        verified = false,
        source = 'https://trailblazercommunitygroups.com/events/',
    },
    {
        name = 'Community voucher tracker',
        summary = 'Dinesh Yadav maintains a community page tracking currently available public vouchers.',
        eligibility = 'Third-party tracker; verify each listing before relying on it.',
        verified = false,
        source = 'https://dineshyadav.com/how-to-get-free-or-discounted-salesforce-certification-voucher/',
    },
}

local state = {
    jobs = {},
    by_id = {},
    running_count = 0,
    sequence = 0,
    subscribers = {},
    loaded = false,
}

-- Forward declarations: finish_job -> pump -> run_job -> advance ->
-- step_done -> advance/finish_job form a cycle.
local pump ---@type fun()
local advance ---@type fun(job: TrailheadJob, generation: integer)

---@return string
local function state_path()
    return fn.stdpath('data') .. '/diver/sf/trailhead.json'
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
    if #value > limit then
        return value:sub(1, limit - 3) .. '...'
    end
    return value
end

---@param job TrailheadJob
---@param line string
local function append_log(job, line)
    local text = truncate(tostring(line):gsub('\r', ''), LOG_LINE_BYTES_MAX)
    job.log[#job.log + 1] = text
    while #job.log > LOG_LINE_COUNT_MAX do
        table.remove(job.log, 1)
    end
    job.updated_at = os.time()
end

---@param event TrailheadEvent
local function emit(event)
    for _, subscriber in ipairs(state.subscribers) do
        local ok, err = pcall(subscriber, event)
        if not ok then
            core.notify('Trailhead event subscriber failed: ' .. tostring(err), vim.log.levels.WARN)
        end
    end
end

---@param job TrailheadJob
---@return table
local function persist_job(job)
    local steps = {}
    for _, step in ipairs(job.steps) do
        steps[#steps + 1] = {
            name = step.name,
            argv = step.argv,
            note = step.note,
            status = step.status,
            detail = step.detail,
        }
    end
    local log = {}
    local first = math.max(1, #job.log - PERSIST_LOG_LINES_MAX + 1)
    for index = first, #job.log do
        log[#log + 1] = job.log[index]
    end
    return {
        id = job.id,
        kind = job.kind,
        title = job.title,
        status = job.status,
        steps = steps,
        created_at = job.created_at,
        updated_at = job.updated_at,
        log = log,
        result = job.result,
        error = job.error,
    }
end

local function save_state()
    local dir = fn.fnamemodify(state_path(), ':h')
    if fn.isdirectory(dir) == 0 then
        local ok = pcall(fn.mkdir, dir, 'p')
        if not ok then
            return
        end
    end
    local jobs = {}
    for _, job in ipairs(state.jobs) do
        jobs[#jobs + 1] = persist_job(job)
    end
    local ok, encoded = pcall(vim.json.encode, jobs)
    if not ok or type(encoded) ~= 'string' then
        return
    end
    -- Atomic publish: write the temp file, then rename over the state.
    -- A crash mid-write never leaves a half-written state file behind.
    local path = state_path()
    local tmp = path .. '.tmp'
    local wrote = pcall(function()
        local handle = io.open(tmp, 'w')
        if not handle then
            error('cannot open state temp file')
        end
        handle:write(encoded)
        handle:close()
    end)
    if wrote then
        -- pcall only reports that os.rename was *called*; a failed rename
        -- returns (nil, err), so the rename result must be checked too.
        local called, renamed = pcall(os.rename, tmp, path)
        if not called or not renamed then
            pcall(os.remove, tmp)
        end
    else
        pcall(os.remove, tmp)
    end
end

---@param raw any
---@return string[]?
local function coerce_argv(raw)
    if type(raw) ~= 'table' then
        return nil
    end
    -- Uniform rejection: untrusted argv is only trusted when it is a plain
    -- sequence of in-bounds strings. Anything else degrades to no argv
    -- (an external step), so hostile state can never smuggle a spawn.
    local count = #raw
    if count == 0 or count > STEP_ARGV_COUNT_MAX then
        return nil
    end
    ---@type string[]
    local argv = {}
    for index = 1, count do
        local arg = raw[index]
        if type(arg) ~= 'string' or #arg > STEP_ARGV_BYTES_MAX then
            return nil
        end
        argv[index] = arg
    end
    for key in pairs(raw) do
        if type(key) ~= 'number' or key < 1 or key > count or key ~= math.floor(key) then
            return nil
        end
    end
    return argv
end

---@param raw any
---@return string[]
local function coerce_log(raw)
    if type(raw) ~= 'table' then
        return {}
    end
    ---@type string[]
    local log = {}
    for _, line in ipairs(raw) do
        if #log >= LOG_LINE_COUNT_MAX then
            break
        end
        if type(line) == 'string' then
            log[#log + 1] = truncate(line:gsub('\r', ''), LOG_LINE_BYTES_MAX)
        end
    end
    return log
end

---@param raw table
---@return TrailheadJob?
local function coerce_job(raw)
    -- Overlong ids are rejected rather than truncated: truncation could
    -- collapse two hostile ids into one by_id slot.
    if type(raw.id) ~= 'string' or raw.id == '' or #raw.id > JOB_ID_BYTES_MAX then
        return nil
    end
    if type(raw.title) ~= 'string' then
        return nil
    end
    if type(raw.steps) ~= 'table' then
        return nil
    end
    ---@type TrailheadStep[]
    local steps = {}
    for _, item in ipairs(raw.steps) do
        if type(item) == 'table' and type(item.name) == 'string' and item.name ~= '' and #steps < STEPS_PER_JOB_MAX then
            steps[#steps + 1] = {
                name = truncate(item.name, STEP_NAME_BYTES_MAX),
                -- Hostile argv never survives the load: unvalidated entries
                -- degrade to no argv (external step) rather than a spawn.
                argv = coerce_argv(item.argv),
                note = type(item.note) == 'string' and truncate(item.note, NOTE_BYTES_MAX) or nil,
                -- A stale 'running' step never resumes mid-flight; it goes
                -- back to pending so resume() retries it cleanly.
                status = 'pending',
                detail = type(item.detail) == 'string' and truncate(item.detail, RESULT_BYTES_MAX) or nil,
            }
        end
    end
    local status = raw.status
    if
        status ~= 'queued'
        and status ~= 'paused'
        and status ~= 'done'
        and status ~= 'failed'
        and status ~= 'cancelled'
    then
        -- 'running' cannot survive a restart: nothing is driving it.
        status = 'paused'
    end
    ---@type TrailheadJob
    local job = {
        id = raw.id,
        kind = JOB_KINDS[raw.kind] and raw.kind or 'note',
        title = truncate(raw.title, TITLE_BYTES_MAX),
        status = status,
        steps = steps,
        created_at = type(raw.created_at) == 'number' and math.floor(raw.created_at) or os.time(),
        updated_at = os.time(),
        log = coerce_log(raw.log),
        result = type(raw.result) == 'string' and truncate(raw.result, RESULT_BYTES_MAX) or nil,
        error = type(raw.error) == 'string' and truncate(raw.error, RESULT_BYTES_MAX) or nil,
        generation = 0,
    }
    return job
end

local function ensure_loaded()
    if state.loaded then
        return
    end
    state.loaded = true
    local ok, raw = pcall(function()
        local path = state_path()
        -- Bound the read before touching the bytes: a planted oversized
        -- file must not exhaust memory on startup.
        if fn.getfsize(path) > STATE_READ_BYTES_MAX then
            return nil
        end
        local handle = io.open(path, 'r')
        if not handle then
            return nil
        end
        local content = handle:read('*a')
        handle:close()
        if type(content) ~= 'string' or content == '' or #content > STATE_READ_BYTES_MAX then
            return nil
        end
        return content
    end)
    if not ok or type(raw) ~= 'string' or raw == '' then
        return
    end
    local decoded_ok, decoded = pcall(vim.json.decode, raw)
    if not decoded_ok or type(decoded) ~= 'table' then
        return
    end
    for _, item in ipairs(decoded) do
        if #state.jobs < JOB_COUNT_MAX and type(item) == 'table' then
            local job = coerce_job(item)
            -- First job wins its id: a hostile file cannot shadow a job
            -- already loaded under the same id.
            if job and not state.by_id[job.id] then
                state.jobs[#state.jobs + 1] = job
                state.by_id[job.id] = job
            end
        end
    end
end

---@param job TrailheadJob
---@param status string
local function set_job_status(job, status)
    job.status = status
    job.updated_at = os.time()
    emit({ type = 'job', job_id = job.id, status = status })
    save_state()
end

---@param job TrailheadJob
---@return TrailheadStep?
local function current_step(job)
    for _, step in ipairs(job.steps) do
        if step.status == 'pending' then
            return step
        end
    end
    return nil
end

---@param job TrailheadJob
---@return TrailheadStep?
local function waiting_step(job)
    for _, step in ipairs(job.steps) do
        if step.status == 'running' then
            return step
        end
    end
    return nil
end

---@param job TrailheadJob
---@param status string
---@param err? string
local function finish_job(job, status, err)
    job.handle = nil
    state.running_count = math.max(0, state.running_count - 1)
    if status == 'done' then
        job.result = ('completed %d of %d steps'):format(#job.steps, #job.steps)
        job.error = nil
        append_log(job, 'job done')
    else
        job.error = err
        append_log(job, 'job ' .. status .. (err and (': ' .. err) or ''))
    end
    set_job_status(job, status)
    pump()
end

---@param job TrailheadJob
---@param step TrailheadStep
---@param generation integer
---@param ok boolean
---@param detail string
local function step_done(job, step, generation, ok, detail)
    if generation ~= job.generation then
        return
    end
    step.status = ok and 'done' or 'failed'
    if detail ~= '' then
        step.detail = truncate(detail, RESULT_BYTES_MAX)
    end
    emit({ type = 'step', job_id = job.id, status = step.status, step = step.name })
    append_log(job, ('step %s: %s'):format(step.status, step.name))
    if not ok then
        finish_job(job, 'failed', step.name .. ': ' .. (step.detail or 'failed'))
        return
    end
    advance(job, generation)
end

---@param job TrailheadJob
---@param generation integer
---@param result vim.SystemCompleted
local function on_shell_exit(job, step, generation, result)
    if generation ~= job.generation then
        return
    end
    job.handle = nil
    local chunks = {}
    if type(result.stdout) == 'string' and result.stdout ~= '' then
        chunks[#chunks + 1] = result.stdout
    end
    if type(result.stderr) == 'string' and result.stderr ~= '' then
        chunks[#chunks + 1] = result.stderr
    end
    local output = table.concat(chunks, '\n')
    local kept = 0
    for line in output:gmatch('[^\n]+') do
        if kept >= STEP_LOG_LINES_MAX then
            append_log(job, ('... output truncated after %d lines'):format(STEP_LOG_LINES_MAX))
            break
        end
        append_log(job, '  | ' .. line)
        kept = kept + 1
    end
    if result.code == 0 then
        step_done(job, step, generation, true, 'exit 0')
    else
        step_done(job, step, generation, false, ('exit %d'):format(result.code))
    end
end

---@param job TrailheadJob
---@param step TrailheadStep
---@param generation integer
local function run_shell_step(job, step, generation)
    assert(step.argv ~= nil, 'shell step requires argv')
    local argv = step.argv
    local ok, sysobj = pcall(vim.system, argv, {
        cwd = core.root(),
        text = true,
        timeout = STEP_TIMEOUT_MS,
    }, function(result)
        vim.schedule(function()
            on_shell_exit(job, step, generation, result)
        end)
    end)
    if not ok or sysobj == nil then
        step_done(job, step, generation, false, 'failed to spawn: ' .. tostring(sysobj))
        return
    end
    job.handle = sysobj
end

---@param job TrailheadJob
---@param generation integer
advance = function(job, generation)
    if generation ~= job.generation then
        return
    end
    local step = current_step(job)
    if not step then
        finish_job(job, 'done', nil)
        return
    end
    step.status = 'running'
    emit({ type = 'step', job_id = job.id, status = 'running', step = step.name })
    append_log(job, 'step started: ' .. step.name)
    if step.argv then
        run_shell_step(job, step, generation)
    elseif step.note then
        -- Note steps finish on their own; external steps wait below.
        vim.schedule(function()
            step_done(job, step, generation, true, step.note or 'noted')
        end)
    else
        -- External/browser step: neither argv nor note. It stays waiting
        -- until complete_step() or fail_step() reports it. Persist the
        -- wait so a restart does not lose track of the running step.
        append_log(job, 'step waiting for report: ' .. step.name)
        save_state()
    end
end

---@param job TrailheadJob
local function run_job(job)
    job.generation = job.generation + 1
    state.running_count = state.running_count + 1
    set_job_status(job, 'running')
    advance(job, job.generation)
end

pump = function()
    for _, job in ipairs(state.jobs) do
        if state.running_count >= ACTIVE_JOB_COUNT_MAX then
            return
        end
        if job.status == 'queued' then
            run_job(job)
        end
    end
end

---@param opts TrailheadEnqueueOpts
---@return string? job_id, string? err
function M.enqueue(opts)
    ensure_loaded()
    if type(opts) ~= 'table' then
        return nil, 'enqueue expects an options table'
    end
    if not JOB_KINDS[opts.kind] then
        return nil, 'unknown job kind: ' .. tostring(opts.kind)
    end
    if type(opts.title) ~= 'string' or opts.title == '' then
        return nil, 'job title is required'
    end
    if #state.jobs >= JOB_COUNT_MAX then
        return nil, ('job queue is full (%d jobs)'):format(JOB_COUNT_MAX)
    end
    state.sequence = state.sequence + 1
    local id = ('th-%d-%d'):format(os.time(), state.sequence)
    ---@type TrailheadJob
    local job = {
        id = id,
        kind = opts.kind,
        title = truncate(opts.title, TITLE_BYTES_MAX),
        -- Draft state: steps are attached while paused, then start() or
        -- resume() drives the job. Manual complete_step()/fail_step()
        -- only report the waiting external step of a running job.
        status = 'paused',
        steps = {},
        created_at = os.time(),
        updated_at = os.time(),
        log = {},
        generation = 0,
    }
    state.jobs[#state.jobs + 1] = job
    state.by_id[id] = job
    append_log(job, 'enqueued: ' .. job.title)
    set_job_status(job, 'paused')
    return id, nil
end

---@param id string
---@param opts TrailheadStepOpts
---@return boolean ok, string? err
function M.add_step(id, opts)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return false, 'unknown job id'
    end
    if job.status == 'running' then
        return false, 'cannot add steps to a running job'
    end
    if type(opts) ~= 'table' or type(opts.name) ~= 'string' or opts.name == '' then
        return false, 'step name is required'
    end
    if #job.steps >= STEPS_PER_JOB_MAX then
        return false, ('job already has %d steps'):format(STEPS_PER_JOB_MAX)
    end
    ---@type TrailheadStep
    local step = { name = truncate(opts.name, STEP_NAME_BYTES_MAX), status = 'pending' }
    if opts.argv ~= nil then
        if type(opts.argv) ~= 'table' or #opts.argv == 0 then
            return false, 'step argv must be a non-empty list of strings'
        end
        if #opts.argv > STEP_ARGV_COUNT_MAX then
            return false, ('step argv exceeds %d arguments'):format(STEP_ARGV_COUNT_MAX)
        end
        local argv = {}
        for _, arg in ipairs(opts.argv) do
            if type(arg) ~= 'string' then
                return false, 'step argv must contain only strings'
            end
            if #arg > STEP_ARGV_BYTES_MAX then
                return false, ('step argv argument exceeds %d bytes'):format(STEP_ARGV_BYTES_MAX)
            end
            argv[#argv + 1] = arg
        end
        step.argv = argv
    elseif type(opts.note) == 'string' and opts.note ~= '' then
        step.note = truncate(opts.note, NOTE_BYTES_MAX)
    end
    job.steps[#job.steps + 1] = step
    append_log(job, 'step added: ' .. step.name)
    save_state()
    return true, nil
end

---@param id string
---@return boolean ok, string? err
function M.start(id)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return false, 'unknown job id'
    end
    if job.status == 'running' or job.status == 'queued' then
        return false, 'job is already active'
    end
    if job.status == 'done' then
        return false, 'job already finished'
    end
    if #job.steps == 0 then
        return false, 'job has no steps'
    end
    job.generation = job.generation + 1
    job.error = nil
    for _, step in ipairs(job.steps) do
        if step.status ~= 'done' then
            step.status = 'pending'
            step.detail = nil
        end
    end
    append_log(job, 'started')
    set_job_status(job, 'queued')
    pump()
    return true, nil
end

---@param id string
---@return boolean ok, string? err
function M.cancel(id)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return false, 'unknown job id'
    end
    if job.status ~= 'running' and job.status ~= 'queued' then
        return false, 'job is not active'
    end
    -- Invalidate in-flight async callbacks before touching the handle.
    job.generation = job.generation + 1
    local handle = job.handle
    job.handle = nil
    if handle then
        pcall(function()
            handle:kill('sigterm')
        end)
    end
    if job.status == 'running' then
        state.running_count = math.max(0, state.running_count - 1)
        for _, step in ipairs(job.steps) do
            if step.status == 'running' then
                step.status = 'pending'
            end
        end
    end
    append_log(job, 'cancelled by user')
    set_job_status(job, 'cancelled')
    pump()
    return true, nil
end

---@param id string
---@return boolean ok, string? err
function M.resume(id)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return false, 'unknown job id'
    end
    if job.status == 'running' or job.status == 'queued' then
        return false, 'job is already active'
    end
    if job.status == 'done' then
        return false, 'job already finished'
    end
    job.generation = job.generation + 1
    job.error = nil
    job.result = nil
    for _, step in ipairs(job.steps) do
        if step.status ~= 'done' then
            step.status = 'pending'
            step.detail = nil
        end
    end
    append_log(job, 'resumed')
    set_job_status(job, 'queued')
    pump()
    return true, nil
end

---@param id string
---@param step_name string
---@param result? string
---@return boolean ok, string? err
function M.complete_step(id, step_name, result)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return false, 'unknown job id'
    end
    -- Manual reporting only covers the currently waiting external step of
    -- a running job. Paused drafts are built with add_step, not reports;
    -- shell and note steps finish on their own.
    if job.status ~= 'running' then
        return false, 'job is not running; start it before reporting steps'
    end
    if type(step_name) ~= 'string' or step_name == '' then
        return false, 'step name is required'
    end
    local step = waiting_step(job)
    if not step then
        return false, 'no step is currently waiting for a report'
    end
    if step.name ~= step_name then
        return false, 'only the waiting step can be reported: ' .. step.name
    end
    if step.argv ~= nil then
        return false, 'step is shell-driven; it completes on its own'
    end
    if step.note ~= nil then
        return false, 'step is note-driven; it completes on its own'
    end
    local detail = (type(result) == 'string' and result ~= '') and result or 'reported'
    step_done(job, step, job.generation, true, detail)
    save_state()
    return true, nil
end

---@param id string
---@param step_name string
---@param err string
---@return boolean ok, string? err
function M.fail_step(id, step_name, err)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return false, 'unknown job id'
    end
    -- Manual reporting only covers the currently waiting external step of
    -- a running job; see complete_step for the rationale.
    if job.status ~= 'running' then
        return false, 'job is not running; start it before reporting steps'
    end
    if type(step_name) ~= 'string' or step_name == '' then
        return false, 'step name is required'
    end
    local step = waiting_step(job)
    if not step then
        return false, 'no step is currently waiting for a report'
    end
    if step.name ~= step_name then
        return false, 'only the waiting step can be reported: ' .. step.name
    end
    if step.argv ~= nil then
        return false, 'step is shell-driven; it completes on its own'
    end
    if step.note ~= nil then
        return false, 'step is note-driven; it completes on its own'
    end
    local detail = (type(err) == 'string' and err ~= '') and err or 'reported as failed'
    step_done(job, step, job.generation, false, detail)
    return true, nil
end

---@param job TrailheadJob
---@return TrailheadJob
local function copy_job(job)
    -- Deep enough to stop aliasing attacks: steps, argv and log are copied
    -- so callers cannot mutate live scheduler state through a returned job.
    ---@type TrailheadStep[]
    local steps = {}
    for _, step in ipairs(job.steps) do
        ---@type string[]?
        local argv = nil
        if step.argv ~= nil then
            argv = {}
            for _, arg in ipairs(step.argv) do
                argv[#argv + 1] = arg
            end
        end
        steps[#steps + 1] = {
            name = step.name,
            argv = argv,
            note = step.note,
            status = step.status,
            detail = step.detail,
        }
    end
    ---@type string[]
    local log = {}
    for _, line in ipairs(job.log) do
        log[#log + 1] = line
    end
    ---@type TrailheadJob
    local copy = {
        id = job.id,
        kind = job.kind,
        title = job.title,
        status = job.status,
        steps = steps,
        created_at = job.created_at,
        updated_at = job.updated_at,
        log = log,
        result = job.result,
        error = job.error,
        generation = job.generation,
    }
    return copy
end

---@param id string
---@return TrailheadJob?
function M.get(id)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return nil
    end
    return copy_job(job)
end

---@return TrailheadJob[]
function M.list()
    ensure_loaded()
    ---@type TrailheadJob[]
    local jobs = {}
    for _, job in ipairs(state.jobs) do
        jobs[#jobs + 1] = copy_job(job)
    end
    return jobs
end

---@param id string
---@return integer done_count, integer total_count, string? err
function M.progress(id)
    ensure_loaded()
    local job = type(id) == 'string' and state.by_id[id] or nil
    if not job then
        return 0, 0, 'unknown job id'
    end
    local done_count = 0
    for _, step in ipairs(job.steps) do
        if step.status == 'done' then
            done_count = done_count + 1
        end
    end
    return done_count, #job.steps, nil
end

---@param subscriber fun(event: TrailheadEvent)
---@return boolean ok, string? err
function M.on_event(subscriber)
    if type(subscriber) ~= 'function' then
        return false, 'trailhead subscriber must be a function'
    end
    if #state.subscribers >= SUBSCRIBER_COUNT_MAX then
        return false, ('too many event subscribers (%d)'):format(SUBSCRIBER_COUNT_MAX)
    end
    state.subscribers[#state.subscribers + 1] = subscriber
    return true, nil
end

---@return string[]
function M.quest_lines()
    local lines = {
        'Free Salesforce certification voucher sources (researched 2026-09-27).',
        'VERIFIED = confirmed against an official Salesforce source.',
        'SPECULATIVE = third-party report or otherwise unconfirmed.',
        '',
    }
    for index, source in ipairs(VOUCHER_SOURCES) do
        lines[#lines + 1] = ('%d. %s [%s]'):format(index, source.name, source.verified and 'VERIFIED' or 'SPECULATIVE')
        lines[#lines + 1] = '   ' .. source.summary
        lines[#lines + 1] = '   Eligibility: ' .. source.eligibility
        lines[#lines + 1] = '   Source: ' .. source.source
        lines[#lines + 1] = ''
    end
    lines[#lines + 1] = 'Open item: the Trailblazer profile trailblazer.me/id/qompassai'
    lines[#lines + 1] = 'needs a live browser visit to inspect badges, rank, and quest eligibility.'
    return lines
end

---@param id? string
---@return string
function M.status(id)
    ensure_loaded()
    if type(id) == 'string' and id ~= '' then
        local job = state.by_id[id]
        if not job then
            return 'unknown job id: ' .. id
        end
        local done_count = 0
        for _, step in ipairs(job.steps) do
            if step.status == 'done' then
                done_count = done_count + 1
            end
        end
        local lines = {
            ('job %s [%s] %s'):format(job.id, job.status, job.title),
            ('progress: %d/%d steps'):format(done_count, #job.steps),
        }
        for _, step in ipairs(job.steps) do
            lines[#lines + 1] = ('  [%s] %s'):format(step.status, step.name)
        end
        if job.error then
            lines[#lines + 1] = 'error: ' .. job.error
        end
        if job.result then
            lines[#lines + 1] = 'result: ' .. job.result
        end
        return table.concat(lines, '\n')
    end
    local active = 0
    for _, job in ipairs(state.jobs) do
        if job.status == 'running' or job.status == 'queued' then
            active = active + 1
        end
    end
    local lines = { ('trailhead jobs: %d total, %d active'):format(#state.jobs, active) }
    for _, job in ipairs(state.jobs) do
        if job.status == 'running' or job.status == 'queued' then
            local done_count = 0
            for _, step in ipairs(job.steps) do
                if step.status == 'done' then
                    done_count = done_count + 1
                end
            end
            lines[#lines + 1] = ('  %s [%s] %s (%d/%d)'):format(job.id, job.status, job.title, done_count, #job.steps)
        end
    end
    return table.concat(lines, '\n')
end

---@param title string
---@param lines string[]
local function open_scratch(title, lines)
    vim.cmd('enew')
    local bufnr = api.nvim_get_current_buf()
    api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
    api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
    api.nvim_set_option_value('swapfile', false, { buf = bufnr })
    pcall(api.nvim_buf_set_name, bufnr, title)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    api.nvim_set_option_value('modifiable', false, { buf = bufnr })
end

---@param err? string
local function notify_expected(err)
    -- Expected user errors (bad id, wrong state, bad usage) report at WARN:
    -- an ERROR-level notify inside a user-command callback makes vim.cmd
    -- throw on Neovim 0.13, which would punish programmatic callers.
    core.notify(err or 'unknown error', vim.log.levels.WARN)
end

---@param opts SfCommandArgs
local function cmd_enqueue(opts)
    local args = core.get_args(opts)
    if #args < 2 then
        core.notify('Usage: SfTrailheadEnqueue {trailmix|quest|study|shell|note} {title}', vim.log.levels.WARN)
        return
    end
    local id, err = M.enqueue({ kind = args[1], title = table.concat(args, ' ', 2) })
    if not id then
        notify_expected(err)
        return
    end
    core.notify('Trailhead job enqueued: ' .. id, vim.log.levels.INFO)
end

---@param opts SfCommandArgs
local function cmd_add_step(opts)
    local args = core.get_args(opts)
    if #args < 3 then
        core.notify('Usage: SfTrailheadAddStep {id} {shell|note} {name} [argv...|text...]', vim.log.levels.WARN)
        return
    end
    local id, mode, name = args[1], args[2], args[3]
    ---@type TrailheadStepOpts
    local step_opts = { name = name }
    if mode == 'shell' then
        if #args < 4 then
            core.notify('Shell steps need at least one argv entry', vim.log.levels.WARN)
            return
        end
        local argv = {}
        for index = 4, #args do
            argv[#argv + 1] = args[index]
        end
        step_opts.argv = argv
    elseif mode == 'note' then
        -- Trailing words become the note text; a bare note step records
        -- its own name, keeping the CLI's auto-complete behavior.
        if #args > 3 then
            step_opts.note = table.concat(args, ' ', 4)
        else
            step_opts.note = name
        end
    else
        core.notify('Step mode must be shell or note', vim.log.levels.WARN)
        return
    end
    local ok, err = M.add_step(id, step_opts)
    if not ok then
        notify_expected(err)
        return
    end
    core.notify(('Step added to %s: %s'):format(id, name), vim.log.levels.INFO)
end

---@param opts SfCommandArgs
local function cmd_start(opts)
    local id = core.get_arg(opts)
    if not id then
        core.notify('Usage: SfTrailheadStart {id}', vim.log.levels.WARN)
        return
    end
    local ok, err = M.start(id)
    if not ok then
        notify_expected(err)
        return
    end
    core.notify('Trailhead job started: ' .. id, vim.log.levels.INFO)
end

---@param opts SfCommandArgs
local function cmd_cancel(opts)
    local id = core.get_arg(opts)
    if not id then
        core.notify('Usage: SfTrailheadCancel {id}', vim.log.levels.WARN)
        return
    end
    local ok, err = M.cancel(id)
    if not ok then
        notify_expected(err)
        return
    end
    core.notify('Trailhead job cancelled: ' .. id, vim.log.levels.INFO)
end

---@return integer cancelled
function M.cancel_all()
    ensure_loaded()
    local cancelled = 0
    for _, job in ipairs(state.jobs) do
        if job.status == 'running' or job.status == 'queued' then
            local ok = M.cancel(job.id)
            if ok then
                cancelled = cancelled + 1
            end
        end
    end
    return cancelled
end

local function cmd_cancel_all()
    local cancelled = M.cancel_all()
    core.notify(('Cancelled %d Trailhead job(s)'):format(cancelled), vim.log.levels.INFO)
end

---@param opts SfCommandArgs
local function cmd_resume(opts)
    local id = core.get_arg(opts)
    if not id then
        core.notify('Usage: SfTrailheadResume {id}', vim.log.levels.WARN)
        return
    end
    local ok, err = M.resume(id)
    if not ok then
        notify_expected(err)
        return
    end
    core.notify('Trailhead job resumed: ' .. id, vim.log.levels.INFO)
end

---@param opts SfCommandArgs
local function cmd_complete(opts)
    local args = core.get_args(opts)
    if #args < 2 then
        core.notify('Usage: SfTrailheadDone {id} {step} [result]', vim.log.levels.WARN)
        return
    end
    local result = #args > 2 and table.concat(args, ' ', 3) or nil
    local ok, err = M.complete_step(args[1], args[2], result)
    if not ok then
        notify_expected(err)
        return
    end
    core.notify(('Step reported done: %s'):format(args[2]), vim.log.levels.INFO)
end

---@param opts SfCommandArgs
local function cmd_fail(opts)
    local args = core.get_args(opts)
    if #args < 3 then
        core.notify('Usage: SfTrailheadFail {id} {step} {error}', vim.log.levels.WARN)
        return
    end
    local ok, err = M.fail_step(args[1], args[2], table.concat(args, ' ', 3))
    if not ok then
        notify_expected(err)
        return
    end
    core.notify(('Step reported failed: %s'):format(args[2]), vim.log.levels.INFO)
end

---@param opts SfCommandArgs
local function cmd_status(opts)
    core.notify(M.status(core.get_arg(opts)), vim.log.levels.INFO)
end

local function cmd_jobs()
    ensure_loaded()
    local lines = { 'Trailhead jobs', '' }
    for _, job in ipairs(state.jobs) do
        local done_count = 0
        for _, step in ipairs(job.steps) do
            if step.status == 'done' then
                done_count = done_count + 1
            end
        end
        lines[#lines + 1] = ('%s [%s] (%s) %d/%d steps'):format(job.id, job.status, job.kind, done_count, #job.steps)
        lines[#lines + 1] = '  ' .. job.title
    end
    open_scratch('trailhead-jobs', lines)
end

---@param opts SfCommandArgs
local function cmd_log(opts)
    local id = core.get_arg(opts)
    if not id then
        core.notify('Usage: SfTrailheadLog {id}', vim.log.levels.WARN)
        return
    end
    ensure_loaded()
    local job = state.by_id[id]
    if not job then
        notify_expected('unknown job id')
        return
    end
    local lines = { ('Log for %s: %s'):format(job.id, job.title), '' }
    for _, line in ipairs(job.log) do
        lines[#lines + 1] = line
    end
    open_scratch('trailhead-log-' .. job.id, lines)
end

local function cmd_quests()
    open_scratch('trailhead-voucher-sources', M.quest_lines())
end

M.commands = {
    { name = 'SfTrailheadEnqueue', fn = cmd_enqueue, opts = { desc = 'Enqueue a Trailhead agent job', nargs = '+' } },
    {
        name = 'SfTrailheadAddStep',
        fn = cmd_add_step,
        opts = { desc = 'Add a step to a Trailhead job', nargs = '+' },
    },
    { name = 'SfTrailheadStart',   fn = cmd_start,   opts = { desc = 'Start a Trailhead job', nargs = '?' } },
    { name = 'SfTrailheadCancel',  fn = cmd_cancel,  opts = { desc = 'Cancel a Trailhead job', nargs = '?' } },
    {
        name = 'SfTrailheadCancelAll',
        fn = cmd_cancel_all,
        opts = { desc = 'Cancel all active Trailhead jobs', nargs = 0 },
    },
    { name = 'SfTrailheadResume', fn = cmd_resume, opts = { desc = 'Resume a Trailhead job', nargs = '?' } },
    {
        name = 'SfTrailheadDone',
        fn = cmd_complete,
        opts = { desc = 'Report a Trailhead step done (external agent)', nargs = '+' },
    },
    {
        name = 'SfTrailheadFail',
        fn = cmd_fail,
        opts = { desc = 'Report a Trailhead step failed (external agent)', nargs = '+' },
    },
    { name = 'SfTrailheadStatus', fn = cmd_status, opts = { desc = 'Show Trailhead job status', nargs = '?' } },
    { name = 'SfTrailheadJobs',   fn = cmd_jobs,   opts = { desc = 'List Trailhead jobs', nargs = 0 } },
    { name = 'SfTrailheadLog',    fn = cmd_log,    opts = { desc = 'Show a Trailhead job log', nargs = '?' } },
    {
        name = 'SfTrailheadQuests',
        fn = cmd_quests,
        opts = { desc = 'Show free certification voucher sources', nargs = 0 },
    },
}

return M
