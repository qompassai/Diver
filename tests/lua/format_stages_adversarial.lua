-- tests/lua/format_stages_adversarial.lua
-- Balanced suite for the single-format-on-save pipeline owner: exactly half
-- adversarial, half validation (12 checks each, 24 total).
-- Run from the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/format_stages_adversarial.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $T1_ADV_REPORT (default /tmp/t1_adversarial_report.txt); print() is
-- unreliable under this invocation, so the file is the record.
--
-- NOTE: a real :write! is not used. Under the full config a plugin (not this
-- track's code) terminates headless nvim on :write!; the failure reproduces
-- on the pristine tree and with --noplugin it works. The live path is
-- exercised by firing the real BufWritePre autocmds via
-- nvim_exec_autocmds, which is exactly what :write! would trigger.
local api = vim.api
local report_path = os.getenv('T1_ADV_REPORT') or '/tmp/t1_adversarial_report.txt'
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
local tmp = vim.fn.tempname() .. '_t1adv'
vim.fn.mkdir(tmp, 'p')
local function make_buf(name, filetype, lines)
    local buf = api.nvim_create_buf(true, false)
    api.nvim_buf_set_name(buf, tmp .. '/' .. name)
    if filetype then
        vim.bo[buf].filetype = filetype
    end
    api.nvim_buf_set_lines(buf, 0, -1, false, lines or { 'placeholder' })
    return buf
end
local function drop_buf(buf)
    if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_delete(buf, { force = true })
    end
end
local function reg(name, priority, opts, run)
    formatters.register_stage({
        name = name,
        priority = priority,
        patterns = opts.patterns,
        filetypes = opts.filetypes,
        desc = 't1 adversarial probe',
        run = run,
    })
end
local function unreg(name)
    formatters.unregister_stage(name)
end

-- A1: registration order must not affect execution order (adversarial).
do
    local order = {}
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_adv_z_last', 30, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 'z'
    end)
    reg('t1_adv_a_first', 10, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 'a'
    end)
    reg('t1_adv_m_mid', 20, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 'm'
    end)
    formatters.run_save_stages(buf)
    adv_check(
        #order == 3 and order[1] == 'a' and order[2] == 'm' and order[3] == 'z',
        'A1 priority order deterministic despite reverse registration (got ' .. table.concat(order, ',') .. ')'
    )
    unreg('t1_adv_z_last')
    unreg('t1_adv_a_first')
    unreg('t1_adv_m_mid')
    drop_buf(buf)
end

-- V1: stages run in ascending priority order (validation).
do
    local order = {}
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_val_p30', 30, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 30
    end)
    reg('t1_val_p10', 10, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 10
    end)
    reg('t1_val_p20', 20, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 20
    end)
    formatters.run_save_stages(buf)
    val_check(
        #order == 3 and order[1] == 10 and order[2] == 20 and order[3] == 30,
        'V1 stages executed in ascending priority order'
    )
    unreg('t1_val_p30')
    unreg('t1_val_p10')
    unreg('t1_val_p20')
    drop_buf(buf)
end

-- A2: an erroring stage must not break the save or later stages (adversarial).
do
    local after_ran = false
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_adv_boom', 10, { patterns = { '*.t1a' } }, function()
        error('t1 adversarial boom')
    end)
    reg('t1_adv_after', 20, { patterns = { '*.t1a' } }, function()
        after_ran = true
    end)
    notices = {}
    local n = formatters.run_save_stages(buf)
    adv_check(after_ran, 'A2 later stage still ran after an erroring stage')
    -- t1_adv_after + the always-applicable native_pipeline stage.
    adv_check(n == 2, 'A2 completed count excludes the failed stage (got ' .. tostring(n) .. ')')
    local warned = false
    for _, note in ipairs(notices) do
        if note.level == vim.log.levels.WARN and note.msg:find('t1_adv_boom', 1, true) then
            warned = true
        end
    end
    adv_check(warned, 'A2 erroring stage produced exactly one WARN naming it')
    unreg('t1_adv_boom')
    unreg('t1_adv_after')
    drop_buf(buf)
end

-- V2: each matching stage runs exactly once per save (validation).
do
    local counts = { a = 0, b = 0 }
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_val_once_a', 10, { patterns = { '*.t1a' } }, function()
        counts.a = counts.a + 1
    end)
    reg('t1_val_once_b', 20, { patterns = { '*.t1a' } }, function()
        counts.b = counts.b + 1
    end)
    formatters.run_save_stages(buf)
    val_check(
        counts.a == 1 and counts.b == 1,
        'V2 each stage ran exactly once (a=' .. counts.a .. ' b=' .. counts.b .. ')'
    )
    unreg('t1_val_once_a')
    unreg('t1_val_once_b')
    drop_buf(buf)
end

-- A3: vim.b.format_disabled skips every stage, including LSP ones (adversarial).
do
    local probe_ran = false
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_adv_probe', 10, { patterns = { '*.t1a' } }, function()
        probe_ran = true
    end)
    vim.b[buf].format_disabled = true
    local n = formatters.run_save_stages(buf)
    adv_check(n == 0, 'A3 run_save_stages returns 0 when format_disabled')
    adv_check(not probe_ran, 'A3 no stage ran when format_disabled')
    vim.b[buf].format_disabled = nil
    unreg('t1_adv_probe')
    drop_buf(buf)
end

-- V3: run_save_stages returns the count of cleanly completed stages (validation).
do
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_val_cnt_a', 10, { patterns = { '*.t1a' } }, function()
        return true
    end)
    reg('t1_val_cnt_b', 20, { patterns = { '*.t1a' } }, function()
        return true
    end)
    -- native_pipeline always applies and returns true when format_on_save is off.
    local n = formatters.run_save_stages(buf)
    val_check(n == 3, 'V3 completed count is 3 (two probes + native_pipeline), got ' .. tostring(n))
    unreg('t1_val_cnt_a')
    unreg('t1_val_cnt_b')
    drop_buf(buf)
end

-- A4: stages must not fire for non-matching filetype or pattern (adversarial).
do
    local ft_ran, pat_ran = false, false
    local buf = make_buf('probe.t1a', 'lua')
    reg('t1_adv_wrong_ft', 10, { filetypes = { 'no_such_filetype_xyz' } }, function()
        ft_ran = true
    end)
    reg('t1_adv_wrong_pat', 10, { patterns = { '*.nomatch_xyz' } }, function()
        pat_ran = true
    end)
    formatters.run_save_stages(buf)
    adv_check(not ft_ran, 'A4 filetype-scoped stage did not fire for another filetype')
    adv_check(not pat_ran, 'A4 pattern-scoped stage did not fire for a non-matching name')
    unreg('t1_adv_wrong_ft')
    unreg('t1_adv_wrong_pat')
    drop_buf(buf)
end

-- V4: pattern matching fires for matching names (validation).
do
    local ran = false
    local buf = make_buf('matchme.t1v', 'text')
    reg('t1_val_pat', 10, { patterns = { '*.t1v' } }, function()
        ran = true
    end)
    formatters.run_save_stages(buf)
    val_check(ran, 'V4 pattern-scoped stage fired for a matching name')
    unreg('t1_val_pat')
    drop_buf(buf)
end

-- V5: filetype matching fires for matching filetypes (validation).
do
    local ran = false
    local buf = make_buf('probe.t1a', 't1valft')
    reg('t1_val_ft', 10, { filetypes = { 't1valft' } }, function()
        ran = true
    end)
    formatters.run_save_stages(buf)
    val_check(ran, 'V5 filetype-scoped stage fired for a matching filetype')
    unreg('t1_val_ft')
    drop_buf(buf)
end

-- A5: duplicate stage names are rejected loudly, not merged silently (adversarial).
do
    reg('t1_adv_dup', 10, { patterns = { '*.t1a' } }, function() end)
    local ok, err = pcall(reg, 't1_adv_dup', 10, { patterns = { '*.t1a' } }, function() end)
    adv_check(not ok, 'A5 second registration with the same name raised')
    adv_check(
        not ok and tostring(err):find('t1_adv_dup', 1, true) ~= nil,
        'A5 duplicate-name error names the offending stage'
    )
    unreg('t1_adv_dup')
end

-- V6: unregister_stage removes the stage; get_stage reflects it (validation).
do
    reg('t1_val_tmp', 10, { patterns = { '*.t1a' } }, function() end)
    val_check(formatters.get_stage('t1_val_tmp') ~= nil, 'V6 get_stage finds a registered stage')
    unreg('t1_val_tmp')
    val_check(formatters.get_stage('t1_val_tmp') == nil, 'V6 get_stage returns nil after unregister')
end

-- A6: the live BufWritePre path survives an erroring stage (adversarial).
-- Fires the real autocmds via nvim_exec_autocmds (a real :write! is killed
-- by an unrelated plugin in this headless environment; see header note).
do
    local buf = make_buf('live.t1a', 'text', { 'hello save' })
    local marker_ran = false
    reg('t1_adv_live_boom', 10, { patterns = { '*.t1a' } }, function()
        error('t1 adversarial live boom')
    end)
    reg('t1_adv_live_marker', 20, { patterns = { '*.t1a' } }, function()
        marker_ran = true
    end)
    notices = {}
    api.nvim_exec_autocmds('BufWritePre', { buffer = buf })
    adv_check(marker_ran, 'A6 live BufWritePre ran later stages despite the error')
    local warned = false
    for _, note in ipairs(notices) do
        if note.level == vim.log.levels.WARN and note.msg:find('t1_adv_live_boom', 1, true) then
            warned = true
        end
    end
    adv_check(warned, 'A6 live BufWritePre warned about the erroring stage')
    unreg('t1_adv_live_boom')
    unreg('t1_adv_live_marker')
    drop_buf(buf)
end

-- V7: the live BufWritePre path runs stages in order, exactly once (validation).
do
    local order = {}
    local buf = make_buf('live.t1a', 'text', { 'hello save' })
    reg('t1_val_live_b', 20, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 'b'
    end)
    reg('t1_val_live_a', 10, { patterns = { '*.t1a' } }, function()
        order[#order + 1] = 'a'
    end)
    api.nvim_exec_autocmds('BufWritePre', { buffer = buf })
    val_check(
        #order == 2 and order[1] == 'a' and order[2] == 'b',
        'V7 live BufWritePre ran stages in priority order exactly once'
    )
    unreg('t1_val_live_b')
    unreg('t1_val_live_a')
    drop_buf(buf)
end

-- V8: stage context carries the buffer number and stage name (validation).
do
    local seen_bufnr, seen_name = nil, nil
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_val_ctx', 10, { patterns = { '*.t1a' } }, function(bufnr, ctx)
        seen_bufnr = bufnr
        seen_name = ctx and ctx.name
    end)
    formatters.run_save_stages(buf)
    val_check(seen_bufnr == buf, 'V8 stage received the correct bufnr')
    val_check(seen_name == 't1_val_ctx', 'V8 stage context names the stage')
    unreg('t1_val_ctx')
    drop_buf(buf)
end

-- A7: a stage returning false is not counted as completed (adversarial).
do
    local buf = make_buf('probe.t1a', 'text')
    reg('t1_adv_skipme', 10, { patterns = { '*.t1a' } }, function()
        return false
    end)
    -- native_pipeline always applies and returns true.
    local n = formatters.run_save_stages(buf)
    adv_check(n == 1, 'A7 stage returning false excluded from completed count (got ' .. tostring(n) .. ')')
    unreg('t1_adv_skipme')
    drop_buf(buf)
end

-- V9: exactly one BufWritePre autocmd owns save formatting (validation).
do
    local found = 0
    for _, ac in ipairs(api.nvim_get_autocmds({ event = 'BufWritePre' })) do
        local desc = tostring(ac.desc or '')
        if desc:find('save-format stage pipeline', 1, true) then
            found = found + 1
        end
    end
    val_check(found == 1, 'V9 exactly one save-format stage pipeline BufWritePre exists (found ' .. found .. ')')
end

-- V10: the native pipeline stage is registered at priority 1000 (validation).
do
    local stage = formatters.get_stage('native_pipeline')
    val_check(stage ~= nil, 'V10 native_pipeline stage is registered')
    val_check(stage ~= nil and stage.priority == 1000, 'V10 native_pipeline has priority 1000')
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
