-- tests/lua/git.lua
-- Balanced suite for the git + git-xet module: exactly half adversarial
-- and half validation (7 checks each, 14 total). Run from the repo root
-- with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/git.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $GIT_REPORT (default /tmp/git_report.txt).
-- This machine has git 2.43.0 + gpg; pass, git-lfs and git-xet are
-- absent, so the suite asserts the graceful "unavailable" paths for them.
local report_path = os.getenv('GIT_REPORT') or '/tmp/git_report.txt'
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

local git = require('git')
local xet = require('git.xet')

local EXPECTED_COMMANDS = {
    'GitLog',
    'Gcommit',
    'Ge',
    'Gpush',
    'Gpull',
    'GitBlame',
    'GitDocs',
    'GitValidate',
    'GitUpdateCheck',
    'GitXetInstall',
    'GitXetTrack',
    'GitXetStatus',
}

local function user_commands()
    return vim.api.nvim_get_commands({})
end

local function check_by_name(checks, name)
    for _, check in ipairs(checks) do
        if check.name == name then
            return check
        end
    end
    return nil
end

-- Validation ------------------------------------------------------------
do
    local commands = user_commands()
    local all_present = true
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if commands[name] == nil then
            all_present = false
        end
    end
    val_check(all_present, 'all 12 :Git* commands registered by setup()')
end

do
    local twice_ok = pcall(git.setup) and pcall(git.setup)
    local commands = user_commands()
    local count = 0
    for _, name in ipairs(EXPECTED_COMMANDS) do
        if commands[name] ~= nil then
            count = count + 1
        end
    end
    val_check(twice_ok and count == 12, 'setup() is idempotent: twice without error, still exactly the 12 commands')
end

do
    git.setup()
    local explicit = true
    for key, _ in pairs(git.default_config) do
        if git.config[key] == nil then
            explicit = false
        end
    end
    git.setup({ log_lines_max = 50 })
    local override_ok = git.config.log_lines_max == 50
    git.setup(nil)
    local restored = git.config.log_lines_max == 200
    local defaults_intact = git.default_config.log_lines_max == 200
    val_check(
        explicit and override_ok and restored and defaults_intact,
        'config fully explicit; overrides apply, nil restores defaults, default_config never mutated'
    )
end

do
    local checks = git.checks()
    local git_check = check_by_name(checks, 'git')
    local xet_check = check_by_name(checks, 'git-xet')
    local gpg_check = check_by_name(checks, 'gpg')
    local pass_check = check_by_name(checks, 'pass')
    local repo_check = check_by_name(checks, 'repo')
    val_check(
        git_check ~= nil
            and git_check.status == 'ok'
            and xet_check ~= nil
            and xet_check.status == 'unavailable'
            and gpg_check ~= nil
            and gpg_check.status == 'ok'
            and pass_check ~= nil
            and pass_check.status == 'unavailable'
            and repo_check ~= nil
            and repo_check.status == 'ok',
        'checks(): git ok, git-xet unavailable, gpg ok, pass unavailable, repo ok'
    )
end

do
    local diff = table.concat({
        'diff --git a/f.lua b/f.lua',
        '@@ -2,0 +2 @@',
        '+added',
        '@@ -5 +5,2 @@',
        '-b',
        '+c',
        '+d',
        '@@ -10,2 +12,0 @@',
        '-old1',
        '-old2',
        '',
    }, '\n')
    local signs = git.parse_signs(diff)
    local expected = {
        { lnum = 2, kind = 'add' },
        { lnum = 5, kind = 'change' },
        { lnum = 6, kind = 'change' },
        { lnum = 12, kind = 'delete' },
    }
    local exact = #signs == #expected
    if exact then
        for index, sign in ipairs(signs) do
            if sign.lnum ~= expected[index].lnum or sign.kind ~= expected[index].kind then
                exact = false
            end
        end
    end
    val_check(exact, 'parse_signs maps add/change/delete hunks to exact signs')
end

val_check(
    xet.transfer_for_remote('git@huggingface.co:user/model.git') == 'xet'
        and xet.transfer_for_remote('https://huggingface.co/user/model') == 'xet'
        and xet.transfer_for_remote('git@github.com:qompassai/diver.git') == 'basic'
        and xet.transfer_for_remote('https://github.com/qompassai/diver.git') == 'basic',
    "transfer_for_remote: HF Hub negotiates 'xet', plain GitHub falls back to 'basic'"
)

do
    local root, root_err = git.repo_root()
    val_check(
        git.in_repo() and root ~= nil and root_err == nil and root:match('diver$') ~= nil,
        'in_repo()/repo_root() detect the diver work tree from cwd'
    )
end

-- Adversarial -----------------------------------------------------------
adv_check(
    not pcall(git.setup, 'nope') and not pcall(git.setup, { log_lines_max = 'many' }),
    'setup() rejects a non-table config and a mistyped option'
)

do
    local ok, signs = pcall(git.parse_signs, 'not a diff\n@@@ broken\n@@ -x +y @@')
    adv_check(ok and type(signs) == 'table' and #signs == 0, 'parse_signs on garbage returns empty, never throws')
end

adv_check(
    xet.transfer_for_remote(nil) == 'basic' and xet.transfer_for_remote('') == 'basic',
    "transfer_for_remote degrades to 'basic' on nil/empty input"
)

do
    local ok, err = git.commit('', {})
    adv_check(
        not ok and type(err) == 'string' and err:find('empty') ~= nil,
        'commit() refuses an empty message before spawning'
    )
end

do
    local ok, err = git.push({ cwd = '/tmp' })
    adv_check(not ok and type(err) == 'string', 'push() refuses outside a git repo with a clear reason')
end

do
    local ok, err = xet.track_pattern('', {})
    adv_check(
        not ok and type(err) == 'string' and err:find('non%-empty') ~= nil,
        'track_pattern() rejects an empty pattern'
    )
end

do
    local function cancelled_select(_, _, _on_choice)
        -- never calls back: simulates the user dismissing the dialog
    end
    local ok_install = pcall(xet.install, cancelled_select)
    local ok_track = pcall(xet.track, cancelled_select)
    adv_check(ok_install and ok_track, 'install()/track() survive a cancelled picker without side effects')
end

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
assert(f ~= nil, 'cannot open report path ' .. report_path)
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
