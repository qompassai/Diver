-- tests/lua/ui_facade.lua
-- Balanced suite for the config.ui shared-interface refactor: exactly half
-- adversarial and half validation (6 checks each, 12 total).
-- Run from the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/ui_facade.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $UI_FACADE_REPORT (default /tmp/ui_facade_report.txt).
local report_path = os.getenv('UI_FACADE_REPORT') or '/tmp/ui_facade_report.txt'
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

-- Validation: facade ----------------------------------------------------
local ui = require('config.ui')
val_check(ui.float == require('config.ui.float'), 'facade .float resolves to config.ui.float')
val_check(type(ui.nerd) == 'table' and #ui.nerd > 1000, 'facade .nerd exposes the glyph data table')
val_check(ui.no_such_submodule == nil, 'facade returns nil for unknown keys')
val_check(type(ui.ui_config) == 'function', 'boot entry point is ui_config (config/* convention)')

-- Validation: float instance API ----------------------------------------
local float = require('config.ui.float')
local inst = float.setup({ cmd = { 'true' }, focus = false, start_in_insert = false })
val_check(
    type(inst.open) == 'function'
        and type(inst.close) == 'function'
        and type(inst.toggle) == 'function'
        and type(inst.is_open) == 'function',
    'float instance exposes open/close/toggle/is_open'
)

local opened = inst.open({ id = 'uitest1' })
local open_seen = inst.is_open('uitest1')
local closed = inst.close('uitest1')
local closed_seen = not inst.is_open('uitest1')
val_check(
    opened == true and open_seen and closed == true and closed_seen,
    'float open -> is_open -> close -> is_open cycle behaves'
)

-- Adversarial ------------------------------------------------------------
local bad_open, bad_open_err = float.open({ id = {} })
adv_check(bad_open == nil and bad_open_err ~= nil, 'module open() rejects non-string id')
adv_check(float.close('no-such-float-xyz') == false, 'module close() on unknown id returns false')
local bad_toggle, bad_toggle_err = float.toggle({ id = {} })
adv_check(bad_toggle == nil and bad_toggle_err ~= nil, 'module toggle() rejects non-string id')
adv_check(ui.setup == nil, 'old M.setup entry point is gone')
adv_check(float.is_open('no-such-float-xyz') == false, 'is_open() on unknown id is false')
local colors = require('config.ui.colors')
adv_check(
    type(colors) == 'table' and type(colors.setup) == 'function',
    'colors requires cleanly and keeps an explicit setup()'
)

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
