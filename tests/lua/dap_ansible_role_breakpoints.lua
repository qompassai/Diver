-- Tests for dap.ansible role-entry breakpoint seeding.
-- Run from the repo root:  lua tests/lua/dap_ansible_role_breakpoints.lua
-- Harness follows tests/lua/mcp_server/*_spec.lua (plain-lua `check`
-- counting, minimal vim stub since `vim` is nil outside Neovim) and
-- tests/lua/research_docs_make_header.lua (vim-stub pattern).
-- Exactly 50% validation / 50% adversarial: 12 cases, 6 + 6.
local here = debug.getinfo(1, 'S').source:sub(2)
if here:sub(1, 1) ~= '/' then
    local pwd = io.popen('pwd')
    local cwd = pwd:read('*l')
    pwd:close()
    here = cwd .. '/' .. here
end
local dir = here:match('^(.*)/[^/]*$')
local root = dir:match('^(.*)/tests/lua$')
assert(root ~= nil, 'cannot locate repo root from ' .. dir)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local notified = {}
local bufadd_calls = {}
local bufload_calls = {}
local breakpoint_calls = {}
local next_bufnr = 100

_G.vim = {
    api = {
        nvim_get_current_buf = function()
            return 1
        end,
        nvim_buf_is_valid = function()
            return true
        end,
        nvim_buf_get_name = function()
            return ''
        end,
    },
    fn = {
        expand = function(s)
            return s
        end,
        fnamemodify = function(path, mods)
            if mods == ':p' and path:sub(1, 1) ~= '/' then
                return os.getenv('PWD') .. '/' .. path
            end
            return path
        end,
        filereadable = function(path)
            local handle = io.open(path, 'r')
            if handle == nil then
                return 0
            end
            handle:close()
            return 1
        end,
        bufadd = function(path)
            next_bufnr = next_bufnr + 1
            bufadd_calls[#bufadd_calls + 1] = path
            return next_bufnr
        end,
        bufload = function(bufnr)
            bufload_calls[#bufload_calls + 1] = bufnr
        end,
        getcwd = function()
            return os.getenv('PWD')
        end,
        stdpath = function(what)
            assert(what == 'cache')
            return '/tmp/nvim-cache'
        end,
        exepath = function()
            return ''
        end,
        executable = function()
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
    notify = function(message, level)
        notified[#notified + 1] = { message = message, level = level }
    end,
    trim = function(s)
        return s:match('^%s*(.-)%s*$')
    end,
    schedule = function(fn)
        fn()
    end,
    env = {},
    g = {},
    log = { levels = { TRACE = 0, DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 } },
}

package.preload['dap.breakpoints'] = function()
    return {
        set = function(opts, bufnr, line)
            breakpoint_calls[#breakpoint_calls + 1] = { opts = opts, bufnr = bufnr, line = line }
            return true
        end,
    }
end

local ansible = require('dap.ansible')
assert(type(ansible.seed_role_entry_breakpoints) == 'function', 'seed_role_entry_breakpoints must exist')

local passed = 0
local total = 0
local function check(value, message)
    total = total + 1
    assert(value, message)
    passed = passed + 1
end

local function reset_recorders()
    notified = {}
    bufadd_calls = {}
    bufload_calls = {}
    breakpoint_calls = {}
    next_bufnr = 100
end

local function tmpdir()
    local path = os.tmpname()
    os.remove(path)
    assert(os.execute("mkdir -p '" .. path .. "'"), 'mkdir failed')
    return path
end

local function write_file(path, content)
    local handle = assert(io.open(path, 'w'))
    handle:write(content)
    handle:close()
end

local function make_role(base, role, tasks_content)
    local tasks_dir = base .. '/roles/' .. role .. '/tasks'
    assert(os.execute("mkdir -p '" .. tasks_dir .. "'"), 'mkdir role failed')
    write_file(tasks_dir .. '/main.yml', tasks_content)
end

-- ================= VALIDATION (6) =================

-- 1. Two plain roles: both seeded at their first task lines.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  roles:\n    - web\n    - db\n')
    make_role(base, 'web', '---\n- name: install nginx\n  apt:\n    name: nginx\n')
    make_role(base, 'db', '# comment\n\n- name: install postgres\n  apt:\n    name: postgresql\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 2, 'expected 2 seeded, got ' .. #result.seeded)
    check(result.seeded[1].role == 'web', 'first role: ' .. result.seeded[1].role)
    check(result.seeded[1].line == 2, 'web first task at line 2, got ' .. result.seeded[1].line)
    check(result.seeded[2].role == 'db', 'second role: ' .. result.seeded[2].role)
    check(result.seeded[2].line == 3, 'db first task at line 3, got ' .. result.seeded[2].line)
    check(#result.unresolved == 0, 'expected no unresolved')
    check(#breakpoint_calls == 2, 'expected 2 breakpoint.set calls')
    check(breakpoint_calls[1].line == 2, 'breakpoint call line mismatch')
end

-- 2. Dict role forms (`- { role: x }` and `- role: x`) are parsed.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  roles:\n    - { role: cache }\n    - role: mq\n')
    make_role(base, 'cache', '- name: flush\n  command: true\n')
    make_role(base, 'mq', '- name: start\n  service:\n    name: mq\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 2, 'dict forms seeded: ' .. #result.seeded)
    check(result.seeded[1].role == 'cache', 'role: ' .. result.seeded[1].role)
    check(result.seeded[2].role == 'mq', 'role: ' .. result.seeded[2].role)
end

-- 3. Quoted role names are unquoted before resolution.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', "---\n- hosts: all\n  roles:\n    - 'quoted-role'\n")
    make_role(base, 'quoted-role', '- name: go\n  debug:\n    msg: hi\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 1 and result.seeded[1].role == 'quoted-role', 'quoted role resolved')
    check(result.seeded[1].file == base .. '/roles/quoted-role/tasks/main.yml', 'file: ' .. result.seeded[1].file)
end

-- 4. `---` header, comments and blanks are skipped when finding the task.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  roles:\n    - web\n')
    make_role(base, 'web', '---\n# role docs\n\n# another comment\n\n- name: first real task\n  ping:\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(result.seeded[1].line == 6, 'first task at line 6, got ' .. tostring(result.seeded[1].line))
end

-- 5. Roles from multiple plays are all collected.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: web\n  roles:\n    - a\n- hosts: db\n  roles:\n    - b\n    - c\n')
    make_role(base, 'a', '- name: t\n  ping:\n')
    make_role(base, 'b', '- name: t\n  ping:\n')
    make_role(base, 'c', '- name: t\n  ping:\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 3, 'multi-play roles: ' .. #result.seeded)
end

-- 6. Missing role is reported explicitly; the good role still seeds.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  roles:\n    - web\n    - ghost\n')
    make_role(base, 'web', '- name: t\n  ping:\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 1 and result.seeded[1].role == 'web', 'web still seeded')
    check(#result.unresolved == 1 and result.unresolved[1].role == 'ghost', 'ghost unresolved')
    check(result.unresolved[1].reason:find('cannot read') ~= nil, 'reason: ' .. result.unresolved[1].reason)
    local warned = false
    for _, note in ipairs(notified) do
        if note.level == 3 and note.message:find('ghost') ~= nil then
            warned = true
        end
    end
    check(warned, 'WARN notification must name the unresolved role')
end

-- ================= ADVERSARIAL (6) =================

-- 7. Unreadable playbook: nil + error, no exception.
do
    reset_recorders()
    local result, err = ansible.seed_role_entry_breakpoints('/nonexistent/dir/site.yml')
    check(result == nil, 'expected nil result')
    check(type(err) == 'string' and err:find('not readable') ~= nil, 'err: ' .. tostring(err))
end

-- 8. Empty playbook path: nil + error.
do
    reset_recorders()
    local result, err = ansible.seed_role_entry_breakpoints('')
    check(result == nil, 'expected nil result')
    check(type(err) == 'string', 'expected string err')
end

-- 9. Playbook without any roles section: clean empty result, no warning.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  tasks:\n    - name: direct\n      ping:\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 0 and #result.unresolved == 0, 'empty result expected')
    check(#notified == 0, 'no notifications for role-less playbook')
end

-- 10. tasks/main.yml with no executable task: unresolved with reason.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  roles:\n    - empty\n')
    make_role(base, 'empty', '---\n# nothing here\n\n# just comments\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 0, 'nothing seeded')
    check(#result.unresolved == 1, 'one unresolved')
    check(result.unresolved[1].reason == 'no executable task found', 'reason: ' .. result.unresolved[1].reason)
    check(#breakpoint_calls == 0, 'no breakpoint attempted')
end

-- 11. Path traversal in a role name is rejected; never escapes roles dir.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  roles:\n    - { role: ../evil }\n')
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 0, 'traversal role not seeded')
    check(#result.unresolved == 1, 'traversal role unresolved')
    check(result.unresolved[1].reason == 'unsafe role name', 'reason: ' .. result.unresolved[1].reason)
    check(#breakpoint_calls == 0, 'no breakpoint attempted for traversal')
    check(#bufadd_calls == 0, 'no buffer created for traversal')
end

-- 12. breakpoints.set raising is captured as unresolved, not propagated.
do
    reset_recorders()
    local base = tmpdir()
    write_file(base .. '/site.yml', '---\n- hosts: all\n  roles:\n    - web\n')
    make_role(base, 'web', '- name: t\n  ping:\n')
    package.preload['dap.breakpoints'] = function()
        return {
            set = function()
                error('boom')
            end,
        }
    end
    package.loaded['dap.breakpoints'] = nil
    local result, err = ansible.seed_role_entry_breakpoints(base .. '/site.yml')
    check(err == nil, 'unexpected err: ' .. tostring(err))
    check(#result.seeded == 0, 'nothing seeded on set failure')
    check(#result.unresolved == 1, 'one unresolved')
    check(result.unresolved[1].reason:find('^breakpoint failed:') ~= nil, 'reason: ' .. result.unresolved[1].reason)
end

print(('ansible role breakpoints: %d/%d checks passed (12 cases: 6 validation + 6 adversarial)'):format(passed, total))
