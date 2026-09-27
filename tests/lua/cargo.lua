-- tests/lua/cargo.lua
-- Balanced suite for the dev/cargo module: exactly half adversarial and
-- half validation (7 checks each, 14 total). Run from the repo root with
-- the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/cargo.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $CARGO_REPORT (default /tmp/cargo_report.txt).
-- The pure parser is exercised with fixture strings; no real cargo build
-- is ever spawned (cargo --version only, when present).
local report_path = os.getenv('CARGO_REPORT') or '/tmp/cargo_report.txt'
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

local cargo = require('dev.cargo')

-- The lazy stubs from lua/utils/init.lua must be live after a full boot.
local stubs_live = vim.fn.exists(':Cargo') == 2
    and vim.fn.exists(':CargoDocs') == 2
    and vim.fn.exists(':CargoValidate') == 2
    and vim.fn.exists(':CargoUpdateCheck') == 2
-- Remove the stubs so setup() can register the real commands (this is
-- what each stub does to itself on first use).
for _, name in ipairs({ 'Cargo', 'CargoDocs', 'CargoValidate', 'CargoUpdateCheck' }) do
    if vim.fn.exists(':' .. name) == 2 then
        vim.cmd('delcommand ' .. name)
    end
end

local EXPECTED_COMMANDS = { 'Cargo', 'CargoDocs', 'CargoValidate', 'CargoUpdateCheck' }

local function user_commands()
    return vim.api.nvim_get_commands({})
end

local ERROR_FIXTURE = [[
error[E0308]: mismatched types
  --> src/main.rs:10:5
   |
10 |     let x: i32 = "hello";
   |                  ^^^^^^^ expected `i32`, found `&str`
   |
]]

local WARNING_FIXTURE = [[
warning: unused variable: `x`
  --> src/lib.rs:3:9
   |
3  |     let x = 1;
   |         ^ help: prefix it with an underscore: `_x`
   |
error: aborting due to 1 previous error
]]

local MULTI_FIXTURE = [[
error[E0599]: no method named `foo` found for struct `Bar`
  --> src/a.rs:1:1
   |
1  | bar.foo();
   |     ^^^ method not found
   |
error: internal compiler error: unexpected panic
thread 'rustc' panicked at compiler/rustc_middle/src/ty/mod.rs:123:5:
explicit panic
]]

-- Validation ------------------------------------------------------------
do
    cargo.setup()
    local commands = user_commands()
    local all_present = true
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if commands[name] == nil then
            all_present = false
        end
    end
    local twice_ok = pcall(cargo.setup) and pcall(cargo.setup)
    local count = 0
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if user_commands()[name] ~= nil then
            count = count + 1
        end
    end
    val_check(
        stubs_live and all_present and twice_ok and count == 4,
        'lazy :Cargo* stubs live after boot; setup registers 4 commands; idempotent, still exactly 4'
    )
end

do
    local explicit = true
    for key, _ in pairs(cargo.default_config) do
        if cargo.config[key] == nil then
            explicit = false
        end
    end
    cargo.setup({ float_width = 80 })
    local override_ok = cargo.config.float_width == 80
    cargo.setup()
    local restored = cargo.config.float_width == 100
    local defaults_intact = cargo.default_config.float_width == 100 and cargo.default_config.populate_quickfix == true
    val_check(
        explicit and override_ok and restored and defaults_intact,
        'config fully explicit; overrides apply, nil restores, default_config never mutated'
    )
end

do
    local expected = {
        b = { 'build' },
        c = { 'check' },
        r = { 'run' },
        rr = { 'run', '--release' },
        t = { 'test' },
        ['zig-x86_64-r'] = { 'zigbuild', '--release', '--target', 'x86_64-unknown-linux-gnu' },
        ['zig-aarch64-r'] = { 'zigbuild', '--release', '--target', 'aarch64-unknown-linux-gnu' },
        ['zig-aarch64-t'] = { 'zigbuild', 'test', '--target', 'aarch64-unknown-linux-gnu' },
    }
    local match = true
    local order_ok = #cargo.config.alias_order == 8
    for name, words in pairs(expected) do
        local actual = cargo.aliases[name]
        if actual == nil or #actual ~= #words then
            match = false
        else
            for index, word in ipairs(words) do
                if actual[index] ~= word then
                    match = false
                end
            end
        end
    end
    local extra = 0
    for _ in pairs(cargo.aliases) do
        extra = extra + 1
    end
    val_check(
        match and order_ok and extra == 8,
        'alias table mirrors the cargo config: 8 aliases with exact expansions, alias_order covers all 8'
    )
end

do
    local items, counts = cargo.parse_rustc_output(ERROR_FIXTURE)
    local item = items ~= nil and items[1] or nil
    val_check(
        items ~= nil
            and #items == 1
            and item.filename == 'src/main.rs'
            and item.lnum == 10
            and item.col == 5
            and item.type == 'E'
            and item.text == 'E0308 mismatched types'
            and counts.errors == 1
            and counts.warnings == 0
            and counts.ices == 0,
        'error[E0308] fixture: 1 item src/main.rs:10:5 type E text "E0308 mismatched types"; counts 1/0/0'
    )
end

do
    local items, counts = cargo.parse_rustc_output(WARNING_FIXTURE .. MULTI_FIXTURE)
    local warn_item = items ~= nil and items[1] or nil
    val_check(
        items ~= nil
            and #items == 2
            and warn_item.type == 'W'
            and warn_item.filename == 'src/lib.rs'
            and warn_item.lnum == 3
            and warn_item.col == 9
            and warn_item.text == 'unused variable: `x`'
            and items[2].type == 'E'
            and items[2].text:find('E0599', 1, true) ~= nil
            and counts.errors == 1
            and counts.warnings == 1
            and counts.ices == 1,
        'warning+multi fixture: 2 items (W lib.rs:3:9, E E0599); aborting line uncounted; ICE counted once'
    )
end

do
    local z_items = cargo.complete('z', '', 0)
    local z_words = {}
    local z_menu_ok = true
    for _, item in ipairs(z_items) do
        z_words[item.word] = item.menu
    end
    for _, name in ipairs({ 'zig-x86_64-r', 'zig-aarch64-r', 'zig-aarch64-t' }) do
        local menu = z_words[name]
        if menu == nil or menu:find(cargo.aliases[name][1], 1, true) == nil then
            z_menu_ok = false
        end
    end
    local all_items = cargo.complete('', '', 0)
    local alias_hits = 0
    for _, item in ipairs(all_items) do
        if item.menu:sub(1, 7) == '[alias]' then
            alias_hits = alias_hits + 1
        end
    end
    local empty_lead_ok = #z_items == 3
    val_check(
        z_menu_ok and empty_lead_ok and alias_hits == 8,
        "complete('z'): 3 zig aliases with expansion preview; complete(''): all 8 aliases listed"
    )
end

do
    vim.fn.chdir('/tmp')
    local ok, root, err = pcall(cargo.workspace_root)
    val_check(
        ok and root == nil and type(err) == 'string',
        'workspace_root in /tmp (no Cargo.toml): returns nil+err, never throws'
    )
end

-- Adversarial -----------------------------------------------------------
do
    local cases = { nil, 123, true, {} }
    local all_ok = true
    for _, bad in ipairs(cases) do
        local ok, items, err = pcall(cargo.parse_rustc_output, bad)
        if not (ok and items == nil and type(err) == 'string') then
            all_ok = false
        end
    end
    adv_check(all_ok, 'parse_rustc_output(nil/123/true/{}) returns nil+err, never throws')
end

do
    local items1, counts1 = cargo.parse_rustc_output('')
    local items2 = cargo.parse_rustc_output('   \n\n  \n')
    adv_check(
        items1 ~= nil
            and #items1 == 0
            and counts1.errors == 0
            and counts1.warnings == 0
            and counts1.ices == 0
            and items2 ~= nil
            and #items2 == 0,
        'empty and whitespace-only input: 0 items, 0/0/0 counts'
    )
end

do
    local malformed = [[
this is not compiler output
  --> src/main.rs
  --> src/main.rs:abc:def
  --> :10:5
error without a colon
warning without a colon
error[E]: empty code
  --> src/main.rs:10:5: trailing junk colon breaks the shape
]]
    local items, counts = cargo.parse_rustc_output(malformed)
    adv_check(
        items ~= nil and #items == 0 and counts.errors == 0 and counts.warnings == 0,
        'malformed lines (bare -->, non-numeric coords, colon-less headers) yield 0 items'
    )
end

do
    local stray = '  --> src/main.rs:10:5\n'
    local items, counts = cargo.parse_rustc_output(stray)
    local two_locs = [[
error[E0308]: mismatched types
  --> src/first.rs:1:1
  --> src/second.rs:2:2
]]
    local items2, counts2 = cargo.parse_rustc_output(two_locs)
    adv_check(
        items ~= nil
            and #items == 0
            and counts.errors == 0
            and items2 ~= nil
            and #items2 == 1
            and items2[1].filename == 'src/first.rs'
            and counts2.errors == 1,
        'stray --> with no header ignored; second --> for one diagnostic ignored (first wins)'
    )
end

do
    local wins_before = #vim.api.nvim_list_wins()
    local cases = {
        nil,
        {},
        { subcommand = 123 },
        { subcommand = '' },
        { subcommand = 't', args = 'x' },
        { subcommand = 't', args = { 'ok', 42 } },
        { subcommand = 't', on_exit = 'x' },
    }
    local all_ok = true
    for _, bad in ipairs(cases) do
        local ok, info, err = pcall(cargo.run, bad)
        if not (ok and info == nil and type(err) == 'string') then
            all_ok = false
        end
    end
    local wins_after = #vim.api.nvim_list_wins()
    -- Missing binary: deterministic via a bogus cargo_bin override, so
    -- this holds whether or not cargo is installed on the test machine.
    cargo.setup({ cargo_bin = 'definitely-not-cargo-xyz' })
    local ok2, info2, err2 = pcall(cargo.run, { subcommand = 't' })
    local missing_ok = ok2
        and info2 == nil
        and type(err2) == 'string'
        and err2:find('not found on PATH', 1, true) ~= nil
    cargo.setup() -- restore the real config
    local wins_final = #vim.api.nvim_list_wins()
    local jobs_empty = next(cargo.jobs) == nil
    adv_check(
        all_ok and missing_ok and jobs_empty and wins_after == wins_before and wins_final == wins_before,
        'run(nil/{}/bad subcommand/bad args/bad on_exit) returns nil+err, spawns nothing, never throws; '
            .. 'missing cargo binary also returns nil+err with no window or job leak'
    )
end

do
    local chunk = 'error[E0308]: mismatched types\n  --> src/main.rs:10:5\n'
    local big = string.rep(chunk, 20000) -- ~1.2 MB, far over the parse budget
    local ok, items, counts = pcall(cargo.parse_rustc_output, big)
    adv_check(
        ok and items ~= nil and #items <= 4000 and counts.errors == #items,
        'oversized input terminates: items bounded at 4000, counts consistent'
    )
end

adv_check(
    not pcall(cargo.setup, 'nope')
        and not pcall(cargo.setup, { float_width = 'wide' })
        and not pcall(cargo.setup, { alias_order = { 'nope' } }),
    'setup() rejects a non-table config, a mistyped float_width, and an unknown alias_order entry'
)

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
