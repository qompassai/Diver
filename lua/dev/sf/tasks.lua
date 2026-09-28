-- /qompassai/Diver/lua/dev/sf/tasks.lua
-- Qompass AI Diver Salesforce Async Agent Tasks
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Plain words: a Trailhead module is a recipe ("learn Apex, deploy a
-- class, run a script"). This module turns that recipe into an async
-- "agent task": an ordered list of `sf` CLI steps that the bounded job
-- queue in dev.sf.trailhead runs one by one, without blocking Neovim.
-- You dispatch a task, it runs in the background, you can cancel it,
-- and when it finishes a teach-doc appears at
-- docs/salesforce/<module>.md with the exact commands and what happened.
--
-- What this module does NOT do:
--   * invent sf flags -- every flag below is verified against the
--     Salesforce CLI Command Reference (see docs/salesforce/FLAGS.md);
--   * drive the Trailhead website (no public API exists for it -- the
--     teach-doc records CLI evidence only, never badge completion);
--   * fake results -- if no org is authorized, the org probe step fails
--     and the teach-doc says so plainly.
--
-- The "agent" here is the task runner itself: a deterministic, bounded,
-- cancellable sequence of sf invocations. A planner (rose.nvim, an A2A
-- orchestrator) can compose plans through dispatch(); every transition
-- is broadcast on trailhead.on_event() for those supervisors
-- (see lua/dev/sf/trailhead.lua).
---@module 'dev.sf.tasks'

local core = require('dev.sf.core')
local trailhead = require('dev.sf.trailhead')

local fn = vim.fn

---Canonical Salesforce CLI Command Reference. Opened 2026-09-28
---(reference version 2.152.14). Every flag used in the catalog below
---is verified against this page; see docs/salesforce/FLAGS.md.
local FLAGS_DOC = 'https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference.html'

---Slugs are teach-doc filenames too, so only safe filename characters.
local SLUG_PATTERN = '^[a-z0-9][a-z0-9_%-]*$'
local SLUG_MAX_BYTES = 64

---Target-org aliases/usernames: no shell metacharacters, bounded length.
local TARGET_ORG_PATTERN = '^[%w@._%-]+$'
local TARGET_ORG_MAX_BYTES = 128

---Log lines kept in a teach-doc; the full log stays in the job record.
local DOC_LOG_TAIL = 40

---@class SfTaskFlag
---@field flag string The CLI flag, exactly as typed on the command line.
---@field topic string The `sf` command topic the flag was verified under.

---@class SfTaskStepTemplate
---@field name string Step name (letters, digits, dashes).
---@field base string[] argv prefix: the `sf` command and its flag names.
---@field arg? string Value attached after `base` (a path or a SOQL string).
---@field trail? string[] argv parts appended after `arg` (e.g. `--json`).
---@field needs_org boolean True when `--target-org <alias>` is appended.
---@field expect string ELI5: what this step does.
---@field flags SfTaskFlag[] Every flag used, with the topic it was verified under.

---@class SfTaskModule
---@field slug string Catalog key; also the teach-doc filename stem.
---@field title string Human title.
---@field trailhead_url string The real Trailhead module page (verified 2026-09-28).
---@field summary string ELI5: what the task does.
---@field project_hint string Where to run it from (a Salesforce DX project root).
---@field learn string[] ELI5 lesson bullets recorded after a real run.
---@field steps SfTaskStepTemplate[]

---@class SfTaskStep
---@field name string Step name.
---@field argv string[] Exact argv dispatched (never shell-interpolated).
---@field expect string ELI5: what this step does.
---@field flags SfTaskFlag[]

---@class SfTaskDispatchOpts
---@field target_org? string Org alias/username; validated before use.
---@field mode? string 'live' (default) or 'hermetic' (stubbed dry run).

---@class SfDispatchedJob
---@field slug string
---@field target_org? string
---@field mode string 'live' | 'hermetic'
---@field title string
---@field trailhead_url string
---@field summary string
---@field learn string[]
---@field steps SfTaskStep[]
---@field dispatched_at string UTC timestamp.

---A step every module starts with: ask the CLI who it can talk to.
---If this step fails, nothing later in the plan can run for real.
---@return SfTaskStepTemplate
local function org_probe_step()
    return {
        name = 'list-authorized-orgs',
        base = { 'sf', 'org', 'list' },
        trail = { '--json' },
        needs_org = false,
        expect = 'List every org the CLI has credentials for, as JSON.',
        flags = {
            { flag = '--json', topic = 'org list' },
        },
    }
end

---The module catalog. Each entry is a Trailhead module's hands-on work
---translated into verified `sf` invocations.
---@type table<string, SfTaskModule>
local CATALOG = {
    ['org-auth'] = {
        slug = 'org-auth',
        title = 'Salesforce CLI auth check',
        trailhead_url = 'https://trailhead.salesforce.com/',
        summary = 'Before any Trailhead hands-on work, the sf CLI must know '
            .. 'which Salesforce org to talk to. This task asks the CLI which '
            .. 'orgs it has credentials for and which one is the default target.',
        project_hint = 'Any directory; no Salesforce project needed.',
        learn = {
            'sf org list --json shows every org the CLI holds credentials for, and checks whether each connection is still alive.',
            'An empty org list means nothing else in this workstream can run for real -- authenticate first (see docs/salesforce/auth.md).',
            'sf config get target-org --json shows the default org that later steps use when you do not pass --target-org.',
        },
        steps = {
            org_probe_step(),
            {
                name = 'show-default-target-org',
                base = { 'sf', 'config', 'get', 'target-org' },
                trail = { '--json' },
                needs_org = false,
                expect = 'Show the default target org other commands use.',
                flags = {
                    { flag = 'target-org', topic = 'config get' },
                    { flag = '--json', topic = 'config get' },
                },
            },
        },
    },
    ['apex-basics'] = {
        slug = 'apex-basics',
        title = 'Apex Basics & Database (sf CLI edition)',
        trailhead_url = 'https://trailhead.salesforce.com/content/learn/modules/apex_database',
        summary = 'Do the hands-on parts of the Trailhead "Apex Basics & Database" '
            .. 'module from the terminal: deploy the Teatime Apex class from the '
            .. 'salesforce practice repo and run an anonymous Apex script, the CLI '
            .. 'twin of the Developer Console "Execute Anonymous" window.',
        project_hint = 'Run from a Salesforce DX project checkout (for example '
            .. 'qompassai/salesforce trailhead/apex) so the relative paths below exist.',
        learn = {
            'sf project deploy start --source-dir <path> --json pushes one file or folder of metadata to the org; scoping to one file keeps the blast radius small.',
            'sf apex run --file <script> --json runs anonymous Apex, the CLI twin of the Developer Console Execute Anonymous window.',
            'Both commands take --target-org; without it they use the default from sf config.',
        },
        steps = {
            org_probe_step(),
            {
                name = 'deploy-Teatime-class',
                base = { 'sf', 'project', 'deploy', 'start', '--source-dir' },
                arg = 'force-app/main/default/classes/Teatime.cls',
                trail = { '--json' },
                needs_org = true,
                expect = 'Deploy the Teatime Apex practice class to the org.',
                flags = {
                    { flag = '--source-dir', topic = 'project deploy start' },
                    { flag = '--json', topic = 'project deploy start' },
                    { flag = '--target-org', topic = 'project deploy start' },
                },
            },
            {
                name = 'run-anonymous-apex',
                base = { 'sf', 'apex', 'run', '--file' },
                arg = 'scripts/apex/water_if_else.apex',
                trail = { '--json' },
                needs_org = true,
                expect = 'Run the anonymous Apex practice script (if/else logic).',
                flags = {
                    { flag = '--file', topic = 'apex run' },
                    { flag = '--json', topic = 'apex run' },
                    { flag = '--target-org', topic = 'apex run' },
                },
            },
        },
    },
    ['soql-for-admins'] = {
        slug = 'soql-for-admins',
        title = 'SOQL for Admins (sf CLI edition)',
        trailhead_url = 'https://trailhead.salesforce.com/content/learn/modules/soql-for-admins',
        summary = 'Do the hands-on parts of the Trailhead "SOQL for Admins" module '
            .. 'from the terminal: run a SOQL query against the org with '
            .. 'sf data query, and deploy the AccountUtility Apex class the '
            .. 'module asks you to build.',
        project_hint = 'Run from a Salesforce DX project checkout (for example '
            .. 'qompassai/salesforce trailhead/soql) so the relative paths below exist.',
        learn = {
            'sf data query --query "<SOQL>" --json runs SOQL from the terminal, the CLI twin of the Developer Console Query Editor.',
            'SOQL always needs SELECT and FROM; field names are API names, not labels.',
            'The AccountUtility class from the module deploys with sf project deploy start --source-dir.',
        },
        steps = {
            org_probe_step(),
            {
                name = 'query-recent-accounts',
                base = { 'sf', 'data', 'query', '--query' },
                arg = 'SELECT Name, AnnualRevenue FROM Account LIMIT 5',
                trail = { '--json' },
                needs_org = true,
                expect = 'List five accounts with their annual revenue.',
                flags = {
                    { flag = '--query', topic = 'data query' },
                    { flag = '--json', topic = 'data query' },
                    { flag = '--target-org', topic = 'data query' },
                },
            },
            {
                name = 'deploy-AccountUtility-class',
                base = { 'sf', 'project', 'deploy', 'start', '--source-dir' },
                arg = 'force-app/main/default/classes/AccountUtility.cls',
                trail = { '--json' },
                needs_org = true,
                expect = 'Deploy the AccountUtility Apex class from the module.',
                flags = {
                    { flag = '--source-dir', topic = 'project deploy start' },
                    { flag = '--json', topic = 'project deploy start' },
                    { flag = '--target-org', topic = 'project deploy start' },
                },
            },
        },
    },
}

---@class SfTasksState
---@field registry table<string, SfDispatchedJob> Jobs dispatched by this module, by job id.
---@field doc_root_override? string Test seam / user config for teach-doc output.
---@field subscribed boolean True once the trailhead event subscriber is installed.
local state = {
    registry = {},
    doc_root_override = nil,
    subscribed = false,
}

---@param slug any
---@return boolean
local function is_slug(slug)
    return type(slug) == 'string' and #slug > 0 and #slug <= SLUG_MAX_BYTES and slug:match(SLUG_PATTERN) ~= nil
end

---@param value any
---@return boolean
local function is_target_org(value)
    return type(value) == 'string'
        and #value > 0
        and #value <= TARGET_ORG_MAX_BYTES
        and value:match(TARGET_ORG_PATTERN) ~= nil
end

---@param slug string
---@return SfTaskModule?
local function get_module(slug)
    if not is_slug(slug) then
        return nil
    end
    return CATALOG[slug]
end

---Path of this file, so the default teach-doc root resolves to the
---diver repo's docs/salesforce/ no matter the Neovim cwd.
---@return string
local function module_file()
    local src = debug.getinfo(1, 'S').source
    if src:sub(1, 1) == '@' then
        src = src:sub(2)
    end
    return src
end

---diver repo root docs/salesforce/, four levels above this file.
---@return string
local function default_doc_root()
    local dir = fn.fnamemodify(module_file(), ':h')
    for _ = 1, 3 do
        dir = fn.fnamemodify(dir, ':h')
    end
    return dir .. '/docs/salesforce'
end

---@return string
local function doc_root()
    return state.doc_root_override or default_doc_root()
end

---Render argv as a shell command line for the teach-doc. Display only;
---execution always uses the argv table, never this string.
---@param argv string[]
---@return string
local function shell_quote(argv)
    local parts = {}
    for _, part in ipairs(argv) do
        if part:match('^[%w%-%._:/=+@,]+$') then
            parts[#parts + 1] = part
        else
            parts[#parts + 1] = "'" .. part:gsub("'", "'\"'\"'") .. "'"
        end
    end
    return table.concat(parts, ' ')
end

---@param mod SfTaskModule
---@param target_org? string
---@return SfTaskStep[]
local function build_steps(mod, target_org)
    local steps = {}
    for _, tmpl in ipairs(mod.steps) do
        local argv = {}
        for _, part in ipairs(tmpl.base) do
            argv[#argv + 1] = part
        end
        if tmpl.arg ~= nil then
            argv[#argv + 1] = tmpl.arg
        end
        for _, part in ipairs(tmpl.trail or {}) do
            argv[#argv + 1] = part
        end
        if tmpl.needs_org and target_org ~= nil then
            argv[#argv + 1] = '--target-org'
            argv[#argv + 1] = target_org
        end
        steps[#steps + 1] = {
            name = tmpl.name,
            argv = argv,
            expect = tmpl.expect,
            flags = tmpl.flags,
        }
    end
    return steps
end

---@param slug any
---@param opts any
---@return SfTaskModule? module
---@return string? target_org
---@return string? mode
---@return string? err
local function validate_dispatch(slug, opts)
    local mod = get_module(slug)
    if mod == nil then
        return nil, nil, nil, 'unknown task module: ' .. tostring(slug)
    end
    if opts == nil then
        opts = {}
    end
    if type(opts) ~= 'table' then
        return nil, nil, nil, 'opts must be a table'
    end
    local target_org = opts.target_org
    if target_org ~= nil and not is_target_org(target_org) then
        return nil, nil, nil, 'invalid target org alias'
    end
    local mode = opts.mode or 'live'
    if mode ~= 'live' and mode ~= 'hermetic' then
        return nil, nil, nil, 'mode must be "live" or "hermetic"'
    end
    return mod, target_org, mode, nil
end

---@param path string
---@return boolean
local function ensure_dir(path)
    if fn.isdirectory(path) == 1 then
        return true
    end
    return pcall(fn.mkdir, path, 'p')
end

---@param info SfDispatchedJob
---@param job table trailhead job snapshot.
---@return string[]
local function render_header(info, job)
    local org = info.target_org or 'default (from sf config target-org)'
    local mode_note = info.mode == 'hermetic' and 'hermetic dry-run (stubbed sf; NOT a live org)' or 'live'
    return {
        '# ' .. info.title,
        '',
        '> Async agent task teach-doc. Generated by `lua/dev/sf/tasks.lua`; do not edit by hand -- regenerate with `:SfTasksDoc '
            .. job.id
            .. '`.',
        '',
        '- **Module:** `' .. info.slug .. '`',
        '- **Trailhead:** ' .. info.trailhead_url,
        '- **Job:** `' .. job.id .. '`',
        '- **Run mode:** ' .. mode_note,
        '- **Target org:** ' .. org,
        '- **Dispatched:** ' .. info.dispatched_at,
        '- **Outcome:** ' .. job.status,
        '- **Flags verified against:** ' .. FLAGS_DOC,
        '',
        '## What this task does',
        '',
        info.summary,
        '',
        'Run it from: ' .. info.project_hint,
        '',
    }
end

---@param info SfDispatchedJob
---@return string[]
local function render_commands(info)
    local lines = { '## Exact commands run', '' }
    for i, step in ipairs(info.steps) do
        lines[#lines + 1] = i .. '. `' .. shell_quote(step.argv) .. '`'
        lines[#lines + 1] = '   ' .. step.expect
        local seen = {}
        for _, f in ipairs(step.flags) do
            if not seen[f.flag] then
                seen[f.flag] = true
                lines[#lines + 1] = '   Flag `' .. f.flag .. '` verified under `' .. f.topic .. '`.'
            end
        end
        lines[#lines + 1] = ''
    end
    return lines
end

---@param job table trailhead job snapshot.
---@return integer? index, table? step
local function failed_step(job)
    for i, step in ipairs(job.steps or {}) do
        if step.status == 'failed' then
            return i, step
        end
    end
    return nil, nil
end

---@param info SfDispatchedJob
---@param job table trailhead job snapshot.
---@return string[]
local function render_outcome(info, job)
    local lines = { '## What happened', '' }
    local done_count = 0
    for _, step in ipairs(job.steps or {}) do
        if step.status == 'done' then
            done_count = done_count + 1
        end
    end
    if job.status == 'done' then
        lines[#lines + 1] = 'All '
            .. #info.steps
            .. ' steps exited 0. Nothing was faked: every line below came from the real (or stubbed, in hermetic mode) `sf` process.'
    elseif job.status == 'cancelled' then
        lines[#lines + 1] = 'Cancelled by the user after '
            .. done_count
            .. ' of '
            .. #info.steps
            .. ' steps. Partial work stays visible in the log below.'
    else
        local idx, step = failed_step(job)
        if idx ~= nil and step ~= nil then
            lines[#lines + 1] = 'FAILED at step '
                .. idx
                .. ' (`'
                .. step.name
                .. '`, exit '
                .. tostring(step.exit_code)
                .. '). Later steps never ran.'
        else
            lines[#lines + 1] = 'FAILED. See the log tail below for what the CLI said.'
        end
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = '```text'
    local log = job.log or {}
    local from = math.max(1, #log - DOC_LOG_TAIL + 1)
    for i = from, #log do
        lines[#lines + 1] = log[i]
    end
    lines[#lines + 1] = '```'
    lines[#lines + 1] = ''
    return lines
end

---@param info SfDispatchedJob
---@param job table trailhead job snapshot.
---@return string[]
local function render_learn(info, job)
    local lines = { '## What I learned', '' }
    for _, bullet in ipairs(info.learn) do
        lines[#lines + 1] = '- ' .. bullet
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Outcome notes:'
    lines[#lines + 1] = ''
    if info.mode == 'hermetic' then
        lines[#lines + 1] =
            '- This doc came from a hermetic dry run (stubbed `sf` output). It proves the wiring, not a live org.'
    end
    if job.status == 'done' then
        lines[#lines + 1] = '- A green run means the CLI accepted every command against the target org.'
    elseif job.status == 'cancelled' then
        lines[#lines + 1] = '- Cancelled runs are honest partial runs: dispatch again to start over.'
    else
        lines[#lines + 1] =
            '- Do not retry blindly: read the log above, fix auth or the project path, then dispatch again.'
        lines[#lines + 1] =
            '- If the org probe step failed, no org is authorized; work through docs/salesforce/auth.md first.'
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = '## Auth you need before a live run'
    lines[#lines + 1] = ''
    lines[#lines + 1] =
        'See `docs/salesforce/auth.md`. In short: run `sf org login web --alias <alias> --set-default` yourself (interactive browser login), then verify with `:SfTasksDispatch org-auth`.'
    lines[#lines + 1] = ''
    return lines
end

---@param info SfDispatchedJob
---@param job table trailhead job snapshot.
---@return string
local function render_doc(info, job)
    local lines = {}
    local function append(part)
        for _, line in ipairs(part) do
            lines[#lines + 1] = line
        end
    end
    append(render_header(info, job))
    append(render_commands(info))
    append(render_outcome(info, job))
    append(render_learn(info, job))
    return table.concat(lines, '\n')
end

---@param path string
---@param text string
---@return string? path, string? err
local function write_file(path, text)
    local handle, open_err = io.open(path, 'w')
    if handle == nil then
        return nil, tostring(open_err)
    end
    handle:write(text)
    handle:close()
    return path, nil
end

---@param job_id string
---@return string? path, string? err
local function write_teach_doc(job_id)
    local info = state.registry[job_id]
    if info == nil then
        return nil, 'unknown agent task job: ' .. tostring(job_id)
    end
    if not is_slug(info.slug) then
        return nil, 'refusing unsafe doc slug'
    end
    local job = trailhead.get(job_id)
    if job == nil then
        return nil, 'trailhead job not found: ' .. tostring(job_id)
    end
    if not ensure_dir(doc_root()) then
        return nil, 'cannot create teach-doc directory: ' .. doc_root()
    end
    return write_file(doc_root() .. '/' .. info.slug .. '.md', render_doc(info, job))
end

---Trailhead event subscriber: when one of OUR jobs reaches a terminal
---state, write its teach-doc. Other jobs are ignored. (Event job ids
---arrive as `ev.job_id`; see lua/dev/sf/trailhead.lua emit calls.)
---@param ev table
local function on_trailhead_event(ev)
    if type(ev) ~= 'table' or ev.type ~= 'job' then
        return
    end
    local job_id = ev.job_id
    local info = state.registry[job_id]
    if info == nil then
        return
    end
    if ev.status ~= 'done' and ev.status ~= 'failed' and ev.status ~= 'cancelled' then
        return
    end
    local _, err = write_teach_doc(job_id)
    if err ~= nil then
        core.notify('teach-doc failed for ' .. tostring(job_id) .. ': ' .. err, vim.log.levels.WARN)
    end
end

local M = {}

---Install the trailhead event subscriber (idempotent). Called
---automatically on first dispatch; also safe to call from setup code.
function M.setup()
    if state.subscribed then
        return
    end
    trailhead.on_event(on_trailhead_event)
    state.subscribed = true
end

---Override where teach-docs are written (tests and user config).
---@param path string
function M.set_doc_root(path)
    assert(type(path) == 'string' and #path > 0, 'doc root must be a non-empty string')
    state.doc_root_override = path
end

---@return string[] slugs, sorted.
function M.list_modules()
    local slugs = {}
    for slug, _ in pairs(CATALOG) do
        slugs[#slugs + 1] = slug
    end
    table.sort(slugs)
    return slugs
end

---@param slug string
---@return SfTaskModule?
function M.get_module(slug)
    return get_module(slug)
end

---Dispatch an async agent task: validate the module and options, check
---for the `sf` CLI, enqueue the verified steps on the trailhead job
---queue, and start the job. Nonblocking; cancel with `:SfTasksStatus`
---(shows the job id) then `trailhead.cancel`, or M.cancel(id).
---@param slug string Catalog key, e.g. 'apex-basics'.
---@param opts? SfTaskDispatchOpts
---@return string? job_id, string? err
function M.dispatch(slug, opts)
    local mod, target_org, mode, err = validate_dispatch(slug, opts)
    if err ~= nil then
        return nil, err
    end
    M.setup()
    if not core.ensure_sf() then
        return nil, 'sf CLI not found in PATH; install it, then dispatch again'
    end
    local steps = build_steps(mod, target_org)
    local id = trailhead.enqueue({
        kind = 'shell',
        title = mod.title .. ' [' .. mod.slug .. ']',
        note = 'async agent task; teach-doc -> docs/salesforce/' .. mod.slug .. '.md',
    })
    if id == nil then
        return nil, 'could not create trailhead job'
    end
    for _, step in ipairs(steps) do
        trailhead.add_step(id, { name = step.name, argv = step.argv })
    end
    -- Register BEFORE start: a fast job can finish inside start() (the
    -- stubbed tests complete synchronously), and the teach-doc
    -- subscriber must see the entry when the terminal event fires.
    state.registry[id] = {
        slug = mod.slug,
        target_org = target_org,
        mode = mode,
        title = mod.title,
        trailhead_url = mod.trailhead_url,
        summary = mod.summary,
        project_hint = mod.project_hint,
        learn = mod.learn,
        steps = steps,
        dispatched_at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    trailhead.start(id)
    core.notify('agent task dispatched: ' .. mod.slug .. ' (' .. id .. ')', vim.log.levels.INFO)
    return id, nil
end

---Cancel a dispatched task. Delegates to the trailhead queue, which
---kills the running `sf` process (SIGTERM) and marks later steps
---cancelled. The teach-doc still records the partial run.
---@param id string trailhead job id.
---@return boolean ok, string? err
function M.cancel(id)
    return trailhead.cancel(id)
end

---Snapshot of a dispatched task's job (steps, log, status).
---@param id string trailhead job id.
---@return table?
function M.job(id)
    return trailhead.get(id)
end

---(Re)generate the teach-doc for a finished task job.
---@param job_id string
---@return string? path, string? err
function M.doc_for(job_id)
    local info = state.registry[job_id]
    if info == nil then
        return nil, 'unknown agent task job: ' .. tostring(job_id)
    end
    local job = trailhead.get(job_id)
    if job == nil then
        return nil, 'trailhead job not found: ' .. tostring(job_id)
    end
    if job.status ~= 'done' and job.status ~= 'failed' and job.status ~= 'cancelled' then
        return nil, 'job ' .. tostring(job_id) .. ' is not finished (status: ' .. job.status .. ')'
    end
    return write_teach_doc(job_id)
end

---@param _ any unused buffer number.
local function list_modules_buffer(_)
    local lines = {
        'Async Salesforce agent tasks (`:SfTasksDispatch <module> [target-org]`):',
        '',
    }
    for _, slug in ipairs(M.list_modules()) do
        local mod = CATALOG[slug]
        lines[#lines + 1] = '  ' .. slug .. ' -- ' .. mod.title
        lines[#lines + 1] = '    ' .. mod.summary
        lines[#lines + 1] = ''
    end
    core.open_scratch('sf-tasks-modules', lines)
end

M.commands = {
    {
        name = 'SfTasksModules',
        rhs = list_modules_buffer,
        opts = { nargs = 0, desc = 'List async Salesforce agent task modules' },
    },
    {
        name = 'SfTasksDispatch',
        rhs = function(cmd_opts)
            local args = core.get_args(cmd_opts)
            local id, err = M.dispatch(args[1], { target_org = args[2] })
            if id == nil then
                core.notify('dispatch failed: ' .. tostring(err), vim.log.levels.ERROR)
            end
        end,
        opts = { nargs = '+', desc = 'Dispatch async agent task: SfTasksDispatch <module> [target-org]' },
    },
    {
        name = 'SfTasksDoc',
        rhs = function(cmd_opts)
            local args = core.get_args(cmd_opts)
            local path, err = M.doc_for(args[1])
            if path ~= nil then
                core.open_scratch('teach-doc: ' .. path, { path })
            else
                core.notify('doc failed: ' .. tostring(err), vim.log.levels.ERROR)
            end
        end,
        opts = { nargs = 1, desc = 'Regenerate teach-doc for a finished agent task job' },
    },
    {
        name = 'SfTasksStatus',
        rhs = function(cmd_opts)
            local args = core.get_args(cmd_opts)
            trailhead.status({ args = args[1] or '' })
        end,
        opts = { nargs = '?', desc = 'Show agent task job status' },
    },
}

return M
