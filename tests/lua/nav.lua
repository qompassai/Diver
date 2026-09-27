-- tests/lua/nav.lua
-- Balanced suite for the nav directory-ring module: exactly half
-- adversarial and half validation (7 checks each, 14 total). Run from
-- the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/nav.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $NAV_REPORT (default /tmp/nav_report.txt).
-- The suite only touches /tmp fixture dirs and its own test ring file
-- under stdpath('data')/nav/ (cleaned up at the end).
local report_path = os.getenv('NAV_REPORT') or '/tmp/nav_report.txt'
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

local nav = require('nav')

local fixture_root = '/tmp/nav_fixtures'
local dir_a = fixture_root .. '/a'
local dir_b = fixture_root .. '/b'
local dir_c = fixture_root .. '/c'
local dir_d = fixture_root .. '/d'
vim.fn.delete(fixture_root, 'rf')
for _, dir in ipairs({ dir_a, dir_b, dir_c, dir_d }) do
    assert(vim.fn.mkdir(dir, 'p') == 1, 'cannot create fixture dir ' .. dir)
end

local RING_TEST_FILE = 'nav_test_ring.json'

local function ring_file_path()
    return vim.fs.joinpath(vim.fn.stdpath('data'), 'nav', RING_TEST_FILE)
end

local function write_ring_file(text)
    local path = ring_file_path()
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    local f = io.open(path, 'w')
    assert(f ~= nil, 'cannot write test ring file')
    f:write(text)
    f:close()
end

local function work_config(extra)
    return vim.tbl_extend('force', {
        cd_scope = 'window',
        keymaps_enabled = true,
        persist_enabled = true,
        ring_file_name = RING_TEST_FILE,
        ring_size_max = 32,
    }, extra or {})
end

local EXPECTED_COMMANDS = {
    'DirPush',
    'DirNext',
    'DirPrev',
    'DirReset',
    'DirList',
    'NavDocs',
    'NavValidate',
    'NavUpdateCheck',
}

local function user_commands()
    return vim.api.nvim_get_commands({})
end

-- Validation ------------------------------------------------------------
do
    nav.setup(work_config())
    local commands = user_commands()
    local all_present = true
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if commands[name] == nil then
            all_present = false
        end
    end
    local twice_ok = pcall(nav.setup, work_config()) and pcall(nav.setup, work_config())
    local count = 0
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if user_commands()[name] ~= nil then
            count = count + 1
        end
    end
    val_check(
        all_present and twice_ok and count == 8,
        'all 8 :Dir*/:Nav* commands registered; setup() idempotent, still exactly 8'
    )
end

do
    local explicit = true
    for key, _ in pairs(nav.default_config) do
        if nav.config[key] == nil then
            explicit = false
        end
    end
    nav.setup(work_config({ ring_size_max = 3 }))
    local override_ok = nav.config.ring_size_max == 3
    nav.setup(work_config())
    local restored = nav.config.ring_size_max == 32
    local defaults_intact = nav.default_config.ring_size_max == 32 and nav.default_config.keymaps_enabled == true
    val_check(
        explicit and override_ok and restored and defaults_intact,
        'config fully explicit; overrides apply, nil restores, default_config never mutated'
    )
end

do
    nav.setup(work_config())
    nav.reset()
    local ok_a = nav.push(dir_a)
    local ok_b = nav.push(dir_b)
    local ok_c = nav.push(dir_c)
    local entries = nav.entries()
    local current_is_c = nav.current() == dir_c and nav.current_index() == 3
    local prev1 = nav.prev()
    local prev2 = nav.prev()
    local prev3 = nav.prev() -- wraps a -> c
    local next1 = nav.next() -- wraps c -> a
    val_check(
        ok_a
            and ok_b
            and ok_c
            and #entries == 3
            and entries[1] == dir_a
            and entries[2] == dir_b
            and entries[3] == dir_c
            and current_is_c
            and prev1 == dir_b
            and prev2 == dir_a
            and prev3 == dir_c
            and next1 == dir_a
            and nav.current_index() == 1,
        'push a,b,c keeps order, current=c; prev cycles b,a then wraps to c; next wraps to a'
    )
end

do
    nav.reset()
    nav.push(dir_a)
    nav.push(dir_b)
    nav.push(dir_c)
    local before = nav.size()
    local ok = nav.push(dir_b) -- duplicate: no new entry, becomes current
    val_check(
        ok and nav.size() == before and nav.current() == dir_b and nav.current_index() == 2,
        'push dedupes: re-pushing b keeps size 3 and makes b current'
    )
end

do
    nav.setup(work_config({ ring_size_max = 3 }))
    nav.reset()
    nav.push(dir_a)
    nav.push(dir_b)
    nav.push(dir_c)
    nav.push(dir_d) -- over capacity: oldest (a) dropped
    local entries = nav.entries()
    val_check(
        nav.size() == 3
            and entries[1] == dir_b
            and entries[2] == dir_c
            and entries[3] == dir_d
            and nav.current() == dir_d,
        'ring_size_max=3 honored: pushing d drops oldest a, current=d'
    )
    nav.setup(work_config())
end

do
    nav.reset()
    local ok = nav.reset()
    local next_ok = pcall(nav.next)
    local dir, err = nav.next()
    val_check(
        ok
            and nav.size() == 0
            and nav.current() == nil
            and nav.current_index() == 0
            and next_ok
            and dir == nil
            and type(err) == 'string',
        'reset clears the ring; next() on empty returns nil+err, never throws'
    )
end

do
    nav.reset()
    nav.push(dir_a)
    nav.push(dir_b)
    nav.push(dir_c)
    local picked_cwd
    nav.setup(work_config({
        select_impl = function(items, opts, on_choice)
            assert(#items == 3, 'picker got ' .. #items .. ' items, expected 3')
            assert(opts.prompt == nav.config.picker_prompt, 'picker prompt mismatch')
            on_choice(items[2], 2)
        end,
    }))
    local list_ok = pcall(function()
        vim.cmd('DirList')
    end)
    picked_cwd = vim.fn.getcwd()
    local picked_index = nav.current_index()
    nav.setup(work_config()) -- restore the real picker seam
    val_check(
        list_ok and picked_cwd == dir_b and picked_index == 2,
        'DirList picker seam: choosing entry 2 jumps (lcd) to b and sets the index'
    )
end

-- Adversarial -----------------------------------------------------------
do
    nav.reset()
    nav.push(dir_a)
    local size_before = nav.size()
    local ok, err = nav.push('/tmp/nav_no_such_dir_xyz')
    adv_check(
        not ok and type(err) == 'string' and nav.size() == size_before,
        'push of a missing path fails with an error and leaves the ring untouched'
    )
end

do
    nav.reset()
    local results = {}
    for _, bad in ipairs({ nil, 123, '', '   ' }) do
        local ok = pcall(nav.push, bad)
        results[#results + 1] = (ok == true)
        local push_ok, push_err = nav.push(bad)
        results[#results + 1] = push_ok == false
        results[#results + 1] = type(push_err) == 'string'
    end
    local all_ok = true
    for _, flag in ipairs(results) do
        if not flag then
            all_ok = false
        end
    end
    adv_check(all_ok and nav.size() == 0, 'push(nil/123/""/blank) never throws, always returns false+err')
end

do
    nav.reset()
    nav.push(dir_a)
    local cases = { 0, 99, -1, 1.5, 'two' }
    local all_ok = true
    for _, bad in ipairs(cases) do
        local ok, dir, err = pcall(nav.jump, bad)
        if not (ok and dir == nil and type(err) == 'string') then
            all_ok = false
        end
    end
    adv_check(all_ok and nav.current_index() == 1, 'jump(0/99/-1/1.5/"two") returns nil+err, never throws')
end

do
    nav.setup(work_config({ persist_enabled = false }))
    local ok, err = nav.save_ring()
    local ok2, err2 = nav.restore_ring()
    nav.setup(work_config())
    local save_refused = not ok and type(err) == 'string' and err:find('disabled', 1, true) ~= nil
    local restore_refused = not ok2 and type(err2) == 'string'
    adv_check(
        save_refused and restore_refused,
        'save_ring/restore_ring refuse with an error when persist_enabled=false'
    )
end

do
    write_ring_file('{ this is not json !!!')
    local ok, result = pcall(nav.restore_ring)
    local version, version_err = nav.ring_file_version()
    adv_check(
        ok and not result and type(version_err) == 'string' and version == nil,
        'corrupt ring JSON: restore_ring returns false+err (no throw); version read reports the same'
    )
end

do
    write_ring_file(vim.json.encode({
        version = '1.0.0',
        dirs = { dir_a, 42, '', dir_b, { nested = true } },
    }))
    local ok, count = nav.restore_ring()
    local entries = nav.entries()
    adv_check(
        ok and count == 2 and #entries == 2 and entries[1] == dir_a and entries[2] == dir_b and nav.current() == dir_a,
        'restore drops malformed entries (42, "", table), keeps the 2 valid dirs, index resets to 1'
    )
end

adv_check(
    not pcall(nav.setup, 'nope') and not pcall(nav.setup, work_config({ ring_size_max = 'many' })),
    'setup() rejects a non-table config and a mistyped ring_size_max'
)

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
os.remove(ring_file_path())
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
