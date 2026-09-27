-- tests/lua/ownership_guard_adversarial.lua
-- Balanced suite for the save-ownership guard: exactly half adversarial,
-- half validation (16 checks each, 32 total).
-- Run from the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/ownership_guard_adversarial.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $OWNERSHIP_GUARD_REPORT (default /tmp/ownership_guard_report.txt);
-- print() is unreliable under this invocation, so the file is the record.
--
-- The guard under test lives in lua/formatters/init.lua:
--   * formatters.check_save_ownership(opts) — static scan of
--     lua/config/lang/*.lua + after/ftplugin/*.lua, returning violations.
--   * formatters.assert_save_ownership(opts) — same scan, raising loudly.
--   * the register_stage tripwire over live BufWritePre autocmds.
local api = vim.api
local report_path = os.getenv('OWNERSHIP_GUARD_REPORT') or '/tmp/ownership_guard_report.txt'
local log_lines = {}
local function emit(line)
    log_lines[#log_lines + 1] = line
end
local adv_passed, adv_failed = 0, 0
local val_passed, val_failed = 0, 0
local function adv_check(cond, msg)
    if cond then
        adv_passed = adv_passed + 1
        emit('ok [A] - ' .. msg)
    else
        adv_failed = adv_failed + 1
        emit('NOT OK [A] - ' .. msg)
    end
end
local function val_check(cond, msg)
    if cond then
        val_passed = val_passed + 1
        emit('ok [V] - ' .. msg)
    else
        val_failed = val_failed + 1
        emit('NOT OK [V] - ' .. msg)
    end
end
local notices = {}
local orig_notify = vim.notify
vim.notify = function(msg, level, _)
    notices[#notices + 1] = {
        msg = tostring(msg),
        level = level,
    }
end
local formatters = require('formatters')

-- Fixture scaffolding: each case gets its own directory so scans stay
-- isolated. Fixtures are never executed, only scanned as text.
local fx_root = vim.fn.tempname() .. '_t3fx'
vim.fn.mkdir(fx_root, 'p')
local fx_n = 0
local function fixture_dir(name)
    fx_n = fx_n + 1
    local dir = ('%s/%02d_%s'):format(fx_root, fx_n, name)
    vim.fn.mkdir(dir, 'p')
    return dir
end
local function write_fixture(dir, content)
    local path = dir .. '/lang_fixture.lua'
    local fh = assert(io.open(path, 'w'))
    fh:write(content)
    fh:close()
    return path
end
local function scan_dir(dir, allowlist)
    return formatters.check_save_ownership({
        roots = { dir },
        allowlist = allowlist or {},
    })
end

-- A1: a direct save-time formatter is caught, naming file and line.
local dir_a1 = fixture_dir('direct')
local path_a1 = write_fixture(
    dir_a1,
    table.concat({
        'local api = vim.api',
        '-- a direct save formatter: the original sin the guard exists for',
        "api.nvim_create_autocmd('BufWritePre', {",
        '    callback = function()',
        '        vim.lsp.buf.format()',
        '    end,',
        '})',
        '',
    }, '\n')
)
local vs_a1 = scan_dir(dir_a1)
adv_check(#vs_a1 == 1, 'A1 direct BufWritePre formatter caught (got ' .. #vs_a1 .. ')')
adv_check(
    #vs_a1 == 1 and vs_a1[1].line == 3,
    'A1 violation names line 3 (got ' .. (#vs_a1 == 1 and vs_a1[1].line or -1) .. ')'
)
adv_check(#vs_a1 == 1 and vs_a1[1].file == path_a1, 'A1 violation names the offending file')

-- A2: the local-alias disguise (local autocmd = vim.api.nvim_create_autocmd).
local dir_a2 = fixture_dir('alias')
write_fixture(
    dir_a2,
    table.concat({
        'local autocmd = vim.api.nvim_create_autocmd',
        "autocmd('BufWritePre', { callback = function() end })",
        '',
    }, '\n')
)
local vs_a2 = scan_dir(dir_a2)
adv_check(#vs_a2 == 1, 'A2 aliased nvim_create_autocmd caught (got ' .. #vs_a2 .. ')')
adv_check(
    #vs_a2 == 1 and vs_a2[1].line == 2,
    'A2 violation names line 2 (got ' .. (#vs_a2 == 1 and vs_a2[1].line or -1) .. ')'
)

-- A3: the event-in-a-variable disguise (local SAVE = 'BufWritePre').
local dir_a3 = fixture_dir('varname')
write_fixture(
    dir_a3,
    table.concat({
        'local api = vim.api',
        "local SAVE_EVENT = 'BufWritePre'",
        'api.nvim_create_autocmd(SAVE_EVENT, { callback = function() end })',
        '',
    }, '\n')
)
local vs_a3 = scan_dir(dir_a3)
adv_check(#vs_a3 == 1, 'A3 event-in-variable caught (got ' .. #vs_a3 .. ')')
adv_check(
    #vs_a3 == 1 and vs_a3[1].line == 3,
    'A3 violation names line 3 (got ' .. (#vs_a3 == 1 and vs_a3[1].line or -1) .. ')'
)

-- A4: the event passed as a table list.
local dir_a4 = fixture_dir('eventlist')
write_fixture(
    dir_a4,
    table.concat({
        "vim.api.nvim_create_autocmd({ 'BufWritePre', 'BufWritePost' }, {",
        '    callback = function() end,',
        '})',
        '',
    }, '\n')
)
local vs_a4 = scan_dir(dir_a4)
adv_check(#vs_a4 == 1, 'A4 table event list caught (got ' .. #vs_a4 .. ')')
adv_check(
    #vs_a4 == 1 and vs_a4[1].line == 1,
    'A4 violation names line 1 (got ' .. (#vs_a4 == 1 and vs_a4[1].line or -1) .. ')'
)

-- A5: the legacy vim.cmd('autocmd BufWritePre ...') form.
local dir_a5 = fixture_dir('vimcmd')
write_fixture(
    dir_a5,
    table.concat({
        "vim.cmd('autocmd BufWritePre *.t3x lua vim.lsp.buf.format()')",
        '',
    }, '\n')
)
local vs_a5 = scan_dir(dir_a5)
adv_check(#vs_a5 == 1, 'A5 legacy vim.cmd autocmd caught (got ' .. #vs_a5 .. ')')
adv_check(
    #vs_a5 == 1 and vs_a5[1].line == 1,
    'A5 violation names line 1 (got ' .. (#vs_a5 == 1 and vs_a5[1].line or -1) .. ')'
)

-- A6: an allowlisted non-formatting BufWritePre passes; the allowlist is
-- what suppresses it, not a scanner blind spot.
local dir_a6 = fixture_dir('allowlisted')
local path_a6 = write_fixture(
    dir_a6,
    table.concat({
        '-- fixture: documents the allowlist mechanism, nothing more',
        "vim.api.nvim_create_autocmd('BufWritePre', { callback = function() end })",
        '',
    }, '\n')
)
local vs_a6_bare = scan_dir(dir_a6)
local vs_a6_listed = scan_dir(dir_a6, {
    {
        file = path_a6,
        line = 2,
        rationale = 't3 fixture: proves the allowlist suppresses a real hit',
    },
})
adv_check(#vs_a6_bare == 1, 'A6 fixture is a real hit without the allowlist')
adv_check(#vs_a6_listed == 0, 'A6 allowlisted entry passes the scan')

-- A7: the npm_groovy_lint known exception never false-positives the lang
-- scan (it lives outside the scan paths by design).
do
    local leaked = false
    for _, violation in ipairs(formatters.check_save_ownership()) do
        if violation.file:find('npm_groovy_lint', 1, true) then
            leaked = true
        end
    end
    adv_check(not leaked, 'A7 npm_groovy_lint exception does not leak into the lang scan')
end

-- A8: assert_save_ownership fails loudly, naming file and line.
do
    local ok, err = pcall(formatters.assert_save_ownership, { roots = { dir_a1 } })
    adv_check(not ok, 'A8 assert_save_ownership raised on the rogue fixture')
    local msg = tostring(err)
    adv_check(
        not ok and msg:find(path_a1, 1, true) ~= nil and msg:find(':3:', 1, true) ~= nil,
        'A8 failure names the file and line'
    )
end

-- V1: the guard passes clean on the current tree (post-8c1e38d: no live
-- formatting BufWritePre remains in the scanned paths).
do
    local violations = formatters.check_save_ownership()
    local detail = ''
    if #violations > 0 then
        detail = ' (' .. violations[1].file .. ':' .. violations[1].line .. ')'
    end
    val_check(#violations == 0, 'V1 default scan over the real tree is clean' .. detail)
end

-- V2: BufWritePre mentioned only in comments never trips the scanner.
do
    local dir = fixture_dir('commentsonly')
    write_fixture(
        dir,
        table.concat({
            "-- api.nvim_create_autocmd('BufWritePre', { callback = f })",
            '--[[',
            "vim.api.nvim_create_autocmd('BufWritePre', {})",
            '--]]',
            'local x = 1',
            '',
        }, '\n')
    )
    val_check(#scan_dir(dir) == 0, 'V2 comment-only mentions do not trip the scanner')
end

-- V3: BufNewFile header insertion (the rust.lua pattern) is out of scope.
do
    local dir = fixture_dir('bufnewfile')
    write_fixture(
        dir,
        table.concat({
            'local api = vim.api',
            'local autocmd = vim.api.nvim_create_autocmd',
            "autocmd('BufNewFile', {",
            "    pattern = { '*.t3x' },",
            '    callback = function()',
            "        api.nvim_buf_set_lines(0, 0, 0, false, { '-- header' })",
            '    end,',
            '})',
            '',
        }, '\n')
    )
    val_check(#scan_dir(dir) == 0, 'V3 BufNewFile header insertion is not flagged')
end

-- V4: a non-save event whose desc mentions BufWritePre is not flagged.
do
    local dir = fixture_dir('descmention')
    write_fixture(
        dir,
        table.concat({
            "vim.api.nvim_create_autocmd('BufEnter', {",
            "    desc = 'runs before the BufWritePre pipeline stage',",
            '    callback = function() end,',
            '})',
            '',
        }, '\n')
    )
    val_check(#scan_dir(dir) == 0, 'V4 desc-only mention on a non-save event is not flagged')
end

-- V5: the register_stage tripwire stays within budget — 100
-- register/unregister cycles (each runs the live-autocmd enumeration)
-- must stay well under the 50ms setup budget.
do
    local t0 = vim.uv.hrtime()
    for i = 1, 100 do
        local name = 't3_val_probe_' .. i
        formatters.register_stage({
            name = name,
            priority = 10,
            run = function() end,
        })
        formatters.unregister_stage(name)
    end
    local ms = (vim.uv.hrtime() - t0) / 1e6
    val_check(ms < 50, ('V5 100 register/unregister cycles took %.1fms (< 50ms)'):format(ms))
end

-- V6: on the real tree the runtime tripwire stays silent — every live
-- BufWritePre is pipeline-owned or explicitly allowlisted.
do
    notices = {}
    formatters.register_stage({
        name = 't3_val_live_probe',
        priority = 10,
        run = function() end,
    })
    local tripped = false
    for _, note in ipairs(notices) do
        if note.level == vim.log.levels.ERROR and note.msg:find('rogue save-time BufWritePre', 1, true) then
            tripped = true
        end
    end
    val_check(not tripped, 'V6 tripwire silent on the real tree (no rogue live BufWritePre)')
    val_check(
        formatters.get_stage('t3_val_live_probe') ~= nil,
        'V6 probe stage registered, so the tripwire path genuinely ran'
    )
    formatters.unregister_stage('t3_val_live_probe')
end

-- V7: the static scan is fast enough to live in the normal test suite.
do
    local t0 = vim.uv.hrtime()
    formatters.check_save_ownership()
    local ms = (vim.uv.hrtime() - t0) / 1e6
    val_check(ms < 10000, ('V7 default tree scan took %.0fms (< 10s suite budget)'):format(ms))
end

-- V8: the runtime allowlist documents the npm_groovy_lint known
-- exception as do-not-fix.
do
    local found = nil
    for _, entry in ipairs(formatters.ownership_runtime_allowlist) do
        if entry.group_name == 'npm_groovy_lint_format' then
            found = entry
        end
    end
    val_check(found ~= nil, 'V8 runtime allowlist carries the npm_groovy_lint_format exception')
    val_check(
        found ~= nil and found.rationale:find('KNOWN EXCEPTION', 1, true) ~= nil,
        'V8 exception rationale is marked do-not-fix'
    )
end

-- V9: repeated scans agree — the guard is deterministic.
do
    local first = formatters.check_save_ownership()
    local second = formatters.check_save_ownership()
    val_check(#first == 0 and #second == 0, 'V9 two consecutive scans agree (both clean)')
end

-- V10: the violation snippet shows the offending source line.
do
    val_check(
        #vs_a1 == 1 and vs_a1[1].snippet:find('nvim_create_autocmd', 1, true) ~= nil,
        'V10 violation snippet shows the offending call'
    )
end

-- V11: violations come back sorted by file, then line.
do
    local combined = formatters.check_save_ownership({ roots = { dir_a2, dir_a1 } })
    val_check(#combined == 2 and combined[1].file < combined[2].file, 'V11 violations sorted by file then line')
end

-- V12: a missing scan root errors loudly instead of silently passing.
do
    local ok = pcall(formatters.check_save_ownership, {
        roots = { '/nonexistent_t3_root_xyz' },
    })
    val_check(not ok, 'V12 missing scan root raises instead of silently passing')
end

-- V13: the pipeline's own BufWritePre exists under the documented group.
do
    local found = false
    for _, autocmd in ipairs(api.nvim_get_autocmds({ event = 'BufWritePre' })) do
        if autocmd.group_name == 'native_formatters' then
            found = true
        end
    end
    val_check(found, 'V13 pipeline BufWritePre present (group native_formatters)')
end

-- V14: the repo root resolves to this checkout regardless of cwd.
do
    local root = formatters.ownership_repo_root()
    val_check(
        vim.uv.fs_stat(root .. '/lua/formatters/init.lua') ~= nil,
        'V14 ownership_repo_root resolves to the diver checkout'
    )
end

vim.notify = orig_notify
local adv_total = adv_passed + adv_failed
local val_total = val_passed + val_failed
emit(
    ('summary: adversarial %d/%d passed; validation %d/%d passed'):format(adv_passed, adv_total, val_passed, val_total)
)
emit(('balance: %d adversarial checks, %d validation checks'):format(adv_total, val_total))
local fh = assert(io.open(report_path, 'w'))
fh:write(table.concat(log_lines, '\n') .. '\n')
fh:close()
os.exit((adv_failed == 0 and val_failed == 0 and adv_total == val_total) and 0 or 1)
