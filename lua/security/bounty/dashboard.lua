-- dashboard.lua
--
-- Snapshot the on-disk bounty state for rendering (PNG dashboard, reports).
--
-- Plain language: everything the dashboard shows already exists as files --
-- filed scopes, gate markers, recon run logs, reports. This module reads
-- those files and builds one snapshot table. It never opens a gate, never
-- scans, never touches the network: pure read-only collection.
---@module 'security.bounty.dashboard'

local scope = require('security.bounty.scope')
local gates = require('security.bounty.gates')
local profiles = require('security.bounty.profiles')

local M = {}

---Root of all bug-bounty working files (mirrors security.bounty.basedir).
---@return string
local function basedir()
    return vim.fn.expand('~/security/bugbounties')
end

---@return string
function M.png_path()
    return basedir() .. '/dashboard.png'
end

---Program slugs with a filed scope, sorted.
---@return string[]
local function filed_programs()
    local names = {}
    for _, path in ipairs(vim.fn.glob(basedir() .. '/scope/*.txt', false, true)) do
        names[#names + 1] = vim.fn.fnamemodify(path, ':t:r')
    end
    table.sort(names)
    return names
end

---Latest recon run for a program, from on-disk run.jsonl logs.
---Run dirs are timestamped (<yyyymmdd-hhmmss>-<seq>), so the
---lexicographically last one is the latest.
---@param program string
---@return table|nil run { id, state, stage, new_findings } or nil
local function latest_run(program)
    local dirs = vim.fn.glob(basedir() .. '/recon/' .. program .. '/*/run.jsonl', false, true)
    if #dirs == 0 then
        return nil
    end
    table.sort(dirs)
    local logpath = dirs[#dirs]
    local id = vim.fn.fnamemodify(vim.fn.fnamemodify(logpath, ':h'), ':t')
    local run = { id = id, state = 'unknown', stage = '-', new_findings = 0 }
    local fh = io.open(logpath, 'r')
    if fh == nil then
        return run
    end
    for line in fh:lines() do
        local ok, event = pcall(vim.json.decode, line)
        if ok and type(event) == 'table' and type(event.event) == 'string' then
            if event.event == 'run_start' then
                run.state = 'running'
            elseif event.event == 'stage_start' then
                run.stage = tostring(event.stage or '-')
            elseif event.event == 'run_done' then
                run.state = 'done'
            elseif event.event == 'run_cancelled' then
                run.state = 'cancelled'
            elseif event.event == 'findings_diff' and event.new ~= nil then
                run.new_findings = tonumber(event.new) or 0
            end
        end
    end
    fh:close()
    return run
end

---Reports filed for one program. Report files are named
---<date>-<platform>-<program>-<slug>.md.
---@param program string
---@return integer count
local function report_count(program)
    local count = 0
    local needle = '-' .. program .. '-'
    for _, path in ipairs(vim.fn.glob(basedir() .. '/reports/*.md', false, true)) do
        if vim.fn.fnamemodify(path, ':t'):find(needle, 1, true) then
            count = count + 1
        end
    end
    return count
end

---Build the snapshot table. Pure read-only.
---@return table snapshot
function M.collect()
    local programs = {}
    local total_targets, total_reports, total_findings = 0, 0, 0
    for _, name in ipairs(filed_programs()) do
        local targets = 0
        local ok, entries = pcall(scope.load, name)
        if ok and type(entries) == 'table' then
            targets = #entries
        end
        local gate_state = { scope = false, finding = false, submission = false }
        local ok_gates, status = pcall(gates.status, name)
        if ok_gates then
            gate_state = status
        end
        local reports = report_count(name)
        local run = latest_run(name)
        if run ~= nil then
            total_findings = total_findings + run.new_findings
        end
        total_targets = total_targets + targets
        total_reports = total_reports + reports
        programs[#programs + 1] = {
            name = name,
            scope_targets = targets,
            gates = gate_state,
            reports = reports,
            last_run = run,
        }
    end
    return {
        generated_at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        active_profile = profiles.active(),
        programs = programs,
        totals = {
            programs = #programs,
            scope_targets = total_targets,
            reports = total_reports,
            new_findings = total_findings,
        },
    }
end

---Directory of this file, so the renderer script is found no matter
---where the repo is checked out.
---@return string dir
local function this_dir()
    local source = debug.getinfo(1, 'S').source
    if source:sub(1, 1) == '@' then
        source = source:sub(2)
    end
    return vim.fn.fnamemodify(source, ':h')
end

---Render the dashboard PNG and show it through the native image preview.
function M.show()
    if vim.fn.executable('python3') ~= 1 then
        vim.notify('BountyDashboard: python3 not on PATH', vim.log.levels.ERROR)
        return
    end
    local snapshot = M.collect()
    local json = vim.json.encode(snapshot)
    local script = this_dir() .. '/dashboard_render.py'
    if vim.uv.fs_stat(script) == nil then
        vim.notify('BountyDashboard: renderer missing: ' .. script, vim.log.levels.ERROR)
        return
    end
    local png = M.png_path()
    -- Snapshot travels over stdin: never on the command line, never logged.
    local result = vim.system({ 'python3', script, png }, { stdin = json, text = true }):wait(60000)
    if result.code ~= 0 then
        vim.notify(
            'BountyDashboard: renderer failed: ' .. vim.trim(result.stderr or ''),
            vim.log.levels.ERROR
        )
        return
    end
    local img = require('config.ui.image')
    img.setup({ enabled = true })
    img.render(png)
    vim.notify(('BountyDashboard: %d program(s), %d new finding(s)'):format(
        snapshot.totals.programs,
        snapshot.totals.new_findings
    ))
end

return M
