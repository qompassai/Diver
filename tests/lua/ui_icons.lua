-- tests/lua/ui_icons.lua
-- Balanced suite for the config.ui.icons setup-path repair: exactly half
-- adversarial and half validation (6 checks each, 12 total).
-- Covers the un-inverted version gate plus the three latent setup bugs it
-- masked (undefined M.check_type, phantom M.init_cache call, undefined
-- M.default_config). Run from the repo root with the FULL config
-- (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/ui_icons.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $UI_ICONS_REPORT (default /tmp/ui_icons_report.txt).
local report_path = os.getenv('UI_ICONS_REPORT') or '/tmp/ui_icons_report.txt'
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

local icons = require('config.ui.icons')

-- Validation ------------------------------------------------------------
val_check(pcall(icons.setup), 'setup() runs without error on nvim >= 0.10')
val_check(_G.Icons == icons, '_G.Icons points at the module after setup')
val_check(
    icons.config.style == 'glyph' and type(icons.config.use_file_extension) == 'function',
    'defaults applied from M.config'
)
val_check(pcall(icons.setup, nil), 'setup(nil) works (boot calls it with no args)')
val_check(pcall(icons.setup, { style = 'glyph' }), 'setup() accepts config overrides')
icons.setup()
icons.setup()
local autocmds = vim.api.nvim_get_autocmds({ group = 'Icons' })
val_check(#autocmds == 1, 'repeated setup() keeps exactly one Icons autocmd')
icons.setup({ style = 'ascii' })
icons.setup(nil)
val_check(icons.config.style == 'glyph', 'setup(nil) after overrides restores factory defaults')

-- Adversarial -----------------------------------------------------------
adv_check(not pcall(icons.setup, { style = 123 }), 'setup() rejects non-string style')
adv_check(not pcall(icons.setup, 'nope'), 'setup() rejects non-table config')
adv_check(not pcall(icons.setup, { use_file_extension = 'yes' }), 'setup() rejects non-function use_file_extension')
adv_check(not pcall(icons.check_type, 's', 1, 'string'), 'check_type rejects wrong type')
adv_check(not pcall(icons.check_type, 's', nil, 'string'), 'check_type rejects nil when not optional')
adv_check(pcall(icons.check_type, 's', nil, 'string', true), 'check_type allows nil when optional')
icons.setup({ style = 'ascii' })
adv_check(icons.default_config.style == 'glyph', 'overrides never mutate M.default_config')

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
