-- #################################################################
-- qompassai/Diver/lua/config/data/psql.lua
-- Qompass AI Diver Native PostgreSQL Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Plugin-free PostgreSQL tooling for Neovim 0.13+.
--
-- Talks to the `psql` CLI directly through vim.system and :terminal.
-- No vim-dadbod, no vim-dadbod-ui, no vim-dadbod-completion, no FFI binding.
-- Sibling of lua/config/data/sqlite.lua, lua/config/data/duckdb.lua and
-- lua/config/data/mysql.lua: same shape, same safety bounds, same command
-- naming convention, connection-based like mysql.lua rather than file-based.
--
-- Connections are passed to psql as a single libpq conninfo string (e.g.
-- "host=... dbname=... user=..."), which is the documented, forward
-- compatible way to hand psql arbitrary connection parameters (service,
-- passfile, sslmode, ...) without needing a dedicated flag for each one.
-- See: https://www.postgresql.org/docs/current/libpq-connect.html
--
-- Credentials: this module never accepts a bare password field. Pass
-- passfile (a chmod-600 ~/.pgpass-style file) or service (a named entry in
-- pg_service.conf) instead. A password on argv or in a conninfo string
-- built from user input is visible to every other user on the machine
-- through `ps`; a password file is not. See:
--   https://www.postgresql.org/docs/current/libpq-pgpass.html
--
-- Readonly: psql has no --readonly flag. opts.readonly instead adds
-- options='-c default_transaction_read_only=on' to the conninfo string,
-- which makes the server reject writes for the life of the connection.
-- This is a soft guard, not a security boundary: it relies on the server
-- honoring a session GUC, so pair it with a genuinely read-only DB role
-- for anything that matters.
--
-- Two access paths are provided on purpose:
--   1. Human commands (:Psql*) for interactive use in a buffer. These
--      follow whatever readonly state the buffer's session was attached
--      with (:PsqlAttach! for readonly, :PsqlAttach for read/write).
--   2. A buffer-independent Lua API (M.query / M.query_sync) for AI agents
--      or scripts that call this module directly, with no buffer, no
--      window, and no notify() side effects — just rows or an error.
--      Agent calls default to readonly = true. A caller must pass
--      { readonly = false } explicitly to allow writes.
--
-- Commands:
--   :PsqlAttach[!] key=val ...    Attach a connection (bang = readonly).
--                                 Keys: host, port, user, database,
--                                 service, passfile.
--   :PsqlDetach                   Detach the current buffer's connection.
--   :PsqlRun                      Run the buffer, or a visual range, as SQL.
--   :PsqlTables                   List tables in the attached database.
--   :PsqlSchema [table]           Describe one table, or list tables.
--   :PsqlTerminal                 Open an interactive psql REPL in a split.
--   :PsqlInfo                     Show the current buffer's connection info.
--
-- Agent API:
--   require('config.data.psql').query(conn, sql, on_result, opts)
--   require('config.data.psql').query_sync(conn, sql, opts)
--   require('config.data.psql').query_buffer(bufnr, sql, on_result, opts)
--   -- opts.readonly defaults to true for all three; pass
--   -- { readonly = false } to allow the query to write.
--   -- conn has the same shape as :PsqlAttach's keys, as a table.
--
local api = vim.api
local fs = vim.fs
--local uv = vim.uv

local M = {}

local KEY_COUNT_MAX = 8
local QUERY_TIMEOUT_MS = 15000
local RESULT_LINE_COUNT_MAX = 5000
local SQL_BYTES_MAX = 1048576

local READONLY_OPTIONS_VALUE = '-c default_transaction_read_only=on'

local CONNECTION_KEYS = {
    database = true,
    host = true,
    passfile = true,
    port = true,
    service = true,
    user = true,
}

local defaults = {
    notify = true,
}

---@class PsqlConfigOpts
---@field notify? boolean

---@type PsqlConfigOpts
M.config = vim.deepcopy(defaults)

---@class PsqlConnection
---@field database? string
---@field host? string
---@field passfile? string
---@field password? string Forbidden: probed by validate_connection, always rejected; use passfile/service.
---@field port? integer
---@field service? string
---@field user? string

---@class PsqlSession
---@field bufnr integer
---@field conn PsqlConnection
---@field readonly boolean
---@field root string

---@class PsqlQueryOpts
---@field readonly? boolean

M.state = {
    ---@type table<integer, PsqlSession>
    sessions = {},
}

---@param message string
---@param level? integer
local function notify(message, level)
    if not M.config.notify then
        return
    end

    vim.notify(message, level or vim.log.levels.INFO, {
        title = 'psql',
    })
end

---@return boolean
local function has_psql()
    return vim.fn.executable('psql') == 1
end

---@param value string
---@return boolean
local function string_is_safe(value)
    if type(value) ~= 'string' then
        return false
    end

    if value == '' then
        return false
    end

    if value:find('%z') ~= nil then
        return false
    end

    return true
end

---@param bufnr integer
---@return boolean
local function buffer_is_usable(bufnr)
    if type(bufnr) ~= 'number' then
        return false
    end

    if bufnr < 0 then
        return false
    end

    return api.nvim_buf_is_valid(bufnr)
end

---@param bufnr integer
---@return string
local function resolve_root(bufnr)
    local root = fs.root(bufnr, { '.git' })

    if root ~= nil then
        return root
    end

    return vim.fn.getcwd()
end

---@param conn PsqlConnection
---@return boolean
---@return string|nil
local function validate_connection(conn)
    if type(conn) ~= 'table' then
        return false, 'connection must be a table'
    end

    if conn.password ~= nil then
        return false, 'password is not accepted directly; use passfile or service instead'
    end

    if conn.host ~= nil and not string_is_safe(conn.host) then
        return false, 'host must be a non-empty string'
    end

    if conn.user ~= nil and not string_is_safe(conn.user) then
        return false, 'user must be a non-empty string'
    end

    if conn.database ~= nil and not string_is_safe(conn.database) then
        return false, 'database must be a non-empty string'
    end

    if conn.service ~= nil and not string_is_safe(conn.service) then
        return false, 'service must be a non-empty string'
    end

    if conn.passfile ~= nil and not string_is_safe(conn.passfile) then
        return false, 'passfile must be a non-empty string'
    end

    if conn.port ~= nil then
        if type(conn.port) ~= 'number' or conn.port % 1 ~= 0 then
            return false, 'port must be an integer'
        end

        if conn.port < 1 or conn.port > 65535 then
            return false, 'port must be between 1 and 65535'
        end
    end

    return true, nil
end

---@param bufnr integer
---@return PsqlSession|nil
local function get_session(bufnr)
    if not buffer_is_usable(bufnr) then
        return nil
    end

    return M.state.sessions[bufnr]
end

---@param opts PsqlQueryOpts|nil
---@return boolean
local function resolve_query_readonly(opts)
    if type(opts) ~= 'table' then
        return true
    end

    if opts.readonly == nil then
        return true
    end

    return opts.readonly == true
end

---@param value string|integer
---@return string
local function quote_conninfo_value(value)
    local text = tostring(value)
    text = text:gsub('\\', '\\\\')
    text = text:gsub("'", "\\'")
    return "'" .. text .. "'"
end

---@param conn PsqlConnection
---@param readonly boolean
---@return string
local function build_conninfo(conn, readonly)
    local parts = {}

    if conn.host ~= nil then
        parts[#parts + 1] = 'host=' .. quote_conninfo_value(conn.host)
    end

    if conn.port ~= nil then
        parts[#parts + 1] = 'port=' .. quote_conninfo_value(conn.port)
    end

    if conn.user ~= nil then
        parts[#parts + 1] = 'user=' .. quote_conninfo_value(conn.user)
    end

    if conn.database ~= nil then
        parts[#parts + 1] = 'dbname=' .. quote_conninfo_value(conn.database)
    end

    if conn.service ~= nil then
        parts[#parts + 1] = 'service=' .. quote_conninfo_value(conn.service)
    end

    if conn.passfile ~= nil then
        parts[#parts + 1] = 'passfile=' .. quote_conninfo_value(conn.passfile)
    end

    if readonly then
        parts[#parts + 1] = 'options=' .. quote_conninfo_value(READONLY_OPTIONS_VALUE)
    end

    return table.concat(parts, ' ')
end

---@param conn PsqlConnection
---@param readonly boolean
---@param mode_flags string[]
---@return string[]
local function build_argv(conn, readonly, mode_flags)
    local argv = { 'psql', '--no-password', '-v', 'ON_ERROR_STOP=1', '-P', 'pager=off' }

    for _, flag in ipairs(mode_flags or {}) do
        argv[#argv + 1] = flag
    end

    local conninfo = build_conninfo(conn, readonly)

    if conninfo ~= '' then
        argv[#argv + 1] = conninfo
    end

    return argv
end

---@param bufnr integer
---@param conn PsqlConnection
---@param readonly? boolean
---@return PsqlSession|nil
---@return string|nil
function M.attach(bufnr, conn, readonly)
    bufnr = bufnr or api.nvim_get_current_buf()

    if not buffer_is_usable(bufnr) then
        return nil, 'invalid buffer'
    end

    if not has_psql() then
        return nil, 'psql executable was not found on PATH'
    end

    local valid, validation_error = validate_connection(conn)

    if not valid then
        return nil, validation_error
    end

    ---@type PsqlSession
    local session = {
        bufnr = bufnr,
        conn = vim.deepcopy(conn),
        readonly = readonly == true,
        root = resolve_root(bufnr),
    }

    M.state.sessions[bufnr] = session
    notify(
        'Attached '
            .. (conn.database or conn.service or '(default connection)')
            .. (session.readonly and ' (readonly)' or '')
    )

    return session, nil
end

---@param bufnr? integer
function M.detach(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    if M.state.sessions[bufnr] == nil then
        notify('No connection is attached to this buffer', vim.log.levels.WARN)
        return
    end

    M.state.sessions[bufnr] = nil
    notify('Detached connection from buffer ' .. bufnr)
end

---@param bufnr? integer
function M.info(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    local session = get_session(bufnr)

    if session == nil then
        notify('No connection is attached to this buffer', vim.log.levels.WARN)
        return
    end

    notify(vim.inspect({
        bufnr = session.bufnr,
        conn = {
            database = session.conn.database,
            host = session.conn.host,
            passfile = session.conn.passfile,
            port = session.conn.port,
            service = session.conn.service,
            user = session.conn.user,
        },
        readonly = session.readonly,
        root = session.root,
    }))
end

---@param lines string[]
---@param title string
local function show_result_buffer(lines, title)
    assert(type(lines) == 'table')
    assert(type(title) == 'string')

    local truncated = false

    if #lines > RESULT_LINE_COUNT_MAX then
        truncated = true
        local bounded = {}

        for index = 1, RESULT_LINE_COUNT_MAX do
            bounded[index] = lines[index]
        end

        lines = bounded
    end

    if truncated then
        lines[#lines + 1] = ''
        lines[#lines + 1] = string.format('-- output truncated at %d lines --', RESULT_LINE_COUNT_MAX)
    end

    local bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    api.nvim_buf_set_name(bufnr, title)

    vim.bo[bufnr].buftype = 'nofile'
    vim.bo[bufnr].bufhidden = 'wipe'
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].filetype = 'psqlresult'

    vim.cmd('botright split')
    api.nvim_win_set_buf(api.nvim_get_current_win(), bufnr)
    api.nvim_win_resize(api.nvim_get_current_win(), -1, math.min(20, #lines + 1))
end

---@param conn PsqlConnection
---@param readonly boolean
---@param sql string
---@param mode_flags string[]
---@param on_done fun(result: vim.SystemCompleted)
local function run_process(conn, readonly, sql, mode_flags, on_done)
    assert(type(sql) == 'string')
    assert(#sql <= SQL_BYTES_MAX, 'query exceeds size bound')

    vim.system(build_argv(conn, readonly, mode_flags), {
        stdin = sql,
        text = true,
        timeout = QUERY_TIMEOUT_MS,
    }, function(result)
        vim.schedule(function()
            on_done(result)
        end)
    end)
end

---@param session PsqlSession
---@param sql string
---@param title string
local function run_and_show(session, sql, title)
    run_process(session.conn, session.readonly, sql, {}, function(result)
        if result.code ~= 0 then
            local message = result.stderr ~= '' and result.stderr or 'psql exited with code ' .. result.code
            notify(message, vim.log.levels.ERROR)
            return
        end

        local output = result.stdout or ''
        local lines = vim.split(output, '\n', {
            plain = true,
            trimempty = true,
        })

        if #lines == 0 then
            lines = { '-- no rows --' }
        end

        show_result_buffer(lines, title)
    end)
end

---Parse RFC4180-style CSV text into rows of fields.
---
---Tracks whether each field was quoted so an unquoted empty field (NULL
---in psql's --csv output) can be told apart from a quoted empty field (a
---genuine empty string).
---
---@param text string
---@return string[][] rows
---@return boolean[][] quoted
local function parse_csv(text)
    local rows = {}
    local quoted_rows = {}
    local row = {}
    local quoted_flags = {}
    local field = {}
    local field_was_quoted = false
    local in_quotes = false
    local length = #text
    local index = 1

    local function flush_field()
        row[#row + 1] = table.concat(field)
        quoted_flags[#quoted_flags + 1] = field_was_quoted
        field = {}
        field_was_quoted = false
    end

    local function flush_row()
        flush_field()
        rows[#rows + 1] = row
        quoted_rows[#quoted_rows + 1] = quoted_flags
        row = {}
        quoted_flags = {}
    end

    while index <= length do
        local char = text:sub(index, index)

        if in_quotes then
            if char == '"' then
                if text:sub(index + 1, index + 1) == '"' then
                    field[#field + 1] = '"'
                    index = index + 2
                else
                    in_quotes = false
                    index = index + 1
                end
            else
                field[#field + 1] = char
                index = index + 1
            end
        else
            if char == '"' then
                in_quotes = true
                field_was_quoted = true
                index = index + 1
            elseif char == ',' then
                flush_field()
                index = index + 1
            elseif char == '\r' then
                index = index + 1
            elseif char == '\n' then
                flush_row()
                index = index + 1
            else
                field[#field + 1] = char
                index = index + 1
            end
        end
    end

    if #field > 0 or #row > 0 then
        flush_row()
    end

    return rows, quoted_rows
end

---@param output string
---@return table[]
local function parse_csv_rows(output)
    local rows, quoted_rows = parse_csv(output)

    if #rows == 0 then
        return {}
    end

    local headers = rows[1]
    local results = {}

    for row_index = 2, #rows do
        local cells = rows[row_index]
        local quoted_flags = quoted_rows[row_index]
        local result = {}

        for column_index, header in ipairs(headers) do
            local cell = cells[column_index]
            local was_quoted = quoted_flags[column_index] == true

            if cell ~= nil and (was_quoted or cell ~= '') then
                result[header] = cell
            end
        end

        results[#results + 1] = result
    end

    return results
end

---Run SQL against a connection and return decoded rows.
---
---This is the agent-facing entry point: it takes an explicit connection
---rather than reading buffer state, produces no notify() calls, and hands
---back plain Lua tables (one per row, keyed by column name) or an error
---string. Safe to call from a script, a keymap, or an external Lua caller
---with no buffer/window.
---
---opts.readonly defaults to true: an agent-initiated query cannot write
---unless the caller explicitly passes { readonly = false }.
---
---Send one statement per call. Multi-statement batches produce
---concatenated CSV blocks this parser does not separate.
---
---@param conn PsqlConnection
---@param sql string SQL text to run.
---@param on_result fun(rows: table[]|nil, err: string|nil)
---@param opts? PsqlQueryOpts
function M.query(conn, sql, on_result, opts)
    if not has_psql() then
        on_result(nil, 'psql executable was not found on PATH')
        return
    end

    local valid, validation_error = validate_connection(conn)

    if not valid then
        on_result(nil, validation_error)
        return
    end

    if type(sql) ~= 'string' or sql:match('^%s*$') then
        on_result(nil, 'sql must be a non-empty string')
        return
    end

    local readonly = resolve_query_readonly(opts)

    run_process(conn, readonly, sql, { '--csv' }, function(result)
        if result.code ~= 0 then
            on_result(nil, result.stderr ~= '' and result.stderr or 'psql exited with code ' .. result.code)
            return
        end

        on_result(parse_csv_rows(result.stdout or ''), nil)
    end)
end

---Blocking variant of M.query for scripted/headless callers.
---
---opts.readonly defaults to true, matching M.query.
---
---@param conn PsqlConnection
---@param sql string SQL text to run.
---@param opts? PsqlQueryOpts
---@return table[]|nil rows
---@return string|nil err
function M.query_sync(conn, sql, opts)
    if not has_psql() then
        return nil, 'psql executable was not found on PATH'
    end

    local valid, validation_error = validate_connection(conn)

    if not valid then
        return nil, validation_error
    end

    if type(sql) ~= 'string' or sql:match('^%s*$') then
        return nil, 'sql must be a non-empty string'
    end

    local readonly = resolve_query_readonly(opts)

    local result = vim.system(
        build_argv(conn, readonly, {
            '--csv',
        }),
        {
            stdin = sql,
            text = true,
            timeout = QUERY_TIMEOUT_MS,
        }
    ):wait()

    if result.code ~= 0 then
        return nil, result.stderr ~= '' and result.stderr or 'psql exited with code ' .. result.code
    end

    return parse_csv_rows(result.stdout or ''), nil
end

---Non-blocking variant of M.query_sync for the dataaccess bulk lane:
---the psql wait happens in libuv and cb fires on the main loop
---with (rows, nil) or (nil, err).
---
---opts.readonly defaults to true, matching M.query_sync.
---
---@param conn PsqlConnection
---@param sql string SQL text to run.
---@param opts? PsqlQueryOpts
---@param cb fun(rows: table[]|nil, err: string|nil)
function M.query_async(conn, sql, opts, cb)
    assert(type(cb) == 'function', 'cb must be a function')
    -- Every cb invocation goes through vim.schedule so callers can
    -- rely on main-loop context no matter how Neovim dispatches the
    -- system callback.
    local function fail(err)
        vim.schedule(function()
            cb(nil, err)
        end)
    end
    if not has_psql() then
        fail('psql executable was not found on PATH')
        return
    end
    local valid, validation_error = validate_connection(conn)
    if not valid then
        fail(validation_error)
        return
    end
    if type(sql) ~= 'string' or sql:match('^%s*$') then
        fail('sql must be a non-empty string')
        return
    end
    local readonly = resolve_query_readonly(opts)
    local ok, sysobj = pcall(vim.system, build_argv(conn, readonly, { '--csv' }), {
        stdin = sql,
        text = true,
        timeout = QUERY_TIMEOUT_MS,
    }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                local err = result.stderr ~= '' and result.stderr or 'psql exited with code ' .. result.code
                cb(nil, err)
                return
            end
            cb(parse_csv_rows(result.stdout or ''), nil)
        end)
    end)
    if not ok then
        fail('psql failed to start: ' .. tostring(sysobj))
    end
end

---opts.readonly defaults to true, independent of the session's own
---readonly state, matching M.query and M.query_sync. Pass
---{ readonly = false } to allow a write against a read/write session.
---
---@param bufnr integer
---@param sql string
---@param on_result fun(rows: table[]|nil, err: string|nil)
---@param opts? PsqlQueryOpts
function M.query_buffer(bufnr, sql, on_result, opts)
    local session = get_session(bufnr)

    if session == nil then
        on_result(nil, 'no connection is attached to this buffer')
        return
    end

    M.query(session.conn, sql, on_result, opts)
end

---@param bufnr integer
---@param line1 integer
---@param line2 integer
---@return string
local function buffer_sql(bufnr, line1, line2)
    local lines = api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
    return table.concat(lines, '\n')
end

---@param opts vim.api.keyset.create_user_command.command_args
function M.run(opts)
    local bufnr = api.nvim_get_current_buf()
    local session = get_session(bufnr)

    if session == nil then
        notify('No connection is attached to this buffer. Use :PsqlAttach first', vim.log.levels.ERROR)
        return
    end

    local sql = buffer_sql(bufnr, opts.line1, opts.line2)

    if sql:match('^%s*$') then
        notify('No SQL to run', vim.log.levels.WARN)
        return
    end

    run_and_show(session, sql, 'psql://' .. (session.conn.database or session.conn.service or 'default') .. ' [result]')
end

function M.tables()
    local bufnr = api.nvim_get_current_buf()
    local session = get_session(bufnr)

    if session == nil then
        notify('No connection is attached to this buffer. Use :PsqlAttach first', vim.log.levels.ERROR)
        return
    end

    run_and_show(
        session,
        '\\dt\n',
        'psql://' .. (session.conn.database or session.conn.service or 'default') .. ' [tables]'
    )
end

---@param table_name? string
function M.schema(table_name)
    local bufnr = api.nvim_get_current_buf()
    local session = get_session(bufnr)

    if session == nil then
        notify('No connection is attached to this buffer. Use :PsqlAttach first', vim.log.levels.ERROR)
        return
    end

    local sql = table_name and table_name ~= '' and string.format('\\d %s\n', table_name) or '\\dt\n'

    run_and_show(session, sql, 'psql://' .. (session.conn.database or session.conn.service or 'default') .. ' [schema]')
end

function M.terminal()
    local bufnr = api.nvim_get_current_buf()
    local session = get_session(bufnr)

    if session == nil then
        notify('No connection is attached to this buffer. Use :PsqlAttach first', vim.log.levels.ERROR)
        return
    end

    if not has_psql() then
        notify('psql executable was not found on PATH', vim.log.levels.ERROR)
        return
    end

    local argv = build_argv(session.conn, session.readonly, {})

    vim.cmd('botright split')
    vim.fn.jobstart(argv, { term = true })
    vim.cmd('startinsert')
end

---@param args string
---@return PsqlConnection|nil
---@return string|nil
local function parse_connection_args(args)
    local tokens = vim.split(args, '%s+', { trimempty = true })

    if #tokens > KEY_COUNT_MAX then
        return nil, 'too many connection arguments'
    end

    local conn = {}

    for _, token in ipairs(tokens) do
        local key, value = token:match('^([%w_]+)=(.*)$')

        if key == nil then
            return nil, 'malformed argument (expected key=value): ' .. token
        end

        if not CONNECTION_KEYS[key] then
            return nil, 'unknown connection key: ' .. key
        end

        if key == 'port' then
            conn.port = tonumber(value)

            if conn.port == nil then
                return nil, 'port must be numeric'
            end
        else
            conn[key] = value
        end
    end

    return conn, nil
end

local function create_commands()
    api.nvim_create_user_command('PsqlAttach', function(opts)
        if opts.args == '' then
            notify(
                'Usage: :PsqlAttach[!] host=... port=... user=... database=... service=... passfile=...',
                vim.log.levels.ERROR
            )
            return
        end
        local conn, parse_error = parse_connection_args(opts.args)

        if conn == nil then
            notify(parse_error or 'failed to parse connection arguments', vim.log.levels.ERROR)
            return
        end

        local session, err = M.attach(api.nvim_get_current_buf(), conn, opts.bang)

        if session == nil then
            notify(err or 'failed to attach connection', vim.log.levels.ERROR)
        end
    end, {
        bang = true,
        desc = 'Attach a PostgreSQL connection to the current buffer (bang = readonly)',
        nargs = 1,
    })

    api.nvim_create_user_command('PsqlDetach', function()
        M.detach(api.nvim_get_current_buf())
    end, {
        desc = 'Detach the PostgreSQL connection from the current buffer',
    })

    api.nvim_create_user_command('PsqlRun', function(opts)
        M.run(opts)
    end, {
        desc = 'Run the buffer, or a visual range, as SQL against the attached connection',
        range = '%',
    })

    api.nvim_create_user_command('PsqlTables', function()
        M.tables()
    end, {
        desc = 'List tables in the attached PostgreSQL database',
    })

    api.nvim_create_user_command('PsqlSchema', function(opts)
        M.schema(opts.args ~= '' and opts.args or nil)
    end, {
        desc = 'Describe one table, or list tables',
        nargs = '?',
    })

    api.nvim_create_user_command('PsqlTerminal', function()
        M.terminal()
    end, {
        desc = 'Open an interactive psql REPL for the attached connection',
    })

    api.nvim_create_user_command('PsqlInfo', function()
        M.info(api.nvim_get_current_buf())
    end, {
        desc = "Show the current buffer's PostgreSQL connection info",
    })
end

local function create_autocmds()
    local group = api.nvim_create_augroup('NativePsql', {
        clear = true,
    })

    api.nvim_create_autocmd('BufDelete', {
        callback = function(args)
            M.state.sessions[args.buf] = nil
        end,
        group = group,
    })
end

---@param opts? PsqlConfigOpts
---@return table
function M.setup(opts)
    M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

    if not has_psql() then
        notify(
            'psql executable was not found on PATH. '
                .. 'Install it (e.g. `pacman -S postgresql` on Arch) to use :Psql* commands.',
            vim.log.levels.WARN
        )
    end

    create_commands()
    create_autocmds()

    return M
end

return M
