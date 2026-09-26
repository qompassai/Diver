-- /qompassai/diver/lua/ai/debugbridge/scanbreak.lua
-- Qompass AI Debug Bridge: scan-gate + stop-hook (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------------------
-- Two halves of one tripwire.
--
--   gate(files, opts): BEFORE launch, every artifact is scanned with
--     ai.security. High-severity findings are converted from byte
--     offsets to 1-based lines and armed as DAP breakpoints, so the
--     debugger itself stops the moment execution reaches them.
--     ai.security must load; otherwise the gate refuses (fail closed).
--     Medium/low findings never arm breakpoints; they are logged only.
--
--   install_stop_hook(session_key, flagged, ctx): AFTER launch, a dap
--     after.event_stopped listener watches for stops at flagged lines.
--     On a hit the order is fixed: (1) the injected sessions module
--     kills the debuggee process tree BY SESSION KEY, (2) the artifact
--     file is quarantined, (3) the hit is logged and notified.
--     Stops at unflagged lines are ignored silently.
--
-- LIMITS (read before relying on this module)
--   * The stop location is read from session.current_frame as left by
--     Session:event_stopped, guarded by a stopped_thread_id match.
--     If the handler returned early (adapter resumed mid-handling,
--     stackTrace error, empty frames), the frame may be stale from a
--     previous stop; the guard catches thread switches but NOT a
--     same-thread stale frame. A stop that cannot be mapped at all is
--     treated as SUSPECT while flagged lines exist (fail closed) and
--     the reason is logged -- deliberate, see resolve_stop_location.
--   * There is no process-quarantine primitive in ai.security: the
--     flow kills the process tree first, then quarantines the file.
--     A live process could otherwise rewrite the artifact mid-move.
--   * The artifact path comes from session.config.program. Sessions
--     whose config carries no program path skip quarantine with a log
--     entry; the kill still happens.
--   * Sibling modules (ai.debugbridge.sessions, ai.debugbridge.log)
--     are never required at load: the sessions module arrives via the
--     injected ctx (no require cycles), and the log module is only
--     pcall-required lazily as a fallback.

local M = {}

-- Named bounds.
local FILE_COUNT_MAX = 32 -- max files per gate() call
local FILE_BYTES_MAX = 1048576 -- max bytes per file (1 MiB)
local FINDINGS_PER_FILE_MAX = 4096 -- max findings iterated per file
local LINES_PER_FILE_MAX = 1024 -- max flagged lines armed per file
local HOOK_PATHS_MAX = 32 -- max flagged paths per installed hook

--- Lines scanbreak armed as security breakpoints in this Neovim
--- session: path -> set of 1-based lines. The UI reads this because
--- DAP breakpoint objects carry no security marker, and stamping one
--- via logMessage/condition would change breakpoint behavior
--- (logpoints don't stop). Manual breakpoint removal does not clear
--- entries; use M.clear_flagged() to reset.
---@type table<string, table<integer, boolean>>
local flagged_registry = {}

---@class ScanbreakFinding
---@field severity 'low'|'medium'|'high'
---@field code string
---@field detail string
---@field offset integer? 1-based byte offset into the file, when known

---@class ScanbreakFlaggedFile
---@field lines integer[] 1-based flagged lines, sorted, unique
---@field findings ScanbreakFinding[] high-severity findings for the file

---@class ScanbreakGateResult
---@field verdict 'clean'|'suspicious'|'malicious' worst verdict seen
---@field flagged table<string, ScanbreakFlaggedFile> files with high findings

---@class ScanbreakGateOpts
---@field project_root string Absolute root; every file must sit under it

---@class ScanbreakSessionsModule Injected; matches ai.debugbridge.sessions
---@field kill fun(key: string): boolean?, string? Kill adapter+debuggee now

---@class ScanbreakHookCtx
---@field sessions_module ScanbreakSessionsModule Injected; never required at load
---@field log_append? fun(kind: string, detail: table)
---@field quarantine_fn? fun(path: string): string?, string?
---@field notify_fn? fun(message: string, level: integer)

--- Map a 1-based byte offset to a 1-based line number by counting the
--- newlines strictly before the offset. Out-of-range offsets clamp to
--- the nearest valid position, so an offset at/past EOF lands on the
--- final line. Bounded by #text: every step consumes at least one
--- byte. Pure: string ops only, no vim dependency.
---@param text string
---@param offset integer 1-based byte offset
---@return integer line 1-based line number
function M.offset_to_line(text, offset)
    assert(type(text) == 'string', 'offset_to_line: text must be a string')
    assert(type(offset) == 'number', 'offset_to_line: offset must be a number')
    local clamped = offset
    if clamped < 1 then
        clamped = 1
    elseif clamped > #text + 1 then
        clamped = #text + 1
    end
    local line = 1
    local start = 1
    while start <= #text do
        local newline = text:find('\n', start, true)
        if newline == nil or newline >= clamped then
            break
        end
        line = line + 1
        start = newline + 1
    end
    return line
end

--- Best-effort stop-event -> file:line mapping.
---
--- The dap after.event_stopped listeners run after Session:event_stopped
--- has synchronously fetched the stack trace and stored the top frame in
--- session.current_frame (the stackTrace request runs inside
--- dap.async.run's coroutine, so it completes before the after listeners
--- fire). The match is guarded by stopped_thread_id: when the handler
--- auto-continued a different thread or returned early, the frame is not
--- from this event and the location is unmappable.
---@param session table The dap session passed to the listener
---@param body table? The stopped event body ({ threadId = ... })
---@return table? location { path: string, line: integer }
---@return string? err Reason the location could not be mapped
function M.resolve_stop_location(session, body)
    assert(type(session) == 'table', 'resolve_stop_location: session must be a table')
    local thread_id = nil
    if type(body) == 'table' then
        thread_id = body.threadId
    end
    local frame = session.current_frame
    if type(frame) ~= 'table' then
        return nil, 'session has no current frame'
    end
    local stopped_id = session.stopped_thread_id
    if thread_id ~= nil and stopped_id ~= nil and stopped_id ~= thread_id then
        return nil, 'stale frame: stopped thread mismatch'
    end
    local source = frame.source
    local path = type(source) == 'table' and source.path or nil
    local line = frame.line
    if type(path) ~= 'string' or path == '' then
        return nil, 'frame source has no path'
    end
    if type(line) ~= 'number' or line < 1 or line ~= math.floor(line) then
        return nil, 'frame has no valid line'
    end
    return { path = path, line = line }, nil
end

---@param root string
---@return string? normalized Absolute root without trailing slashes, or nil
local function normalize_root(root)
    if type(root) ~= 'string' or root == '' then
        return nil
    end
    if root:sub(1, 1) ~= '/' then
        return nil
    end
    local stripped = root:gsub('/+$', '')
    if stripped == '' then
        return '/'
    end
    return stripped
end

---@param path string
---@param root string Normalized absolute root
---@return boolean ok
---@return string? err
local function check_gate_path(path, root)
    if type(path) ~= 'string' or path == '' then
        return false, 'file path must be a non-empty string'
    end
    if path:sub(1, 1) ~= '/' then
        return false, 'file path must be absolute: ' .. path
    end
    for component in path:gmatch('[^/]+') do
        if component == '..' then
            return false, 'file path must not contain "..": ' .. path
        end
    end
    if root ~= '/' and path ~= root and path:sub(1, #root + 1) ~= root .. '/' then
        return false, 'file path is outside project_root: ' .. path
    end
    -- Resolve symlinks before the gate scans: a symlink inside the
    -- root pointing outside would otherwise pass the lexical check
    -- and let the gate scan (and the debugger launch) a file the
    -- project_root was supposed to exclude.
    local real_path = vim.uv.fs_realpath(path)
    if real_path == nil then
        return false, 'file path does not resolve: ' .. path
    end
    local real_root = vim.uv.fs_realpath(root)
    if real_root == nil then
        return false, 'project_root does not resolve: ' .. root
    end
    if real_root ~= '/' and real_path ~= real_root and real_path:sub(1, #real_root + 1) ~= real_root .. '/' then
        return false, 'file path resolves outside project_root: ' .. path
    end
    return true, nil
end

---@param path string
---@return boolean ok
---@return string? err
local function check_stat(path)
    local uv = vim.uv
    if uv == nil then
        return false, 'vim.uv unavailable'
    end
    local stat = uv.fs_stat(path)
    if stat == nil then
        return false, 'cannot stat file: ' .. path
    end
    if stat.type ~= 'file' then
        return false, 'not a regular file: ' .. path
    end
    if stat.size > FILE_BYTES_MAX then
        return false, 'file exceeds ' .. tostring(FILE_BYTES_MAX) .. ' bytes: ' .. path
    end
    return true, nil
end

---@param path string Already size-checked; the cap read detects TOCTOU growth
---@return string? text
---@return string? err
local function read_bounded(path)
    local handle = io.open(path, 'rb')
    if handle == nil then
        return nil, 'cannot open file: ' .. path
    end
    local data = handle:read(FILE_BYTES_MAX + 1)
    handle:close()
    if data == nil then
        return nil, 'cannot read file: ' .. path
    end
    if #data > FILE_BYTES_MAX then
        return nil, 'file grew past the size cap during read: ' .. path
    end
    return data, nil
end

--- Load ai.security, refusing to proceed when it is absent or broken.
--- A gate that cannot scan must not launch anything unscanned.
---@return table? security
---@return string? err
local function load_security()
    local ok, security = pcall(require, 'ai.security')
    if not ok or type(security) ~= 'table' or type(security.scan_file) ~= 'function' then
        return nil, 'security module unavailable: refusing to launch unscanned'
    end
    return security, nil
end

---@param ctx ScanbreakHookCtx?
---@param kind string
---@param detail table
local function log_via(ctx, kind, detail)
    assert(type(kind) == 'string', 'log kind must be a string')
    assert(type(detail) == 'table', 'log detail must be a table')
    if ctx ~= nil and type(ctx.log_append) == 'function' then
        pcall(ctx.log_append, kind, detail)
        return
    end
    local ok, logmod = pcall(require, 'ai.debugbridge.log')
    if ok and type(logmod) == 'table' and type(logmod.append) == 'function' then
        pcall(logmod.append, kind, detail)
    end
end

---@param ctx ScanbreakHookCtx?
---@param message string
---@param level integer
local function notify_via(ctx, message, level)
    assert(type(message) == 'string', 'notify message must be a string')
    assert(type(level) == 'number', 'notify level must be a number')
    if ctx ~= nil and type(ctx.notify_fn) == 'function' then
        pcall(ctx.notify_fn, message, level)
        return
    end
    pcall(vim.notify, message, level)
end

---@param session table
---@return string? path The debuggee program path, or nil when unknown
local function artifact_path_of(session)
    if type(session) ~= 'table' then
        return nil
    end
    local config = session.config
    if type(config) ~= 'table' then
        return nil
    end
    local program = config.program
    if type(program) ~= 'string' or program == '' then
        return nil
    end
    return program
end

---@param findings table[]
---@return string codes Sorted, comma-joined finding codes
local function codes_of(findings)
    assert(type(findings) == 'table', 'findings must be a table')
    local codes = {}
    for index, finding in ipairs(findings) do
        if index > FINDINGS_PER_FILE_MAX then
            break
        end
        if type(finding) == 'table' and type(finding.code) == 'string' then
            codes[#codes + 1] = finding.code
        end
    end
    table.sort(codes)
    return table.concat(codes, ',')
end

---@param breakpoints table dap.breakpoints module
---@param path string
---@param line integer 1-based
---@return boolean ok
---@return string? err
local function arm_breakpoint(breakpoints, path, line)
    assert(type(breakpoints) == 'table', 'breakpoints module must be a table')
    assert(type(path) == 'string', 'path must be a string')
    assert(type(line) == 'number' and line >= 1, 'line must be a positive number')
    local ok, bufnr = pcall(vim.fn.bufadd, path)
    if not ok or type(bufnr) ~= 'number' then
        return false, 'bufadd failed for ' .. path .. ': ' .. tostring(bufnr)
    end
    local loaded, load_err = pcall(vim.fn.bufload, bufnr)
    if not loaded then
        return false, 'bufload failed for ' .. path .. ': ' .. tostring(load_err)
    end
    local set_ok, set_err = pcall(breakpoints.set, {}, bufnr, line)
    if not set_ok then
        local where = path .. ':' .. tostring(line)
        return false, 'breakpoints.set failed for ' .. where .. ': ' .. tostring(set_err)
    end
    return true, nil
end

---@param current 'clean'|'suspicious'|'malicious'
---@param incoming 'clean'|'suspicious'|'malicious'
---@return 'clean'|'suspicious'|'malicious'
local function worse_verdict(current, incoming)
    local rank = { clean = 1, suspicious = 2, malicious = 3 }
    if rank[incoming] > rank[current] then
        return incoming
    end
    return current
end

--- Scan one file and arm breakpoints on its high-severity findings.
--- Findings without a byte offset cannot be mapped to a line: they
--- stay in findings but arm nothing (no guessing).
---@param security table ai.security module
---@param breakpoints table dap.breakpoints module
---@param path string Validated absolute path
---@return ScanbreakFlaggedFile? flagged
---@return 'clean'|'suspicious'|'malicious'? verdict
---@return string? err
local function scan_and_arm(security, breakpoints, path)
    local report, scan_err = security.scan_file(path)
    if report == nil then
        return nil, nil, 'scan failed for ' .. path .. ': ' .. tostring(scan_err)
    end
    local raw_verdict = report.verdict
    if raw_verdict ~= 'clean' and raw_verdict ~= 'suspicious' and raw_verdict ~= 'malicious' then
        return nil, nil, 'scan returned an unknown verdict for ' .. path
    end
    ---@type 'clean'|'suspicious'|'malicious'
    local verdict = raw_verdict
    local high = {}
    local findings = type(report.findings) == 'table' and report.findings or {}
    for index, finding in ipairs(findings) do
        if index > FINDINGS_PER_FILE_MAX then
            break
        end
        if type(finding) == 'table' and finding.severity == 'high' then
            high[#high + 1] = finding
        end
    end
    ---@type ScanbreakFlaggedFile
    local flagged = { lines = {}, findings = high }
    if #high == 0 then
        return flagged, verdict, nil
    end
    -- Byte offsets only make sense against the file bytes: read the
    -- file once (bounded; the stat cap was already enforced) so every
    -- offset maps to the same content the scanner saw.
    local text, read_err = read_bounded(path)
    if text == nil then
        return nil, nil, read_err
    end
    local line_set = {}
    for _, finding in ipairs(high) do
        if type(finding.offset) == 'number' then
            line_set[M.offset_to_line(text, finding.offset)] = true
        end
    end
    local lines = {}
    for line in pairs(line_set) do
        lines[#lines + 1] = line
    end
    table.sort(lines)
    if #lines > LINES_PER_FILE_MAX then
        return nil, nil, 'too many flagged lines in ' .. path
    end
    for _, line in ipairs(lines) do
        local ok, err = arm_breakpoint(breakpoints, path, line)
        if not ok then
            -- A gate that reports "armed" while the breakpoint is
            -- missing would lie about the runtime backstop: fail.
            return nil, nil, err
        end
    end
    -- All lines armed: record them for the UI. Per-path overwrite, so
    -- re-gating a file refreshes its entry.
    local armed_set = flagged_registry[path]
    if armed_set == nil then
        armed_set = {}
        flagged_registry[path] = armed_set
    end
    for _, line in ipairs(lines) do
        armed_set[line] = true
    end
    flagged.lines = lines
    return flagged, verdict, nil
end

--- Scan files before launch and arm breakpoints on high-severity
--- findings. Every path must be absolute, free of ".." components,
--- and under opts.project_root; every file is size-capped via
--- vim.uv.fs_stat before reading. ai.security must load or the gate
--- refuses (fail closed). Returns the flagged map plus the worst
--- verdict across files. Medium/low findings arm nothing.
---@param files string[] Absolute file paths
---@param opts ScanbreakGateOpts
---@return ScanbreakGateResult? result
---@return string? err
function M.gate(files, opts)
    assert(type(files) == 'table', 'gate: files must be a table')
    assert(type(opts) == 'table', 'gate: opts must be a table')
    local root = normalize_root(opts.project_root)
    if root == nil then
        return nil, 'opts.project_root must be an absolute path'
    end
    if #files > FILE_COUNT_MAX then
        return nil, 'too many files: max ' .. tostring(FILE_COUNT_MAX)
    end
    local security, sec_err = load_security()
    if security == nil then
        return nil, sec_err
    end
    local bp_ok, breakpoints = pcall(require, 'dap.breakpoints')
    if not bp_ok or type(breakpoints) ~= 'table' or type(breakpoints.set) ~= 'function' then
        return nil, 'dap.breakpoints unavailable: cannot arm scan breakpoints'
    end
    ---@type ScanbreakGateResult
    local result = { verdict = 'clean', flagged = {} }
    local seen = {}
    local scanned_count = 0
    local flagged_count = 0
    for _, path in ipairs(files) do
        if not seen[path] then
            seen[path] = true
            local ok, err = check_gate_path(path, root)
            if not ok then
                return nil, err
            end
            ok, err = check_stat(path)
            if not ok then
                return nil, err
            end
            local flagged, verdict, scan_err = scan_and_arm(security, breakpoints, path)
            if flagged == nil then
                return nil, scan_err
            end
            scanned_count = scanned_count + 1
            if #flagged.findings > 0 then
                result.flagged[path] = flagged
                flagged_count = flagged_count + 1
            end
            result.verdict = worse_verdict(result.verdict, verdict)
            log_via(nil, 'scan_findings', {
                path = path,
                verdict = verdict,
                high = #flagged.findings,
                lines = flagged.lines,
            })
        end
    end
    log_via(nil, 'scan_gate', {
        files = scanned_count,
        verdict = result.verdict,
        flagged_files = flagged_count,
    })
    return result, nil
end

--- Snapshot of lines scanbreak armed as security breakpoints in this
--- Neovim session: { [abspath] = { lines = { sorted unique lines } } }.
--- Read by the UI; see the flagged_registry comment for why the DAP
--- objects themselves carry no marker.
---@return table<string, { lines: integer[] }>
function M.flagged_breakpoints()
    local out = {}
    for path, set in pairs(flagged_registry) do
        local lines = {}
        for line in pairs(set) do
            lines[#lines + 1] = line
        end
        table.sort(lines)
        out[path] = { lines = lines }
    end
    return out
end

--- Forget all registry entries. Does not remove DAP breakpoints.
---@return nil
function M.clear_flagged()
    flagged_registry = {}
end

--- Carry out the stop-hook hit sequence. The kill comes FIRST: the
--- process tree must be dead before quarantine or logging touches
--- the artifact, or a live process could rewrite it mid-move.
---@param session_key string Key passed to install_stop_hook
---@param session table The dap session from the stop event
---@param path string? Flagged file, nil when the stop was unmappable
---@param line integer? Flagged line, nil when the stop was unmappable
---@param codes string Comma-joined finding codes, or 'unknown'
---@param reason string? Why an unmapped stop was treated as suspect
---@param ctx ScanbreakHookCtx
local function engage(session_key, session, path, line, codes, reason, ctx)
    local kill_ok = false
    local kill_err = 'sessions_module.kill unavailable'
    local sm = ctx.sessions_module
    if type(sm) == 'table' and type(sm.kill) == 'function' then
        local ok, killed, err = pcall(sm.kill, session_key)
        if ok and killed then
            kill_ok = true
            kill_err = ''
        elseif ok then
            kill_err = tostring(err or 'kill returned false')
        else
            kill_err = tostring(killed)
        end
    end
    local artifact = artifact_path_of(session)
    local quarantine_detail
    if artifact ~= nil and type(ctx.quarantine_fn) == 'function' then
        local ok, dest, qerr = pcall(ctx.quarantine_fn, artifact)
        if ok and dest ~= nil then
            quarantine_detail = 'quarantined ' .. artifact .. ' -> ' .. tostring(dest)
        else
            local why = ok and tostring(qerr) or tostring(dest)
            quarantine_detail = 'quarantine FAILED for ' .. artifact .. ': ' .. why
        end
    elseif artifact == nil then
        quarantine_detail = 'no artifact quarantined: session has no program path'
    else
        quarantine_detail = 'no artifact quarantined: ctx.quarantine_fn missing'
    end
    local where = path ~= nil and (path .. ':' .. tostring(line)) or 'unmapped location'
    local detail = {
        where = where,
        codes = codes,
        reason = reason or '',
        killed = kill_ok,
        kill_error = kill_err,
        quarantine = quarantine_detail,
    }
    log_via(ctx, 'stop_hook_hit', detail)
    log_via(ctx, 'quarantine', { path = artifact or '', detail = quarantine_detail })
    local message = 'ai.debugbridge: stop at ' .. where .. ' codes=[' .. codes .. ']'
    if reason ~= nil then
        message = message .. ' ' .. reason
    end
    if kill_ok then
        message = message .. '; debuggee killed; ' .. quarantine_detail
    else
        message = message .. '; KILL FAILED: ' .. kill_err .. '; ' .. quarantine_detail
    end
    local level = kill_ok and vim.log.levels.WARN or vim.log.levels.ERROR
    notify_via(ctx, message, level)
end

--- dap after.event_stopped listener body. Non-flagged stops are
--- ignored silently. Unmappable stops are treated as suspect while
--- flagged lines exist (fail closed; see resolve_stop_location).
---@param session table
---@param body table?
---@param line_sets table<string, table<integer, boolean>>
---@param codes_by_path table<string, string>
---@param any_flagged boolean
---@param session_key string
---@param ctx ScanbreakHookCtx
local function on_stopped(session, body, line_sets, codes_by_path, any_flagged, session_key, ctx)
    assert(type(session) == 'table', 'stop hook: session must be a table')
    local location, loc_err = M.resolve_stop_location(session, body)
    local hit_path = nil
    local hit_line = nil
    local codes ---@type string
    local reason = nil
    if location ~= nil then
        local set = line_sets[location.path]
        if set == nil or not set[location.line] then
            return
        end
        hit_path = location.path
        hit_line = location.line
        codes = codes_by_path[location.path] or ''
    else
        if not any_flagged then
            return
        end
        reason = 'unmappable stop treated as suspect (' .. tostring(loc_err) .. ')'
        codes = 'unknown'
    end
    engage(session_key, session, hit_path, hit_line, codes, reason, ctx)
    -- No return value: call_listener in session.lua unregisters any
    -- listener that returns truthy, and this hook must persist.
end

--- Install the stop hook for one debug session. The sessions module is
--- injected via ctx (never required here, to avoid cycles); it must
--- expose kill(key). The flagged map is the one M.gate returned.
---
--- Listener-table resolution: the live after.event_stopped table is on
--- the nvim-dap core module 'dap.dap'; require('dap') is this repo's
--- front end and exposes no listeners. 'dap' is tried first so test
--- stubs on that name keep working; the real core is the fallback.
---@return table? stopped The after.event_stopped listener table
---@return string? err
local function resolve_stopped_listeners()
    local candidates = { 'dap', 'dap.dap' }
    for _, name in ipairs(candidates) do
        local ok, mod = pcall(require, name)
        if ok and type(mod) == 'table' then
            local listeners = mod.listeners
            local after = type(listeners) == 'table' and listeners.after or nil
            local stopped = type(after) == 'table' and after.event_stopped or nil
            if type(stopped) == 'table' then
                return stopped, nil
            end
        end
    end
    return nil, 'no usable dap listeners.after.event_stopped table found'
end

---@param session_key string Non-empty; listener key is 'ai_debugbridge_' .. it
---@param flagged table<string, ScanbreakFlaggedFile>
---@param ctx ScanbreakHookCtx
---@return boolean? ok
---@return string? err
function M.install_stop_hook(session_key, flagged, ctx)
    assert(type(session_key) == 'string', 'install_stop_hook: session_key must be a string')
    assert(type(flagged) == 'table', 'install_stop_hook: flagged must be a table')
    assert(type(ctx) == 'table', 'install_stop_hook: ctx must be a table')
    if session_key == '' then
        return nil, 'session_key must not be empty'
    end
    local sm = ctx.sessions_module
    if type(sm) ~= 'table' or type(sm.kill) ~= 'function' then
        return nil, 'ctx.sessions_module.kill is required'
    end
    -- Build the per-path line sets up front so the listener itself
    -- stays allocation-light on the hot stop path.
    local line_sets = {}
    local codes_by_path = {}
    local any_flagged = false
    local path_count = 0
    for path, entry in pairs(flagged) do
        path_count = path_count + 1
        if path_count > HOOK_PATHS_MAX then
            return nil, 'too many flagged paths: max ' .. tostring(HOOK_PATHS_MAX)
        end
        if type(path) ~= 'string' or type(entry) ~= 'table' or type(entry.lines) ~= 'table' then
            return nil, 'flagged entry is malformed'
        end
        if #entry.lines > LINES_PER_FILE_MAX then
            return nil, 'too many flagged lines for ' .. tostring(path)
        end
        local set = {}
        for _, line in ipairs(entry.lines) do
            if type(line) == 'number' and line >= 1 and line == math.floor(line) then
                set[line] = true
                any_flagged = true
            end
        end
        line_sets[path] = set
        codes_by_path[path] = codes_of(type(entry.findings) == 'table' and entry.findings or {})
    end
    local stopped, resolve_err = resolve_stopped_listeners()
    if stopped == nil then
        return nil, resolve_err
    end
    local key = 'ai_debugbridge_' .. session_key
    stopped[key] = function(session, body)
        on_stopped(session, body, line_sets, codes_by_path, any_flagged, session_key, ctx)
    end
    log_via(ctx, 'scan_gate', { event = 'stop_hook_installed', key = key })
    return true, nil
end

--- Remove a previously installed stop hook. Idempotent: an unknown
--- key, a missing dap module, or missing listener tables all succeed.
---@param session_key string
---@return boolean ok Always true
function M.remove_stop_hook(session_key)
    assert(type(session_key) == 'string', 'remove_stop_hook: session_key must be a string')
    local key = 'ai_debugbridge_' .. session_key
    local stopped = resolve_stopped_listeners()
    if stopped ~= nil then
        stopped[key] = nil
    end
    return true
end

return M
