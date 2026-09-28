-- Tests for the upstream-faithful rdbg rework in lua/dap/ruby.lua, plus
-- the lua/dap/backend.lua transport classification of rdbg.
-- Run from the repo root:
--     lua tests/lua/dap_ruby_rdbg.lua
--
-- Harness follows tests/lua/research_docs_make_header.lua (plain-lua
-- `check` counting, minimal vim stub since `vim` is nil outside Neovim).
-- Exactly 50% validation / 50% adversarial: 6 + 6 cases.
local here = debug.getinfo(1, 'S').source:sub(2)
local root = here:match('^(.*)/tests/lua/') or '.'
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

-- Toggle for the bundler validation case.
local GEMFILE_PRESENT = false

_G.vim = {
    api = {},
    fn = {
        executable = function(path)
            return path == '/usr/bin/rdbg' and 1 or 0
        end,
        exepath = function()
            return ''
        end,
        filereadable = function(path)
            if GEMFILE_PRESENT and path:sub(-8) == '/Gemfile' then
                return 1
            end

            return 0
        end,
        fnamemodify = function(path)
            return path
        end,
        getcwd = function()
            return '/proj'
        end,
        has = function()
            return 0
        end,
        input = function()
            return ''
        end,
    },
    fs = {
        normalize = function(path)
            return path
        end,
        dirname = function(path)
            return path:match('^(.*)/[^/]*$') or ''
        end,
        root = function()
            return nil
        end,
    },
    uv = {
        fs_stat = function()
            return nil
        end,
    },
    env = {},
    g = {},
    log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
    notify = function() end,
    schedule = function() end,
    -- Stubbed rdbg utilities: gen-sockpath works, everything else reports
    -- an error. No real rdbg is ever spawned in these tests.
    system = function(argv, opts, on_exit)
        local result

        if argv[2] == '--util=gen-sockpath' then
            result = { code = 0, stdout = '/tmp/rdbg-test-9.sock\n', stderr = '' }
        else
            result = { code = 1, stdout = '', stderr = 'unexpected: ' .. tostring(argv[2]) }
        end

        return {
            wait = function()
                return result
            end,
            kill = function() end,
        }
    end,
    tbl_extend = function(_, ...)
        local out = {}

        for _, t in ipairs({ ... }) do
            for k, v in pairs(t) do
                out[k] = v
            end
        end

        return out
    end,
    wait = function()
        return false
    end,
}

local ruby = require('dap.ruby')
local backend = require('dap.backend')

local passed = 0
local total = 0

local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

-- ##################################################################
-- Validation: 6 cases
-- ##################################################################

-- 1: argument splitting understands quotes and backslash escapes.
do
    local args = ruby.parse_args([[foo.rb --name "hello world" --path 'a b' --esc x\ y]])
    check(args ~= nil, 'parse_args returned nil')
    check(#args == 7, 'parse_args count, want 7 got ' .. #args)
    check(args[3] == 'hello world', 'double-quoted arg stays one word')
    check(args[5] == 'a b', 'single-quoted arg stays one word')
    check(args[7] == 'x y', 'escaped space stays one word')
end

-- 2: default target is `ruby <script> <args>`.
do
    local argv, err = ruby.target_argv({ script = '/proj/foo.rb' }, '/proj')
    check(argv ~= nil, 'target_argv returned nil: ' .. tostring(err))
    check(#argv == 2 and argv[1] == 'ruby' and argv[2] == '/proj/foo.rb', 'default ruby target')
end

-- 3: bundler mode becomes `bundle exec ruby <script>`.
do
    GEMFILE_PRESENT = true
    local argv, err = ruby.target_argv({ script = '/proj/foo.rb' }, '/proj')
    GEMFILE_PRESENT = false
    check(argv ~= nil, 'bundler target_argv returned nil: ' .. tostring(err))
    check(
        #argv == 4 and argv[1] == 'bundle' and argv[2] == 'exec' and argv[3] == 'ruby',
        'bundler target, got: ' .. table.concat(argv or {}, ' ')
    )
end

-- 4: explicit commands are used as-is, with args appended.
do
    local argv, err =
        ruby.target_argv({ command = 'rspec', script = '/proj/spec/a_spec.rb', args = { '--format', 'doc' } }, '/proj')
    check(argv ~= nil, 'command target_argv returned nil: ' .. tostring(err))
    check(
        #argv == 4 and argv[1] == 'rspec' and argv[3] == '--format' and argv[4] == 'doc',
        'explicit command target, got: ' .. table.concat(argv or {}, ' ')
    )
end

-- 5: debug_port parses like upstream: digits, host:port, else socket path.
do
    local tcp = ruby.parse_debug_port('12345')
    check(tcp.mode == 'tcp' and tcp.host == 'localhost' and tcp.port == 12345, 'digits mean loopback TCP')

    local remote = ruby.parse_debug_port('db.internal:2345')
    check(remote.mode == 'tcp' and remote.host == 'db.internal' and remote.port == 2345, 'host:port means TCP')

    local unix = ruby.parse_debug_port('/tmp/rdbg.sock')
    check(unix.mode == 'unix' and unix.sock_path == '/tmp/rdbg.sock', 'anything else is a socket path')
end

-- 6: launch_plan builds the upstream argv with the unix socket default.
do
    local plan, err = ruby.launch_plan('/usr/bin/rdbg', { script = '/proj/foo.rb' }, '/proj')
    check(plan ~= nil, 'launch_plan returned nil: ' .. tostring(err))
    check(plan.mode == 'unix', 'default launch mode is unix, got ' .. tostring(plan.mode))

    local argv = plan.argv
    check(
        #argv == 8
            and argv[1] == '/usr/bin/rdbg'
            and argv[2] == '--command'
            and argv[3] == '--open'
            and argv[4] == '--stop-at-load',
        'rdbg open flags, got: ' .. table.concat(argv, ' ')
    )
    check(argv[5] == '--sock-path=/tmp/rdbg-test-9.sock', 'sock path flag, got: ' .. tostring(argv[5]))
    check(argv[6] == '--' and argv[7] == 'ruby' and argv[8] == '/proj/foo.rb', 'target argv follows the -- separator')
end

-- ##################################################################
-- Adversarial: 6 cases
-- ##################################################################

-- 7: malformed argument strings are rejected, not half-parsed.
do
    local unterminated, err1 = ruby.parse_args([[foo "bar]])
    check(
        unterminated == nil and type(err1) == 'string' and err1:find('unterminated', 1, true) ~= nil,
        'unterminated quote rejected, got: ' .. tostring(err1)
    )

    local dangling, err2 = ruby.parse_args([[foo bar\]])
    check(
        dangling == nil and type(err2) == 'string' and err2:find('incomplete escape', 1, true) ~= nil,
        'trailing escape rejected, got: ' .. tostring(err2)
    )
end

-- 8: config.args must be a list of strings.
do
    local r1, e1 = ruby.target_argv({ script = '/proj/foo.rb', args = '--foo' }, '/proj')
    check(r1 == nil and type(e1) == 'string', 'non-table args rejected, got: ' .. tostring(e1))

    local r2, e2 = ruby.target_argv({ script = '/proj/foo.rb', args = { 42 } }, '/proj')
    check(r2 == nil and type(e2) == 'string', 'non-string arg rejected, got: ' .. tostring(e2))
end

-- 9: the target script is mandatory.
do
    local r1, e1 = ruby.target_argv({}, '/proj')
    check(r1 == nil and type(e1) == 'string', 'missing script rejected, got: ' .. tostring(e1))

    local r2, e2 = ruby.target_argv({ script = '' }, '/proj')
    check(r2 == nil and type(e2) == 'string', 'empty script rejected, got: ' .. tostring(e2))
end

-- 10: debug_port rejects empties, out-of-range ports, and non-strings.
do
    local r1 = ruby.parse_debug_port('')
    check(r1 == nil, 'empty debug_port rejected')

    local r2 = ruby.parse_debug_port('99999')
    check(r2 == nil, 'out-of-range port rejected')

    local r3 = ruby.parse_debug_port(12345)
    check(r3 == nil, 'non-string debug_port rejected')
end

-- 11: the manual start/stop lifecycle is gone; DAP owns the socket.
do
    check(ruby.commands.RubyRdbgStart == nil, 'RubyRdbgStart command removed')
    check(ruby.commands.RubyRdbgStop == nil, 'RubyRdbgStop command removed')
    check(ruby.commands.RubyCheck ~= nil, 'RubyCheck command kept')
    check(type(ruby.adapter.enrich_config) == 'function', 'adapter resolves per session via enrich_config')
    check(ruby.adapter.type == 'pipe', 'adapter placeholder is a unix-socket pipe')
end

-- 12: nonstop contract matches the debug gem, and rdbg is not stdio.
do
    local launches = 0
    local attaches = 0

    for _, config in ipairs(ruby.configurations.ruby) do
        if config.request == 'launch' then
            launches = launches + 1
            check(config.nonstop == true, 'launch hardcodes nonstop: ' .. tostring(config.name))
        elseif config.request == 'attach' then
            attaches = attaches + 1
            check(config.nonstop == nil, 'attach leaves nonstop to the request')
        end
    end

    check(launches == 3, 'three launch configurations, got ' .. launches)
    check(attaches == 1, 'one attach configuration, got ' .. attaches)

    local unix_ids = {}

    for _, entry in ipairs(backend.backends_for_transport('unix')) do
        unix_ids[entry.id] = true
    end

    check(unix_ids['rdbg'] == true, 'rdbg classified as unix transport')

    local stdio_ids = {}

    for _, entry in ipairs(backend.backends_for_transport('stdio')) do
        stdio_ids[entry.id] = true
    end

    check(stdio_ids['rdbg'] ~= true, 'rdbg no longer classified as stdio')
end

assert(total == 41, 'expected 41 checks, got ' .. total)
print(('[dap_ruby_rdbg] PASS: %d/%d (6 validation + 6 adversarial)'):format(passed, total))
