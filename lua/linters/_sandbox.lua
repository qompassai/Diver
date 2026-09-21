-- Linux Bubblewrap policy for native linters. No shell and no direct fallback.
-- SPDX-License-Identifier: Apache-2.0
local uv = vim.uv
local fs = vim.fs
local M = {}
local MOUNTS_MAX = 32

---@param path string
---@param root string
---@return boolean
function M.contains(path, root)
    return path == root or path:sub(1, #root + 1) == root .. '/'
end

---@param value string
---@return string
local function realpath(value)
    assert(type(value) == 'string' and value:sub(1, 1) == '/', 'expected absolute path')
    assert(not value:find('%z'), 'path contains NUL')
    local path, problem = uv.fs_realpath(value)
    assert(path, 'cannot resolve path: ' .. value .. ': ' .. tostring(problem))
    return path
end

---@param argv string[]
---@param path string
local function system_mount(argv, path)
    local stat = uv.fs_lstat(path)
    if stat == nil then
        return
    end
    if stat.type == 'link' then
        local target, problem = uv.fs_readlink(path)
        assert(target, tostring(problem))
        vim.list_extend(argv, { '--symlink', target, path })
    else
        vim.list_extend(argv, { '--ro-bind', path, path })
    end
end

---@param argv string[]
---@param paths string[]
---@param root string
local function extra_mounts(argv, paths, root)
    assert(vim.islist(paths) and #paths <= MOUNTS_MAX, 'invalid read_only mount list')
    for _, path in ipairs(paths) do
        local resolved = realpath(path)
        assert(resolved == fs.normalize(path), 'read_only mounts must use canonical paths')
        assert(resolved ~= '/' and resolved ~= '/home', 'mount is too broad')
        assert(resolved ~= uv.os_homedir(), 'mount a tool directory, not your entire home')
        assert(not M.contains(root, resolved), 'extra mount must not contain the project')
        for _, reserved in ipairs({ '/proc', '/dev', '/run', '/tmp', '/lint-home' }) do
            assert(not M.contains(resolved, reserved), 'reserved sandbox mount: ' .. resolved)
        end
        vim.list_extend(argv, { '--ro-bind', resolved, resolved })
    end
end

---@param argv string[]
---@param environment table<string, string>
---@param executable string
local function environment_flags(argv, environment, executable)
    local environment_copy = vim.tbl_extend('force', environment, {
        HOME = '/lint-home',
        XDG_CACHE_HOME = '/lint-home/.cache',
        XDG_CONFIG_HOME = '/lint-home/.config',
        XDG_DATA_HOME = '/lint-home/.local/share',
        XDG_STATE_HOME = '/lint-home/.local/state',
        TMPDIR = '/tmp',
        PATH = (fs.dirname(executable) or '/usr/bin') .. ':/usr/local/bin:/usr/bin:/bin',
        NO_COLOR = '1',
        LANG = 'C.UTF-8',
    })
    local keys = vim.tbl_keys(environment_copy)
    table.sort(keys)
    for _, key in ipairs(keys) do
        local value = environment_copy[key]
        assert(key:match('^[%a_][%w_]*$'), 'invalid environment key')
        assert(type(value) == 'string' and not value:find('%z'), 'invalid environment value')
        vim.list_extend(argv, { '--setenv', key, value })
    end
end

---@param command string[]
---@param cwd string
---@param context LintContext
---@param options NativeLintSandboxOptions
---@param environment table<string, string>
---@return string[]
function M.wrap(command, cwd, context, options, environment)
    assert(uv.os_uname().sysname == 'Linux', 'Bubblewrap mode requires Linux')
    local executable = vim.fn.exepath(options.executable)
    assert(executable ~= '', 'Bubblewrap is unavailable; install bubblewrap or select direct mode')
    local root = realpath(context.root)
    local working = realpath(cwd)
    local filename = realpath(context.filename)
    assert(root ~= '/' and root ~= uv.os_homedir(), 'choose a project root below / or HOME')
    assert(root ~= '/home' and root ~= '/tmp' and root ~= '/var', 'project root is too broad')
    assert(M.contains(working, root), 'linter cwd escapes the project root')
    assert(M.contains(filename, root), 'buffer symlink escapes the project root')
    -- Same-path mounts preserve diagnostics and absolute paths embedded in configs.
    assert(root == fs.normalize(context.root), 'sandbox requires a canonical project root')
    for _, reserved in ipairs({ '/usr', '/etc', '/proc', '/dev', '/run', '/lint-home' }) do
        assert(not M.contains(root, reserved), 'project overlaps a sandbox system mount')
    end
    local argv = {
        executable,
        '--unshare-all',
        '--unshare-user',
        '--disable-userns',
        '--die-with-parent',
        '--new-session',
        '--cap-drop',
        'ALL',
        '--clearenv',
        '--ro-bind',
        '/usr',
        '/usr',
    }
    for _, path in ipairs({ '/bin', '/sbin', '/lib', '/lib64' }) do
        system_mount(argv, path)
    end
    vim.list_extend(argv, {
        '--proc',
        '/proc',
        '--dev',
        '/dev',
        '--tmpfs',
        '/tmp',
        '--dir',
        '/lint-home',
        '--dir',
        '/lint-home/.cache',
        '--dir',
        '/lint-home/.config',
    })
    for _, path in ipairs({ '/etc/ld.so.cache', '/etc/localtime', '/etc/php' }) do
        system_mount(argv, path)
    end
    extra_mounts(argv, options.read_only, root)
    vim.list_extend(argv, { '--ro-bind', root, root, '--chdir', working })
    environment_flags(argv, environment, command[1])
    vim.list_extend(argv, { '--' })
    vim.list_extend(argv, command)
    return argv
end

return M