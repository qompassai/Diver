-- Shared test harness for the MCP server specs.
-- Sets package.path to the repo root, installs a minimal `vim` stub only
-- when running under plain Lua (under Neovim the real vim is used), and
-- replaces ai.security.auditlog with a hermetic recorder so tests never
-- touch the real audit log. Each spec file is an independent process.
-- Usage: local stub = dofile(<this dir> .. '/common.lua')
local here = debug.getinfo(1, 'S').source:sub(2)
if here:sub(1, 1) ~= '/' then
    -- Invoked with a relative path: anchor at the process cwd.
    local pwd = io.popen('pwd')
    local cwd = pwd:read('*l')
    pwd:close()
    here = cwd .. '/' .. here
end
local dir = here:match('^(.*)/[^/]*$')
local root = dir:match('^(.*)/tests/lua/mcp_server$')
assert(root ~= nil, 'cannot locate repo root from ' .. dir)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local stub = {
    _executables = {},
    _audit_records = {},
    _system_impl = nil, -- assigned per spec: fun(cmd, opts) -> {code, stdout, stderr}
}

---@param s string
---@return string safely single-quoted for sh
local function shquote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
stub.shquote = shquote

if _G.vim == nil then
    local json = dofile(dir .. '/json.lua')
    stub.json = json

    local function stub_fs_dir(path)
        local handle = io.popen('ls -A -p ' .. shquote(path) .. ' 2>/dev/null')
        if handle == nil then
            return function()
                return nil
            end
        end
        local names = {}
        for line in handle:lines() do
            names[#names + 1] = line
        end
        handle:close()
        local i = 0
        return function()
            i = i + 1
            local raw = names[i]
            if raw == nil then
                return nil
            end
            if raw:sub(-1) == '/' then
                return raw:sub(1, -2), 'directory'
            end
            return raw, 'file'
        end
    end

    _G.vim = {
        json = json,
        trim = function(s)
            return s:match('^%s*(.-)%s*$')
        end,
        tbl_count = function(t)
            local n = 0
            for _ in pairs(t) do
                n = n + 1
            end
            return n
        end,
        schedule = function(f)
            f()
        end,
        log = { levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 } },
        fs = { dir = stub_fs_dir },
        fn = {
            executable = function(name)
                return stub._executables[name] and 1 or 0
            end,
            mkdir = function(path, _)
                os.execute('mkdir -p ' .. shquote(path))
                return 1
            end,
            tempname = function()
                return os.tmpname()
            end,
            getcwd = function()
                local handle = io.popen('pwd')
                local cwd = handle:read('*l')
                handle:close()
                return cwd
            end,
        },
        system = function(cmd, opts, on_exit)
            assert(stub._system_impl ~= nil, 'test must assign stub._system_impl')
            local result = stub._system_impl(cmd, opts or {})
            if on_exit ~= nil then
                on_exit(result)
                return nil
            end
            return result
        end,
        uv = {
            fs_realpath = function(path)
                local handle = io.popen('readlink -f ' .. shquote(path) .. ' 2>/dev/null')
                if handle == nil then
                    return nil
                end
                local out = handle:read('*l')
                handle:close()
                return out
            end,
            fs_stat = function(path)
                local handle = io.popen(
                    'if [ -d '
                        .. shquote(path)
                        .. ' ]; then echo directory; elif [ -e '
                        .. shquote(path)
                        .. ' ]; then echo file; fi 2>/dev/null'
                )
                if handle == nil then
                    return nil
                end
                local kind = handle:read('*l')
                handle:close()
                if kind == 'directory' or kind == 'file' then
                    return { type = kind }
                end
                return nil
            end,
        },
    }
else
    stub.json = vim.json
end

-- Hermetic audit log: record instead of writing the real log file.
package.preload['ai.security.auditlog'] = function()
    return {
        append = function(record)
            stub._audit_records[#stub._audit_records + 1] = record
            return true
        end,
    }
end

-- Fresh temp dir per spec file; caller removes it when done.
---@param label string
---@return string dir
function stub.fresh_dir(label)
    local base = os.tmpname()
    os.remove(base)
    local path = base .. '_' .. label
    vim.fn.mkdir(path, 'p')
    return path
end

---@param path string
---@param content string
function stub.write_file(path, content)
    local file = assert(io.open(path, 'w'))
    file:write(content)
    file:close()
end

return stub
