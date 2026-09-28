-- #################################################################
-- /qompassai/diver/lua/dev/cargo.lua
-- Qompass AI Diver Cargo Task Runner
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
--- Cargo task runner: mirrors the [alias] section of
--- ~/.config/cargo/config.toml as :Cargo subcommands with completion,
--- runs them in a floating terminal (argv form only -- never a shell
--- string), and parses rustc diagnostics into the quickfix list.
---
--- Requiring this module performs no I/O and registers nothing.
--- M.setup() registers the :Cargo* commands and is idempotent.
--- M.run() is the spawn seam: module 10 (notify) wraps it later.

---@module 'dev.cargo'

local api = vim.api
local fn = vim.fn

local M = {}

local rce = require('security.rce')
local toolmgr = require('utils.toolmgr')

local OUTPUT_LINES_MAX = 4000 -- output lines parsed into the quickfix list.
local TEXT_BYTES_MAX = 1048576 -- 1 MiB cap on text handed to the parser.
local JOB_ID_INVALID = 0 -- termopen returns 0 when the spawn fails.

local MIGRATIONS_TEMPLATE_NOTE = '[template] no upstream cargo config rename known; shape only, no-op'

---@type utils.toolmgr.Migration[]
local MIGRATIONS = {
    {
        version = '1.98.0',
        description = MIGRATIONS_TEMPLATE_NOTE,
        apply = function()
            return true, 'template migration: no changes applied'
        end,
    },
}

--- Matt's cargo aliases, verbatim from the [alias] section of
--- ~/.config/cargo/config.toml. `cargo` itself expands any other alias
--- the user types, so :Cargo passes unknown subcommands through and they
--- still resolve against his config.
---@type table<string, string[]>
M.aliases = {
    b = { 'build' },
    c = { 'check' },
    r = { 'run' },
    rr = { 'run', '--release' },
    t = { 'test' },
    ['zig-aarch64-r'] = { 'zigbuild', '--release', '--target', 'aarch64-unknown-linux-gnu' },
    ['zig-aarch64-t'] = { 'zigbuild', 'test', '--target', 'aarch64-unknown-linux-gnu' },
    ['zig-x86_64-r'] = { 'zigbuild', '--release', '--target', 'x86_64-unknown-linux-gnu' },
}

--- Common cargo subcommands offered as completion hints. Anything the
--- user types is passed to cargo verbatim, so this list is UX only and
--- never gates what :Cargo accepts.
---@type string[]
local COMMON_SUBCOMMANDS = {
    'add',
    'bench',
    'build',
    'check',
    'clean',
    'clippy',
    'doc',
    'fix',
    'fmt',
    'help',
    'init',
    'install',
    'login',
    'logout',
    'metadata',
    'new',
    'owner',
    'package',
    'publish',
    'remove',
    'run',
    'rustc',
    'rustdoc',
    'search',
    'test',
    'tree',
    'uninstall',
    'update',
    'vendor',
    'version',
    'yank',
}

--- Factory defaults: explicit, alphabetical, one-line comment per key.
--- Never mutated; M.config is rebuilt from this on every setup().
M.default_config = {
    -- Completion display order for the M.aliases above.
    alias_order = { 'b', 'c', 'r', 'rr', 't', 'zig-x86_64-r', 'zig-aarch64-r', 'zig-aarch64-t' },
    -- Cargo binary name on PATH.
    cargo_bin = 'cargo',
    -- Minimum supported cargo: edition-2024 era floor (edition 2024
    -- stabilized in Rust 1.85).
    cargo_version_min = '1.85.0',
    -- Canonical Cargo Book URL (verified 2026-09-27).
    docs_url = 'https://doc.rust-lang.org/cargo/',
    -- Rows of the floating :Cargo terminal window.
    float_height = 24,
    -- Cols of the floating :Cargo terminal window.
    float_width = 100,
    -- Newest toolchain release verified at build time (Rust 1.98.1,
    -- released 2026-09-03); the update check refreshes this live.
    known_upstream_version = '1.98.1',
    -- Parse terminal output into the quickfix list when the job exits.
    populate_quickfix = true,
    -- Quickfix list title prefix.
    quickfix_title = 'cargo',
    -- Plain-text marker of a rustc internal compiler error.
    rustc_ice_pattern = 'internal compiler error',
    -- Scrollback lines kept in the :Cargo terminal buffer (bound).
    term_height = 10000,
    -- Wall-clock cap for one-shot probes (version, metadata).
    timeout_ms = 30000,
    -- System package name for the toolchain updater (pacman/apt/dnf/brew
    -- all ship `rustup`).
    update_package = 'rustup',
    -- GitHub repo whose releases track the toolchain (cargo ships with
    -- it); verified 2026-09-27 against rust-lang/rust Releases.
    update_repo = 'rust-lang/rust',
    -- Linker his cargo config assigns to both zig cross targets.
    zig_linker = 'clang',
    -- Cross targets mirrored from his zigbuild aliases.
    zig_targets = { 'x86_64-unknown-linux-gnu', 'aarch64-unknown-linux-gnu' },
}

--- Live config, rebuilt by every setup() call. Never mutated in place.
---@type table
M.config = vim.deepcopy(M.default_config)

---@class dev.cargo.Diagnostic Quickfix-ready rustc diagnostic.
---@field filename string Source path from the --> line.
---@field lnum integer 1-based line number.
---@field col integer 1-based column number.
---@field type string 'E' for error, 'W' for warning.
---@field text string '[E....] message' or the bare message.

---@class dev.cargo.ParseCounts
---@field errors integer Diagnostics with a parsed location, kind E.
---@field warnings integer Diagnostics with a parsed location, kind W.
---@field ices integer Lines matching rustc_ice_pattern.

---@class dev.cargo.RunOpts
---@field subcommand string Cargo subcommand or alias, e.g. 't'.
---@field args? string[] Extra argv appended after alias expansion.
---@field on_exit? fun(info: dev.cargo.JobInfo) Called once when the job exits.

---@class dev.cargo.JobInfo
---@field argv string[] Resolved argv that was spawned.
---@field buf integer Terminal buffer handle.
---@field duration_ms number|nil Wall clock spawn->exit; nil until on_exit.
---@field errors integer rustc errors parsed from the output.
---@field exit_code integer|nil Process exit code; nil until on_exit.
---@field job_id integer termopen job id.
---@field warnings integer rustc warnings parsed from the output.
---@field win integer Float window handle.

---@class dev.cargo.Check
---@field name string
---@field status string 'ok' | 'below minimum' | 'unavailable'
---@field detail string One-line human summary.

--- Active jobs by termopen job id; entries are removed in on_exit.
---@type table<integer, dev.cargo.JobInfo>
M.jobs = {}

--- Type-check one config option. Mirrors the house pattern in git:
--- programmer errors raise, expected absences stay nil.
---@param name string Option name for the error message.
---@param value any Value to check.
---@param expected string Expected type() string.
local function check_type(name, value, expected)
    if type(value) ~= expected then
        error(('cargo: option %s must be %s, got %s'):format(name, expected, type(value)), 2)
    end
end

--- Build the live config: factory defaults deep-copied, overrides merged,
--- every key type-checked. Never mutates M.default_config.
---@param config table|nil Overrides; nil restores factory defaults.
---@return table merged Live config table.
function M.setup_config(config)
    if config ~= nil and type(config) ~= 'table' then
        error(('cargo: setup expects a table or nil, got %s'):format(type(config)), 2)
    end
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})
    check_type('alias_order', merged.alias_order, 'table')
    check_type('cargo_bin', merged.cargo_bin, 'string')
    check_type('cargo_version_min', merged.cargo_version_min, 'string')
    check_type('docs_url', merged.docs_url, 'string')
    check_type('float_height', merged.float_height, 'number')
    check_type('float_width', merged.float_width, 'number')
    check_type('known_upstream_version', merged.known_upstream_version, 'string')
    check_type('populate_quickfix', merged.populate_quickfix, 'boolean')
    check_type('quickfix_title', merged.quickfix_title, 'string')
    check_type('rustc_ice_pattern', merged.rustc_ice_pattern, 'string')
    check_type('term_height', merged.term_height, 'number')
    check_type('timeout_ms', merged.timeout_ms, 'number')
    check_type('update_package', merged.update_package, 'string')
    check_type('update_repo', merged.update_repo, 'string')
    check_type('zig_linker', merged.zig_linker, 'string')
    check_type('zig_targets', merged.zig_targets, 'table')
    for _, name in ipairs(merged.alias_order) do
        if type(name) ~= 'string' or M.aliases[name] == nil then
            error(('cargo: alias_order entry %s is not a known alias'):format(vim.inspect(name)), 2)
        end
    end
    return merged
end

--- Parse rustc/cargo human-readable output into quickfix items.
--- Recognizes `error[Exxxx]:` / `error:` / `warning:` headers and the
--- standard `--> path:line:col` location line; the first location per
--- diagnostic wins and a location without a preceding header is ignored.
--- Counts reflect diagnostics that produced an item -- exactly what lands
--- in the quickfix list. Summary lines such as "error: aborting due to N
--- previous errors" carry no location and are not counted. Input is
--- bounded: text over TEXT_BYTES_MAX is truncated, at most
--- OUTPUT_LINES_MAX lines are scanned.
---@param text string Raw compiler output.
---@return dev.cargo.Diagnostic[]|nil items
---@return dev.cargo.ParseCounts|string counts_or_err
function M.parse_rustc_output(text)
    if type(text) ~= 'string' then
        return nil, 'parse_rustc_output expects a string, got ' .. type(text)
    end
    local counts = { errors = 0, warnings = 0, ices = 0 }
    local items = {}
    local ice_pattern = M.config.rustc_ice_pattern
    local body = text:sub(1, TEXT_BYTES_MAX)
    ---@type { kind: string, code: string|nil, message: string }|nil
    local current = nil
    local function flush(path, lnum, col)
        local diag = current
        current = nil
        if diag == nil then
            return
        end
        local text_bits = {}
        if diag.code ~= nil then
            text_bits[#text_bits + 1] = diag.code
        end
        text_bits[#text_bits + 1] = diag.message
        items[#items + 1] = {
            filename = path,
            lnum = lnum,
            col = col,
            type = diag.kind,
            text = table.concat(text_bits, ' '),
        }
        if diag.kind == 'E' then
            counts.errors = counts.errors + 1
        else
            counts.warnings = counts.warnings + 1
        end
    end
    local line_count = 0
    for line in (body .. '\n'):gmatch('([^\n]*)\n') do
        line_count = line_count + 1
        if line_count > OUTPUT_LINES_MAX then
            break
        end
        if ice_pattern ~= '' and line:find(ice_pattern, 1, true) ~= nil then
            counts.ices = counts.ices + 1
        end
        local err_code, err_msg = line:match('^error%[E(%d+)%]:%s*(.-)%s*$')
        if err_code ~= nil then
            current = { kind = 'E', code = 'E' .. err_code, message = err_msg }
        else
            local err_plain = line:match('^error:%s*(.-)%s*$')
            if err_plain ~= nil then
                current = { kind = 'E', code = nil, message = err_plain }
            else
                local warn_msg = line:match('^warning:%s*(.-)%s*$')
                if warn_msg ~= nil then
                    current = { kind = 'W', code = nil, message = warn_msg }
                else
                    local path, lnum_s, col_s = line:match('^%s*%-%->%s*(.+):(%d+):(%d+)%s*$')
                    if path ~= nil and current ~= nil then
                        local lnum = assert(tonumber(lnum_s), 'location line digits failed to parse')
                        local col = assert(tonumber(col_s), 'location col digits failed to parse')
                        flush(path, lnum, col)
                    end
                end
            end
        end
    end
    return items, counts
end

--- Complete :Cargo's first argument: known aliases first (expansion shown
--- in the completion menu), then passthrough cargo subcommand hints.
---@param arg_lead string
---@return table[] items Completion dicts { word = ..., menu = ... }.
function M.complete(arg_lead, _cmd_line, _cursor_pos)
    local items = {}
    local seen = {}
    for _, name in ipairs(M.config.alias_order) do
        if name:sub(1, #arg_lead) == arg_lead then
            local expansion = table.concat(M.aliases[name], ' ')
            items[#items + 1] = { word = name, menu = '[alias] ' .. expansion }
            seen[name] = true
        end
    end
    for _, sub in ipairs(COMMON_SUBCOMMANDS) do
        if not seen[sub] and sub:sub(1, #arg_lead) == arg_lead then
            items[#items + 1] = { word = sub, menu = '[cargo]' }
        end
    end
    return items
end

--- Open a centered, minimal float for the cargo terminal. `q` closes it
--- (mirrors the git float idiom).
---@param title string Float title.
---@return integer buf
---@return integer win
local function open_term_float(title)
    local buf = api.nvim_create_buf(false, true)
    local win_width = math.min(M.config.float_width, vim.o.columns - 4)
    local win_height = math.min(M.config.float_height, vim.o.lines - 4)
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = math.floor((vim.o.lines - win_height) / 2),
        col = math.floor((vim.o.columns - win_width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })
    api.nvim_buf_set_name(buf, 'cargo://' .. title)
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true, desc = 'Close cargo float' })
    return buf, win
end

--- Read the finished terminal buffer, parse rustc output into the
--- quickfix list, and report the counts. Runs inside the on_exit
--- callback; never throws (the float may already be closed).
---@param info dev.cargo.JobInfo
local function finish_run(info)
    if not M.config.populate_quickfix then
        return
    end
    if not api.nvim_buf_is_valid(info.buf) then
        return
    end
    local ok, lines = pcall(api.nvim_buf_get_lines, info.buf, 0, -1, false)
    if not ok or type(lines) ~= 'table' then
        return
    end
    local bounded = {}
    for index = 1, math.min(#lines, OUTPUT_LINES_MAX) do
        bounded[#bounded + 1] = lines[index]
    end
    local items, counts = M.parse_rustc_output(table.concat(bounded, '\n'))
    if items == nil then
        return
    end
    assert(counts ~= nil, 'parse returned items but no counts')
    info.errors = counts.errors
    info.warnings = counts.warnings
    fn.setqflist(items, 'r', { title = M.config.quickfix_title .. ': ' .. table.concat(info.argv, ' ') })
    local summary = ('cargo: %d error(s), %d warning(s)'):format(counts.errors, counts.warnings)
    if counts.ices > 0 then
        summary = summary .. (', %d ICE(s)'):format(counts.ices)
    end
    if info.duration_ms ~= nil then
        summary = summary .. (' in %.1fs'):format(info.duration_ms / 1000)
    end
    local level = vim.log.levels.INFO
    if counts.errors > 0 or counts.ices > 0 then
        level = vim.log.levels.WARN
    end
    vim.notify(summary, level)
end

--- Run a cargo subcommand in a floating terminal. The subcommand is
--- expanded through M.aliases when known; anything else is passed to
--- cargo verbatim (argv form via termopen -- never a shell string).
--- Returns the job info immediately; duration_ms/exit_code fill in when
--- the job exits and on_exit fires. Validation failures -- and a missing
--- cargo binary -- return nil+err before anything is spawned (the float
--- is closed on the failure path); M.run never throws. This is the seam
--- module 10 (notify) wraps: keep the (opts, info, on_exit) contract stable.
---@param opts dev.cargo.RunOpts
---@return dev.cargo.JobInfo|nil info
---@return string|nil err
function M.run(opts)
    if type(opts) ~= 'table' then
        return nil, 'run expects an options table, got ' .. type(opts)
    end
    if type(opts.subcommand) ~= 'string' or opts.subcommand == '' then
        return nil, 'run requires a non-empty string subcommand'
    end
    local extra = opts.args or {}
    if type(extra) ~= 'table' then
        return nil, 'run opts.args must be a string list'
    end
    for index, arg in ipairs(extra) do
        if type(arg) ~= 'string' then
            return nil, 'run opts.args[' .. index .. '] must be a string, got ' .. type(arg)
        end
    end
    if opts.on_exit ~= nil and type(opts.on_exit) ~= 'function' then
        return nil, 'run opts.on_exit must be a function'
    end
    local argv = { M.config.cargo_bin }
    local expansion = M.aliases[opts.subcommand]
    if expansion ~= nil then
        for _, word in ipairs(expansion) do
            argv[#argv + 1] = word
        end
    else
        argv[#argv + 1] = opts.subcommand
    end
    for _, arg in ipairs(extra) do
        argv[#argv + 1] = arg
    end
    local buf, win = open_term_float(' cargo ' .. opts.subcommand .. ' ')
    -- A missing cargo binary is an expected failure (see :CargoValidate),
    -- never a throw: termopen raises E475 for a non-executable, so check
    -- first and keep the pcall as a second net.
    if not toolmgr.binary_present(M.config.cargo_bin) then
        api.nvim_win_close(win, true)
        return nil, ("cargo binary '%s' not found on PATH"):format(M.config.cargo_bin)
    end
    local info = {
        argv = argv,
        buf = buf,
        duration_ms = nil,
        errors = 0,
        exit_code = nil,
        job_id = 0,
        warnings = 0,
        win = win,
    }
    local started_ns = vim.uv.hrtime()
    -- Declared before termopen so on_exit can name the job: the callback
    -- cannot fire before termopen returns, so job_id is always assigned.
    local job_id = 0
    local spawn_ok, spawn_result = pcall(fn.termopen, argv, {
        on_exit = function(_job, code, _event)
            info.exit_code = code
            info.duration_ms = (vim.uv.hrtime() - started_ns) / 1000000
            M.jobs[job_id] = nil
            finish_run(info)
            if opts.on_exit ~= nil then
                opts.on_exit(info)
            end
        end,
    })
    if spawn_ok and type(spawn_result) == 'number' then
        job_id = spawn_result
    end
    if job_id <= JOB_ID_INVALID then
        api.nvim_win_close(win, true)
        local reason = spawn_ok and 'termopen refused the spawn' or tostring(spawn_result)
        return nil, 'termopen failed to start ' .. table.concat(argv, ' ') .. ': ' .. reason
    end
    info.job_id = job_id
    M.jobs[job_id] = info
    return info, nil
end

--- Detect the enclosing cargo workspace root. Delegates to
--- `cargo metadata` (bounded), which performs its own Cargo.toml
--- walk-up; this module keeps no hand-rolled walk-up logic.
---@return string|nil root
---@return string|nil err
function M.workspace_root()
    local result, exec_err = rce.safe_exec(
        { M.config.cargo_bin, 'metadata', '--no-deps', '--format-version', '1' },
        { timeout_ms = M.config.timeout_ms }
    )
    if exec_err ~= nil then
        return nil, exec_err
    end
    assert(result ~= nil, 'safe_exec returned no error but no result')
    if result.code ~= 0 then
        return nil, 'cargo metadata exited ' .. result.code .. ': ' .. (result.stderr or ''):sub(1, 200)
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if not ok or type(decoded) ~= 'table' then
        return nil, 'cargo metadata output did not decode as JSON'
    end
    local root = decoded.workspace_root
    if type(root) ~= 'string' or root == '' then
        return nil, 'cargo metadata reported no workspace_root'
    end
    return root, nil
end

--- Map a toolmgr binary report onto the check status vocabulary.
--- Mirrors git: missing tools are 'unavailable', never an error.
---@param report utils.toolmgr.BinaryReport
---@return dev.cargo.Check
local function to_check(report)
    local status = 'unavailable'
    if report.present and report.meets_minimum then
        status = 'ok'
    elseif report.present then
        status = 'below minimum'
    end
    return { name = report.name, status = status, detail = report.detail }
end

--- Per-tool validation. Never throws and never errors: a missing tool is
--- 'unavailable', a too-old one 'below minimum'.
---@return dev.cargo.Check[] checks
function M.checks()
    local cfg = M.config
    local checks = {}
    checks[#checks + 1] = to_check(toolmgr.check_binary({ name = cfg.cargo_bin, min_version = cfg.cargo_version_min }))
    checks[#checks + 1] = to_check(toolmgr.check_binary({ name = 'rustc' }))
    -- His zigbuild aliases need `zig` and the `cargo-zigbuild` shim;
    -- his cargo config links both cross targets through clang.
    checks[#checks + 1] = to_check(toolmgr.check_binary({ name = 'cargo-zigbuild' }))
    checks[#checks + 1] = to_check(toolmgr.check_binary({ name = 'zig' }))
    local linker = toolmgr.check_binary({ name = cfg.zig_linker })
    for _, target in ipairs(cfg.zig_targets) do
        checks[#checks + 1] = {
            name = 'linker:' .. target,
            status = linker.present and 'ok' or 'unavailable',
            detail = linker.present and (cfg.zig_linker .. ' available for ' .. target)
                or (cfg.zig_linker .. ' missing: ' .. target .. ' cross builds will fail'),
        }
    end
    local root, root_err = M.workspace_root()
    checks[#checks + 1] = {
        name = 'workspace',
        status = root ~= nil and 'ok' or 'unavailable',
        detail = root ~= nil and ('workspace root: ' .. root) or ('not in a cargo workspace: ' .. tostring(root_err)),
    }
    return checks
end

--- :Cargo [subcommand] [args...] -- run cargo in a floating terminal.
---@param cmd_opts table nvim_create_user_command callback options.
function M.cmd_cargo(cmd_opts)
    local fargs = cmd_opts.fargs or {}
    if #fargs < 1 then
        vim.notify('Cargo: expected a subcommand, e.g. :Cargo t', vim.log.levels.ERROR)
        return
    end
    local args = {}
    for index = 2, #fargs do
        args[#args + 1] = fargs[index]
    end
    local info, run_err = M.run({ subcommand = fargs[1], args = args })
    if run_err ~= nil then
        vim.notify('Cargo: ' .. run_err, vim.log.levels.ERROR)
        return
    end
    assert(info ~= nil, 'run returned no error but no job info')
end

--- :CargoDocs -- open the verified Cargo Book.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_docs(_cmd_opts)
    local url = M.config.docs_url
    local opened = vim.ui.open ~= nil and pcall(vim.ui.open, url)
    if not opened then
        vim.notify('cargo docs: ' .. url, vim.log.levels.INFO)
    end
end

--- :CargoValidate -- one vim.notify per check; missing tools say
--- "unavailable", never an error.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_validate(_cmd_opts)
    for _, check in ipairs(M.checks()) do
        local level = check.status == 'ok' and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(('cargo %-18s %-13s %s'):format(check.name, check.status, check.detail), level)
    end
end

--- :CargoUpdateCheck -- toolmgr update dialog for the Rust toolchain
--- (cargo ships with it), against the verified rust-lang/rust releases.
---@param _cmd_opts table nvim_create_user_command callback options.
function M.cmd_update_check(_cmd_opts)
    local current = toolmgr.command_version({ M.config.cargo_bin, '--version' })
    toolmgr.check_update({
        tool_label = 'cargo',
        repo = M.config.update_repo,
        package = M.config.update_package,
        current_version = current,
        known_upstream_version = M.config.known_upstream_version,
        migrations = MIGRATIONS,
    })
end

local setup_done = false

--- Register the :Cargo* commands. Idempotent: commands are created once;
--- the config is rebuilt on every call. Performs no subprocess I/O
--- itself.
---@param config? table Overrides merged over M.default_config.
function M.setup(config)
    M.config = M.setup_config(config)
    if setup_done then
        return
    end
    setup_done = true
    api.nvim_create_user_command('Cargo', M.cmd_cargo, {
        nargs = '*',
        complete = M.complete,
        desc = 'Run cargo in a floating terminal (aliases: b c r rr t zig-*)',
    })
    api.nvim_create_user_command('CargoDocs', M.cmd_docs, { desc = 'Open the Cargo Book' })
    api.nvim_create_user_command('CargoValidate', M.cmd_validate, { desc = 'Cargo per-tool validation report' })
    api.nvim_create_user_command('CargoUpdateCheck', M.cmd_update_check, { desc = 'Rust toolchain update check' })
end

return M
