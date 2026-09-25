-- #################################################################
-- qompassai/Diver/lua/config/data/adapter.lua
-- Qompass AI Diver Native DB Adapter Registry
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- What db/adapter.vim did: given a URL, extract its scheme, turn that into
-- a function-name prefix (db#adapter#{scheme}#), and lazily `runtime` an
-- autoload/db/adapter/{scheme}.vim file the first time that scheme was
-- used, discovered by scanning 'runtimepath'. db#adapter#supports/call/
-- dispatch then called functions on that prefix if they existed, with a
-- default value or a thrown error if not.
--
-- What changes in the native version, and why:
--   - No filesystem scanning, no lazy `runtime` sourcing, no name-mangled
--     function prefixes. Neovim's require() already is the module system;
--     an adapter is just a Lua module with known method names (attach,
--     detach, query, query_sync, query_buffer, terminal, info, setup),
--     which lua/config/data/sqlite.lua, duckdb.lua, mysql.lua and psql.lua
--     already share. Adding a new backend means requiring it and calling
--     M.register once, not dropping a specially-named file on 'rtp'.
--   - Adapters declare a `kind`: 'file' (attach takes a path string, like
--     sqlite/duckdb) or 'connection' (attach takes a table, like mysql/
--     psql). db/adapter.vim had no equivalent; it left every adapter free
--     to interpret its URL however it liked. Making the split explicit
--     here is what lets lua/config/data/init.lua's URL parser decide, for
--     a given scheme, whether the remainder of the URL is a filesystem
--     path or a host/port/user/database tuple, without asking the
--     adapter module itself (which would require calling into it before
--     knowing how to construct the very argument it expects).
--   - Schemes and file extensions are both indexed for lookup, since two
--     of the four current adapters (sqlite, duckdb) are more naturally
--     identified by file extension than by an explicit scheme prefix.
--
-- Usage:
--   local adapter = require('config.data.adapter')
--   adapter.register('sqlite', {
--       module = require('config.data.sqlite'),
--       schemes = { 'sqlite', 'sqlite3' },
--       extensions = { 'db', 'sqlite', 'sqlite3' },
--       kind = 'file',
--   })
--   adapter.resolve_scheme('sqlite3')      --> 'sqlite'
--   adapter.supports('sqlite', 'terminal') --> true
--   adapter.dispatch('sqlite://x', 'attach', bufnr, path, false)

local M = {}

local KNOWN_KINDS = {
    connection = true,
    file = true,
}

---@class DbAdapter
---@field extensions table<string, boolean>
---@field kind 'file'|'connection'
---@field module table
---@field name string
---@field schemes table<string, boolean>

M.state = {
    ---@type table<string, DbAdapter>
    adapters = {},
    ---@type table<string, string>
    extension_index = {},
    ---@type table<string, string>
    scheme_index = {},
}

---@param name string
---@return boolean
local function name_is_valid(name)
    return type(name) == 'string' and name ~= ''
end

---@param list string[]|nil
---@return table<string, boolean>
local function to_set(list)
    local set = {}

    if list == nil then
        return set
    end

    assert(type(list) == 'table')

    for _, item in ipairs(list) do
        assert(type(item) == 'string')
        assert(item ~= '')
        set[item:lower()] = true
    end

    return set
end

---Register a backend adapter under `name`, indexing its schemes and (for
---file-kind adapters) its file extensions for later lookup.
---
---Registering the same name twice replaces the previous registration and
---its index entries outright; it does not merge schemes/extensions.
---
---@param name string
---@param opts { module: table, schemes: string[], kind: 'file'|'connection', extensions?: string[] }
function M.register(name, opts)
    assert(name_is_valid(name), 'adapter name must be a non-empty string')
    assert(type(opts) == 'table', 'adapter opts must be a table')
    assert(type(opts.module) == 'table', 'adapter module must be a table')
    assert(KNOWN_KINDS[opts.kind] == true, "adapter kind must be 'file' or 'connection'")
    assert(type(opts.schemes) == 'table' and #opts.schemes > 0, 'adapter needs at least one scheme')

    if opts.kind == 'file' then
        assert(
            type(opts.extensions) == 'table' and #opts.extensions > 0,
            "file-kind adapters need at least one entry in 'extensions'"
        )
    end

    -- Remove this name's previous index entries before re-registering,
    -- so a scheme/extension does not point at a stale adapter name.
    local previous = M.state.adapters[name]

    if previous ~= nil then
        for scheme in pairs(previous.schemes) do
            if M.state.scheme_index[scheme] == name then
                M.state.scheme_index[scheme] = nil
            end
        end

        for extension in pairs(previous.extensions) do
            if M.state.extension_index[extension] == name then
                M.state.extension_index[extension] = nil
            end
        end
    end

    ---@type DbAdapter
    local entry = {
        extensions = to_set(opts.extensions),
        kind = opts.kind,
        module = opts.module,
        name = name,
        schemes = to_set(opts.schemes),
    }

    M.state.adapters[name] = entry

    for scheme in pairs(entry.schemes) do
        M.state.scheme_index[scheme] = name
    end

    for extension in pairs(entry.extensions) do
        M.state.extension_index[extension] = name
    end
end

---@param name string
function M.unregister(name)
    local entry = M.state.adapters[name]

    if entry == nil then
        return
    end

    for scheme in pairs(entry.schemes) do
        if M.state.scheme_index[scheme] == name then
            M.state.scheme_index[scheme] = nil
        end
    end

    for extension in pairs(entry.extensions) do
        if M.state.extension_index[extension] == name then
            M.state.extension_index[extension] = nil
        end
    end

    M.state.adapters[name] = nil
end

---@param scheme string
---@return string|nil
function M.resolve_scheme(scheme)
    if type(scheme) ~= 'string' then
        return nil
    end

    return M.state.scheme_index[scheme:lower()]
end

---@param extension string
---@return string|nil
function M.resolve_extension(extension)
    if type(extension) ~= 'string' then
        return nil
    end

    return M.state.extension_index[extension:lower()]
end

---@param name string
---@return DbAdapter|nil
---@return string|nil
function M.get(name)
    local entry = M.state.adapters[name]

    if entry == nil then
        return nil, 'no adapter registered under: ' .. tostring(name)
    end

    return entry, nil
end

---@param name string
---@return string|nil
function M.kind(name)
    local entry = M.state.adapters[name]

    if entry == nil then
        return nil
    end

    return entry.kind
end

---Equivalent of db#adapter#supports: does this adapter's module have a
---callable function under this name.
---
---@param name string
---@param fn_name string
---@return boolean
function M.supports(name, fn_name)
    local entry = M.state.adapters[name]

    if entry == nil then
        return false
    end

    return type(entry.module[fn_name]) == 'function'
end

---Equivalent of db#adapter#call: call module[fn_name](...) if it exists.
---With no default given, a missing function raises an error, matching
---db#adapter#call's behavior when its optional a:1 default is omitted.
---
---@param name string
---@param fn_name string
---@param ... any
---@return any
function M.call(name, fn_name, ...)
    local entry, err = M.get(name)

    if entry == nil then
        error(err, 0)
    end

    local fn = entry.module[fn_name]

    if type(fn) ~= 'function' then
        error(string.format('adapter %s has no function %s', name, fn_name), 0)
    end

    return fn(...)
end

---Equivalent of db#adapter#call's optional-default form: call
---module[fn_name](...) if it exists, otherwise return `default` without
---erroring.
---
---@param name string
---@param fn_name string
---@param default any
---@param ... any
---@return any
function M.call_or(name, fn_name, default, ...)
    if not M.supports(name, fn_name) then
        return default
    end

    return M.call(name, fn_name, ...)
end

---Equivalent of db#adapter#dispatch: resolve a scheme (or bare adapter
---name) to its adapter, then call the named function on it.
---
---Accepts either a full URL-shaped string ("scheme://...", scheme taken
---up to the first ':') or a bare registered adapter/scheme name.
---
---@param url_or_scheme string
---@param fn_name string
---@param ... any
---@return any
function M.dispatch(url_or_scheme, fn_name, ...)
    assert(type(url_or_scheme) == 'string' and url_or_scheme ~= '', 'dispatch needs a URL or scheme string')

    local scheme = url_or_scheme:match('^([%w+.-]+):') or url_or_scheme
    local name = M.resolve_scheme(scheme) or (M.state.adapters[scheme] ~= nil and scheme or nil)

    if name == nil then
        error('DB: no adapter for ' .. scheme, 0)
    end

    return M.call(name, fn_name, ...)
end

---Equivalent of db#adapter#schemes: every scheme known across all
---registered adapters, sorted for deterministic listing/completion.
---
---@return string[]
function M.schemes()
    local schemes = {}

    for scheme in pairs(M.state.scheme_index) do
        schemes[#schemes + 1] = scheme
    end

    table.sort(schemes)
    return schemes
end

---@return string[]
function M.names()
    local names = {}

    for name in pairs(M.state.adapters) do
        names[#names + 1] = name
    end

    table.sort(names)
    return names
end

return M
