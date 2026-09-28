-- recon.lua
--
-- Reconnaissance job control: staged discovery with the scope gate enforced.
--
-- Plain language: recon is knocking on doors to see which exist -- finding
-- subdomains, live servers, open ports, known CVEs. This module runs the
-- discovery tools in order, saves everything under
-- ~/security/bugbounties/recon/<program>/<run-id>/, and REFUSES to start
-- unless the scope gate is open (see gates.lua). Every target is derived
-- mechanically from the filed scope -- a host not on the permission slip
-- is never touched, no matter what.
--
-- The cycle: subfinder -> dnsx -> httpx -> naabu -> nuclei -> katana.
-- ffuf is available as an opt-in stage (it needs a wordlist). After each
-- full cycle, nuclei findings are diffed against the previous run so only
-- NEW findings surface -- this is the "iterate until something valid"
-- loop. Validation itself stays human: see gates.lua and report.lua.
--
-- FLAG REVIEW (2026-09-28): tool CLI flags below are the stable
-- ProjectDiscovery conventions; they will be re-verified against the
-- installed binaries once the paru install finishes, before first use.
---@module 'security.bounty.recon'

local gates = require('security.bounty.gates')
local scope = require('security.bounty.scope')
local profiles = require('security.bounty.profiles')

local M = {}

---In-memory run registry. Logs persist on disk; this table does not.
---@type table<string, security.bounty.RunState>
M.runs = {}
local run_seq = 0

---@class security.bounty.RunState
---@field id string
---@field program string
---@field dir string
---@field stage integer Index into the stage list (0 = not started).
---@field state string idle|running|done|cancelled|failed
---@field job? userdata Active vim.system job, if any.
---@field started_at string

---Run directory root.
---@return string
function M.dir()
    return vim.fn.expand('~/security/bugbounties/recon')
end

---Append one JSON line to the run log. Logs are the audit trail.
---@param run security.bounty.RunState
---@param event string
---@param data? table
local function log(run, event, data)
    local entry = {
        at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        run = run.id,
        event = event,
    }
    if data ~= nil then
        for k, v in pairs(data) do
            entry[k] = v
        end
    end
    local parts = {}
    for k, v in pairs(entry) do
        parts[#parts + 1] = ('"%s":"%s"'):format(k, tostring(v):gsub('"', '\\"'))
    end
    local fh = io.open(run.dir .. '/run.jsonl', 'a')
    if fh ~= nil then
        fh:write('{' .. table.concat(parts, ',') .. '}\n')
        fh:close()
    end
end

---Extract root domains from scope targets. Wildcards are unwrapped
---('*.example.com' -> 'example.com'); URLs are reduced to hosts; CIDRs
---and bare IPs are skipped (subdomain enumeration needs a domain).
---@param targets string[]
---@return string[] domains Sorted, deduplicated.
function M.domains(targets)
    local seen, domains = {}, {}
    for _, t in ipairs(targets) do
        local d = t:gsub('^%*%.', '')
        d = d:gsub('^https?://', ''):gsub('/.*$', ''):gsub(':%d+$', '')
        if d:match('^[A-Za-z0-9][A-Za-z0-9%.%-]*%.[A-Za-z]+$') and not seen[d] then
            seen[d] = true
            domains[#domains + 1] = d
        end
    end
    table.sort(domains)
    return domains
end

---Stage definitions. Each stage: name, tool binary, argv builder, output
---file. argv builders take (domains, dir, prev_outputs) and return argv.
---A stage is skipped with a warning when its binary is not on PATH.
local stages = {
    {
        name = 'subfinder',
        tool = 'subfinder',
        output = 'subfinder.txt',
        argv = function(domains, dir)
            local list = dir .. '/domains.txt'
            vim.fn.writefile(domains, list)
            -- FLAG-REVIEW: -dL file input, -silent, -o
            return { 'subfinder', '-dL', list, '-silent', '-o', dir .. '/subfinder.txt' }
        end,
    },
    {
        name = 'dnsx',
        tool = 'dnsx',
        output = 'dnsx.txt',
        argv = function(_, dir)
            -- FLAG-REVIEW: stdin input, -silent, -o
            return { 'dnsx', '-silent', '-o', dir .. '/dnsx.txt' }
        end,
        stdin_from = 'subfinder.txt',
    },
    {
        name = 'httpx',
        tool = 'httpx',
        output = 'httpx.txt',
        argv = function(_, dir)
            -- FLAG-REVIEW: -l list input, -silent, -o
            return { 'httpx', '-l', dir .. '/dnsx.txt', '-silent', '-o', dir .. '/httpx.txt' }
        end,
    },
    {
        name = 'naabu',
        tool = 'naabu',
        output = 'naabu.txt',
        argv = function(_, dir)
            -- FLAG-REVIEW: -l list input, -top-ports, -silent, -o.
            -- Naabu SYN scan needs privileges; without them it fails fast
            -- and the stage is recorded as failed, not faked.
            return {
                'naabu',
                '-l',
                dir .. '/httpx.txt',
                '-top-ports',
                '100',
                '-silent',
                '-o',
                dir .. '/naabu.txt',
            }
        end,
    },
    {
        name = 'nuclei',
        tool = 'nuclei',
        output = 'nuclei.txt',
        argv = function(_, dir)
            -- FLAG-REVIEW: -l list input, -silent, -o
            return { 'nuclei', '-l', dir .. '/httpx.txt', '-silent', '-o', dir .. '/nuclei.txt' }
        end,
    },
    {
        name = 'katana',
        tool = 'katana',
        output = 'katana.txt',
        argv = function(_, dir)
            -- FLAG-REVIEW: stdin URL input, -silent, -o
            return { 'katana', '-silent', '-o', dir .. '/katana.txt' }
        end,
        stdin_from = 'httpx.txt',
    },
}

---Is this binary on PATH?
---@param tool string
---@return boolean
local function have(tool)
    return vim.fn.executable(tool) == 1
end

---Which recon tools are currently installed.
---@return table<string, boolean>
function M.available()
    local out = {}
    for _, s in ipairs(stages) do
        out[s.tool] = have(s.tool)
    end
    out['ffuf'] = have('ffuf')
    out['cvemap'] = have('cvemap')
    out['searchpoc'] = have('searchpoc')
    return out
end

---Advance one run to its next stage. Internal; runs via callbacks.
---@param run security.bounty.RunState
local function advance(run)
    if run.state == 'cancelled' then
        return
    end
    run.stage = run.stage + 1
    local st = stages[run.stage]
    if st == nil then
        run.state = 'done'
        log(run, 'run_done')
        vim.notify(('BountyRecon %s: all stages complete (%s)'):format(run.program, run.dir))
        M.diff_findings(run)
        return
    end
    if not have(st.tool) then
        log(run, 'stage_skipped', { stage = st.name, reason = 'tool not installed: ' .. st.tool })
        vim.notify(
            ('BountyRecon: skipping %s (%s not on PATH)'):format(st.name, st.tool),
            vim.log.levels.WARN
        )
        advance(run)
        return
    end
    local argv = st.argv(M.domains(scope.targets(run.program)), run.dir)
    local stdin_text = nil
    if st.stdin_from ~= nil then
        local p = run.dir .. '/' .. st.stdin_from
        if vim.uv.fs_stat(p) ~= nil then
            stdin_text = table.concat(vim.fn.readfile(p), '\n')
        end
    end
    log(run, 'stage_start', { stage = st.name, argv = table.concat(argv, ' ') })
    run.job = vim.system(argv, { text = true, stdin = stdin_text }, function(result)
        run.job = nil
        vim.schedule(function()
            if run.state == 'cancelled' then
                return
            end
            log(run, 'stage_done', { stage = st.name, code = result.code })
            if result.code ~= 0 then
                vim.notify(
                    ('BountyRecon: stage %s exited %d (see %s/run.jsonl)'):format(
                        st.name,
                        result.code,
                        run.dir
                    ),
                    vim.log.levels.WARN
                )
            else
                vim.notify(('BountyRecon: stage %s done'):format(st.name))
            end
            advance(run)
        end)
    end)
end

---Start a recon run. Enforces the scope gate and scope-derived targeting.
---@param program string Program slug with a filed scope.
---@return string run_id
function M.run(program)
    assert(type(program) == 'string' and program ~= '', 'recon.run: program must be nonempty')
    assert(
        gates.is_open('scope', program),
        "recon.run: scope gate is CLOSED for '"
            .. program
            .. "' -- the operator must approve the scope first (:BountyApprove scope "
            .. program
            .. '). Active scanning without approval is unauthorized access.'
    )
    local domains = M.domains(scope.targets(program))
    assert(#domains > 0, "recon.run: no scannable domains in scope for '" .. program .. "'")
    -- A program profile is active: review the planned stages against the
    -- profile's prohibitions BEFORE anything runs. Hard-blocks abort the
    -- run; cautions (minimal testing, content access, re-ingest nudge) are
    -- surfaced as warnings.
    local profile_name = profiles.active()
    if profile_name ~= nil then
        local stage_names = {}
        for _, st in ipairs(stages) do
            stage_names[#stage_names + 1] = st.name
        end
        stage_names[#stage_names + 1] = 'ffuf' -- opt-in stage, reviewed too
        local ok, problems, warnings = profiles.check_recon_plan(profile_name, stage_names)
        assert(
            ok,
            ("recon.run: recon plan BLOCKED under profile '%s': %s"):format(
                profile_name,
                table.concat(problems, '; ')
            )
        )
        for _, warning in ipairs(warnings) do
            vim.notify(('BountyRecon [%s]: %s'):format(profile_name, warning), vim.log.levels.WARN)
        end
    end
    run_seq = run_seq + 1
    local id = os.date('%Y%m%d-%H%M%S') .. '-' .. run_seq
    local dir = M.dir() .. '/' .. program .. '/' .. id
    vim.fn.mkdir(dir, 'p')
    ---@type security.bounty.RunState
    local run = { id = id, program = program, dir = dir, stage = 0, state = 'running', started_at = os.date('!%Y-%m-%dT%H:%M:%SZ') }
    M.runs[id] = run
    log(run, 'run_start', { program = program, domains = table.concat(domains, ',') })
    vim.notify(('BountyRecon %s: starting (%d domains, scope gate open)'):format(program, #domains))
    advance(run)
    return id
end

---Cancel a running recon job. The job is killed; the log keeps the record.
---@param run_id string
function M.cancel(run_id)
    local run = M.runs[run_id]
    assert(run ~= nil, "recon.cancel: unknown run '" .. tostring(run_id) .. "'")
    run.state = 'cancelled'
    if run.job ~= nil then
        run.job:kill('sigterm')
        run.job = nil
    end
    log(run, 'run_cancelled')
    vim.notify(('BountyRecon %s: cancelled'):format(run_id), vim.log.levels.WARN)
end

---One-line status for every known run.
---@return string[] lines
function M.status()
    local lines = {}
    for id, run in pairs(M.runs) do
        local stage_name = stages[run.stage] and stages[run.stage].name or '-'
        lines[#lines + 1] = ('%s  %s  %s  stage=%s  %s'):format(
            id,
            run.program,
            run.state,
            stage_name,
            run.dir
        )
    end
    table.sort(lines)
    return lines
end

---Diff this run's nuclei findings against the previous run for the same
---program. Only NEW findings are worth operator attention -- this is the
---"iterate until something valid" loop made mechanical.
---@param run security.bounty.RunState
function M.diff_findings(run)
    local current = run.dir .. '/nuclei.txt'
    if vim.uv.fs_stat(current) == nil then
        return
    end
    local function findings_of(path)
        local set = {}
        for _, line in ipairs(vim.fn.readfile(path)) do
            if line ~= '' then
                set[line] = true
            end
        end
        return set
    end
    local prev_id, prev_time = nil, ''
    for id, other in pairs(M.runs) do
        if other.program == run.program and id ~= run.id and other.started_at > prev_time then
            local p = other.dir .. '/nuclei.txt'
            if vim.uv.fs_stat(p) ~= nil then
                prev_id, prev_time = id, other.started_at
            end
        end
    end
    local new_lines = {}
    local cur = findings_of(current)
    if prev_id ~= nil then
        local prev = findings_of(M.runs[prev_id].dir .. '/nuclei.txt')
        for line, _ in pairs(cur) do
            if not prev[line] then
                new_lines[#new_lines + 1] = line
            end
        end
    else
        for line, _ in pairs(cur) do
            new_lines[#new_lines + 1] = line
        end
    end
    table.sort(new_lines)
    log(run, 'findings_diff', { new = #new_lines, prev_run = prev_id or 'none' })
    if #new_lines > 0 then
        vim.fn.writefile(new_lines, run.dir .. '/nuclei-new.txt')
        vim.notify(
            ('BountyRecon %s: %d NEW nuclei finding(s) -- see %s/nuclei-new.txt'):format(
                run.program,
                #new_lines,
                run.dir
            ),
            vim.log.levels.INFO
        )
    else
        vim.notify(('BountyRecon %s: no new findings this cycle'):format(run.program))
    end
end

return M
