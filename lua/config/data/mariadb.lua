-- #################################################################
-- qompassai/Diver/lua/config/data/mariadb.lua
-- Qompass AI Diver Native MariaDB Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Plugin-free MariaDB tooling for Neovim 0.13+.
--
-- Talks to the `mariadb` CLI directly (not `mysql`; MariaDB ships both
-- binaries and this module deliberately invokes its own) through
-- vim.system and :terminal. No vim-dadbod, no plugin, no FFI binding.
-- Sibling of lua/config/data/mysql.lua: same shape, same safety bounds,
-- same connection-based session model.
--
-- Ported from db/adapter/mariadb.vim. Mapping:
--   canonicalize(url)      -> not needed. The vim version rewrote a
--                              scheme-only URL into "mariadb:///", handled
--                              JDBC address=() syntax, and absorbed URL
--                              structure into query params. This module's
--                              connection table (host/port/socket/user/
--                              database) is already the normalized shape;
--                              there is no intermediate URL string to
--                              canonicalize.
--   s:command_for_url       -> build_argv(conn, mode_flags), including the
--                              same "any extra param becomes --key=value"
--                              passthrough (conn.extra here) for MariaDB
--                              flags this module has no named field for.
--   interactive(url)        -> M.terminal()
--   filter(url)              -> run_and_show's mode_flags: '-t' is
--                              '--table' here (same effect, spelled out);
--                              --binary-as-hex is kept under the same
--                              name and applied to BOTH the human and
--                              agent paths (the original only used it for
--                              filter/non-interactive; this module also
--                              needs it on the agent's --batch --raw path,
--                              since raw binary column data would
--                              otherwise corrupt the tab-separated parser
--                              — a real gap mysql.lua does not currently
--                              close; see the note at the bottom of this
--                              header).
--   auth_pattern             -> not reproduced. Existed to detect an auth
--                              failure and retry with an inputsecret()
--                              prompt. This stack asks for credentials
--                              upfront via defaults_file, not interactively
--                              after a failed attempt; a bad connection
--                              just surfaces as a normal error.
--   complete_database/tables -> M.databases() / M.tables(), run through
--                              the same query path as everything else
--                              instead of a bespoke completion function.
--
-- Credentials: same stance as mysql.lua. No bare password field; pass
-- defaults_file pointing at a chmod-600 option file with a [client]
-- section. See https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/configuring-mariadb/configuring-mariadb-with-option-files
--
-- Readonly: no --readonly flag on the mariadb client either. opts.readonly
-- adds --init-command='SET SESSION TRANSACTION READ ONLY', identical in
-- spirit to mysql.lua's guard and the same caveat: a soft guard enforced
-- by the server accepting the SET, not a hard client-side restriction.
--
-- Two access paths are provided on purpose:
--   1. Human commands (:Mariadb*) for interactive use in a buffer. These
--      follow whatever readonly state the buffer's session was attached
--      with (:MariadbAttach! for readonly, :MariadbAttach for read/write).
--   2. A buffer-independent Lua API (M.query / M.query_sync) for AI agents
--      or scripts that call this module directly, with no buffer, no
--      window, and no notify() side effects — just rows or an error.
--      Agent calls default to readonly = true. A caller must pass
--      { readonly = false } explicitly to allow writes.
--
-- Commands:
--   :MariadbAttach[!] key=val ... Attach a connection (bang = readonly).
--                                 Keys: host, port, socket, user,
--                                 database, defaults_file, extra.
--   :MariadbDetach                 Detach the current buffer's connection.
--   :MariadbRun                    Run the buffer, or a visual range, as
--                                   SQL.
--   :MariadbTables                 List tables in the attached database.
--   :MariadbDatabases               List all databases on the server.
--   :MariadbSchema [table]          SHOW CREATE TABLE, or SHOW TABLES.
--   :MariadbTerminal                Open an interactive mariadb REPL.
--   :MariadbInfo                    Show the current buffer's connection
--                                   info.
--
-- Agent API:
--   require('config.data.mariadb').query(conn, sql, on_result, opts)
--   require('config.data.mariadb').query_sync(conn, sql, opts)
--   require('config.data.mariadb').query_buffer(bufnr, sql, on_result, opts)
--   -- opts.readonly defaults to true for all three; pass
--   -- { readonly = false } to allow the query to write.
--
-- Agent result rows come from --batch --raw --binary-as-hex tab-separated
-- output, parsed into an array of tables keyed by column name — the same
-- approach and the same single-statement-per-call constraint as
-- lua/config/data/mysql.lua.
--
-- extra: the original s:command_for_url forwarded every URL query param
-- as a bare --key=value flag, with no allowlist. This module keeps that
-- escape hatch (conn.extra, a table of flag-name -> value) for MariaDB
-- options this module has no dedicated field for (e.g. ssl_mode,
-- connect_timeout), but validates each key looks like a plausible
-- long-option name before building argv from it, since conn.extra keys
-- ultimately become literal argv tokens.
--
-- Suggested (optional, not applied here) follow-up: add --binary-as-hex
-- to lua/config/data/mysql.lua's agent-mode flags too. mysql.lua's
-- --batch --raw parser has the same theoretical exposure to unescaped
-- binary column data as this module would have without the flag; nothing
-- in this conversation has required it yet, but it is the same gap.

local api = vim.api
local fs = vim.fs
local uv = vim.uv

local M = {}

local EXTRA_KEY_COUNT_MAX = 16
local KEY_COUNT_MAX = 8
local QUERY_TIMEOUT_MS = 15000
local RESULT_LINE_COUNT_MAX = 5000
local SQL_BYTES_MAX = 1048576

local READONLY_INIT_COMMAND = 'SET SESSION TRANSACTION READ ONLY'

local CONNECTION_KEYS = {
        database = true,
        defaults_file = true,
        host = true,
        port = true,
        socket = true,
        user = true,
}

local defaults = {
        notify = true,
}

---@class QompassMariadbConfigOpts
---@field notify? boolean

---@type QompassMariadbConfigOpts
M.config = vim.deepcopy(defaults)

---@class QompassMariadbConnection
---@field database? string
---@field defaults_file? string
---@field extra? table<string, string>
---@field host? string
---@field port? integer
---@field socket? string
---@field user? string

---@class QompassMariadbSession
---@field bufnr integer
---@field conn QompassMariadbConnection
---@field readonly boolean
---@field root string

---@class QompassMariadbQueryOpts
---@field readonly? boolean

M.state = {
        ---@type table<integer, QompassMariadbSession>
        sessions = {},
}

---@param message string
---@param level? integer
local function notify(message, level)
        if not M.config.notify then
                return
        end

        vim.notify(message, level or vim.log.levels.INFO, {
                title = 'mariadb',
        })
end

---@return boolean
local function has_mariadb()
        return vim.fn.executable('mariadb') == 1
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

---@param key string
---@return boolean
local function extra_key_is_safe(key)
        return type(key) == 'string' and key:match('^[%w][%w_-]*$') ~= nil
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

---@param conn QompassMariadbConnection
---@return boolean
---@return string|nil
local function validate_connection(conn)
        if type(conn) ~= 'table' then
                return false, 'connection must be a table'
        end

        if conn.password ~= nil then
                return false, 'password is not accepted directly; use defaults_file with a [client] section instead'
        end

        if conn.host ~= nil and not string_is_safe(conn.host) then
                return false, 'host must be a non-empty string'
        end

        if conn.socket ~= nil and not string_is_safe(conn.socket) then
                return false, 'socket must be a non-empty string'
        end

        if conn.user ~= nil and not string_is_safe(conn.user) then
                return false, 'user must be a non-empty string'
        end

        if conn.database ~= nil and not string_is_safe(conn.database) then
                return false, 'database must be a non-empty string'
        end

        if conn.defaults_file ~= nil and not string_is_safe(conn.defaults_file) then
                return false, 'defaults_file must be a non-empty string'
        end

        if conn.port ~= nil then
                if type(conn.port) ~= 'number' or conn.port % 1 ~= 0 then
                        return false, 'port must be an integer'
                end

                if conn.port < 1 or conn.port > 65535 then
                        return false, 'port must be between 1 and 65535'
                end
        end

        if conn.extra ~= nil then
                if type(conn.extra) ~= 'table' then
                        return false, 'extra must be a table'
                end

                local count = 0

                for key, value in pairs(conn.extra) do
                        count = count + 1

                        if count > EXTRA_KEY_COUNT_MAX then
                                return false, 'extra has too many keys'
                        end

                        if key == 'password' then
                                return false, 'extra.password is not accepted; use defaults_file instead'
                        end

                        if not extra_key_is_safe(key) then
                                return false, 'extra key is not a plausible flag name: ' .. tostring(key)
                        end

                        if not string_is_safe(value) then
                                return false, 'extra.' .. key .. ' must be a non-empty string'
                        end
                end
        end

        if conn.host == nil and conn.socket == nil and conn.defaults_file == nil then
                return false, 'connection needs at least one of host, socket, or defaults_file'
        end

        return true, nil
end

---@param bufnr integer
---@return QompassMariadbSession|nil
local function get_session(bufnr)
        if not buffer_is_usable(bufnr) then
                return nil
        end

        return M.state.sessions[bufnr]
end

---@param opts QompassMariadbQueryOpts|nil
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

---@param conn QompassMariadbConnection
---@param readonly boolean
---@param mode_flags string[]
---@return string[]
local function build_argv(conn, readonly, mode_flags)
        local argv = { 'mariadb' }

        -- --defaults-extra-file must be the first option on the command
        -- line, before any other flag, or the client rejects it. Same
        -- constraint as mysql.lua; the mariadb client shares the option
        -- parser.
        if conn.defaults_file ~= nil then
                argv[#argv + 1] = '--defaults-extra-file=' .. conn.defaults_file
        end

        if conn.host ~= nil then
                argv[#argv + 1] = '--host=' .. conn.host
        end

        if conn.port ~= nil then
                argv[#argv + 1] = '--port=' .. tostring(conn.port)
        end

        if conn.socket ~= nil then
                argv[#argv + 1] = '--socket=' .. conn.socket
        end

        if conn.user ~= nil then
                argv[#argv + 1] = '--user=' .. conn.user
        end

        if conn.extra ~= nil then
                local keys = {}

                for key in pairs(conn.extra) do
                        keys[#keys + 1] = key
                end

                table.sort(keys)

                for _, key in ipairs(keys) do
                        argv[#argv + 1] = '--' .. key .. '=' .. conn.extra[key]
                end
        end

        if readonly then
                argv[#argv + 1] = '--init-command=' .. READONLY_INIT_COMMAND
        end

        argv[#argv + 1] = '--binary-as-hex'

        for _, flag in ipairs(mode_flags or {}) do
                argv[#argv + 1] = flag
        end

        if conn.database ~= nil then
                argv[#argv + 1] = conn.database
        end

        return argv
end

---@param bufnr integer
---@param conn QompassMariadbConnection
---@param readonly? boolean
---@return QompassMariadbSession|nil
---@return string|nil
function M.attach(bufnr, conn, readonly)
        bufnr = bufnr or api.nvim_get_current_buf()

        if not buffer_is_usable(bufnr) then
                return nil, 'invalid buffer'
        end

        if not has_mariadb() then
                return nil, 'mariadb executable was not found on PATH'
        end

        local valid, validation_error = validate_connection(conn)

        if not valid then
                return nil, validation_error
        end

        ---@type QompassMariadbSession
        local session = {
                bufnr = bufnr,
                conn = vim.deepcopy(conn),
                readonly = readonly == true,
                root = resolve_root(bufnr),
        }

        M.state.sessions[bufnr] = session
        notify(
                'Attached '
                        .. (conn.database or '(no default database)')
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
                        defaults_file = session.conn.defaults_file,
                        extra = session.conn.extra,
                        host = session.conn.host,
                        port = session.conn.port,
                        socket = session.conn.socket,
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
                lines[#lines + 1] = string.format(
                        '-- output truncated at %d lines --',
                        RESULT_LINE_COUNT_MAX
                )
        end

        local bufnr = api.nvim_create_buf(false, true)
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        api.nvim_buf_set_name(bufnr, title)

        vim.bo[bufnr].buftype = 'nofile'
        vim.bo[bufnr].bufhidden = 'wipe'
        vim.bo[bufnr].swapfile = false
        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].filetype = 'mariadbresult'

        vim.cmd('botright split')
        api.nvim_win_set_buf(api.nvim_get_current_win(), bufnr)
        api.nvim_win_set_height(api.nvim_get_current_win(), math.min(20, #lines + 1))
end

---@param conn QompassMariadbConnection
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

---@param session QompassMariadbSession
---@param sql string
---@param title string
local function run_and_show(session, sql, title)
        run_process(session.conn, session.readonly, sql, { '--table' }, function(result)
                if result.code ~= 0 then
                        local message = result.stderr ~= '' and result.stderr
                                or 'mariadb exited with code ' .. result.code
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

---@param output string
---@return table[]
local function parse_tsv_rows(output)
        local lines = vim.split(output, '\n', {
                plain = true,
                trimempty = true,
        })

        if #lines == 0 then
                return {}
        end

        local headers = vim.split(lines[1], '\t', { plain = true })
        local rows = {}

        for line_index = 2, #lines do
                local cells = vim.split(lines[line_index], '\t', { plain = true })
                local row = {}

                for column_index, header in ipairs(headers) do
                        local cell = cells[column_index]

                        if cell ~= nil and cell ~= 'NULL' then
                                row[header] = cell
                        end
                end

                rows[#rows + 1] = row
        end

        return rows
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
---concatenated tab-separated blocks this parser does not separate.
---
---@param conn QompassMariadbConnection
---@param sql string SQL text to run.
---@param on_result fun(rows: table[]|nil, err: string|nil)
---@param opts? QompassMariadbQueryOpts
function M.query(conn, sql, on_result, opts)
        if not has_mariadb() then
                on_result(nil, 'mariadb executable was not found on PATH')
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

        run_process(conn, readonly, sql, { '--batch', '--raw' }, function(result)
                if result.code ~= 0 then
                        on_result(nil, result.stderr ~= '' and result.stderr
                                or 'mariadb exited with code ' .. result.code)
                        return
                end

                on_result(parse_tsv_rows(result.stdout or ''), nil)
        end)
end

---Blocking variant of M.query for scripted/headless callers.
---
---opts.readonly defaults to true, matching M.query.
---
---@param conn QompassMariadbConnection
---@param sql string SQL text to run.
---@param opts? QompassMariadbQueryOpts
---@return table[]|nil rows
---@return string|nil err
function M.query_sync(conn, sql, opts)
        if not has_mariadb() then
                return nil, 'mariadb executable was not found on PATH'
        end

        local valid, validation_error = validate_connection(conn)

        if not valid then
                return nil, validation_error
        end

        if type(sql) ~= 'string' or sql:match('^%s*$') then
                return nil, 'sql must be a non-empty string'
        end

        local readonly = resolve_query_readonly(opts)

        local result = vim.system(build_argv(conn, readonly, { '--batch', '--raw' }), {
                stdin = sql,
                text = true,
                timeout = QUERY_TIMEOUT_MS,
        }):wait()

        if result.code ~= 0 then
                return nil, result.stderr ~= '' and result.stderr
                        or 'mariadb exited with code ' .. result.code
        end

        return parse_tsv_rows(result.stdout or ''), nil
end

---opts.readonly defaults to true, independent of the session's own
---readonly state, matching M.query and M.query_sync. Pass
---{ readonly = false } to allow a write against a read/write session.
---
---@param bufnr integer
---@param sql string
---@param on_result fun(rows: table[]|nil, err: string|nil)
---@param opts? QompassMariadbQueryOpts
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
                notify('No connection is attached to this buffer. Use :MariadbAttach first', vim.log.levels.ERROR)
                return
        end

        local sql = buffer_sql(bufnr, opts.line1, opts.line2)

        if sql:match('^%s*$') then
                notify('No SQL to run', vim.log.levels.WARN)
                return
        end

        run_and_show(session, sql, 'mariadb://' .. (session.conn.database or 'default') .. ' [result]')
end

function M.tables()
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :MariadbAttach first', vim.log.levels.ERROR)
                return
        end

        run_and_show(session, 'SHOW TABLES;', 'mariadb://' .. (session.conn.database or 'default') .. ' [tables]')
end

function M.databases()
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :MariadbAttach first', vim.log.levels.ERROR)
                return
        end

        run_and_show(session, 'SHOW DATABASES;', 'mariadb://' .. (session.conn.host or 'default') .. ' [databases]')
end

---@param identifier string
---@return string
local function quote_identifier(identifier)
        return '`' .. identifier:gsub('`', '``') .. '`'
end

---@param table_name? string
function M.schema(table_name)
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :MariadbAttach first', vim.log.levels.ERROR)
                return
        end

        local sql = table_name and table_name ~= ''
                and string.format('SHOW CREATE TABLE %s;', quote_identifier(table_name))
                or 'SHOW TABLES;'

        run_and_show(session, sql, 'mariadb://' .. (session.conn.database or 'default') .. ' [schema]')
end

function M.terminal()
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :MariadbAttach first', vim.log.levels.ERROR)
                return
        end

        if not has_mariadb() then
                notify('mariadb executable was not found on PATH', vim.log.levels.ERROR)
                return
        end

        local argv = build_argv(session.conn, session.readonly, {})

        vim.cmd('botright split')
        vim.fn.termopen(argv)
        vim.cmd('startinsert')
end

---@param args string
---@return QompassMariadbConnection|nil
---@return string|nil
local function parse_connection_args(args)
        local tokens = vim.split(args, '%s+', { trimempty = true })

        if #tokens > KEY_COUNT_MAX then
                return nil, 'too many connection arguments'
        end

        local conn = {}

        for _, token in ipairs(tokens) do
                local key, value = token:match('^([%w_.]+)=(.*)$')

                if key == nil then
                        return nil, 'malformed argument (expected key=value): ' .. token
                end

                if key == 'port' then
                        conn.port = tonumber(value)

                        if conn.port == nil then
                                return nil, 'port must be numeric'
                        end
                elseif CONNECTION_KEYS[key] then
                        conn[key] = value
                elseif key:sub(1, 6) == 'extra.' then
                        conn.extra = conn.extra or {}
                        conn.extra[key:sub(7)] = value
                else
                        return nil, 'unknown connection key: ' .. key
                end
        end

        return conn, nil
end

local function create_commands()
        api.nvim_create_user_command('MariadbAttach', function(opts)
                if opts.args == '' then
                        notify(
                                'Usage: :MariadbAttach[!] host=... port=... user=... database=... defaults_file=... extra.ssl-mode=...',
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
                desc = 'Attach a MariaDB connection to the current buffer (bang = readonly)',
                nargs = 1,
        })

        api.nvim_create_user_command('MariadbDetach', function()
                M.detach(api.nvim_get_current_buf())
        end, {
                desc = 'Detach the MariaDB connection from the current buffer',
        })

        api.nvim_create_user_command('MariadbRun', function(opts)
                M.run(opts)
        end, {
                desc = 'Run the buffer, or a visual range, as SQL against the attached connection',
                range = '%',
        })

        api.nvim_create_user_command('MariadbTables', function()
                M.tables()
        end, {
                desc = 'List tables in the attached MariaDB database',
        })

        api.nvim_create_user_command('MariadbDatabases', function()
                M.databases()
        end, {
                desc = 'List all databases on the server',
        })

        api.nvim_create_user_command('MariadbSchema', function(opts)
                M.schema(opts.args ~= '' and opts.args or nil)
        end, {
                desc = 'Show schema for one table, or list tables',
                nargs = '?',
        })

        api.nvim_create_user_command('MariadbTerminal', function()
                M.terminal()
        end, {
                desc = 'Open an interactive mariadb REPL for the attached connection',
        })

        api.nvim_create_user_command('MariadbInfo', function()
                M.info(api.nvim_get_current_buf())
        end, {
                desc = "Show the current buffer's MariaDB connection info",
        })
end

local function create_autocmds()
        local group = api.nvim_create_augroup('QompassNativeMariadb', {
                clear = true,
        })

        api.nvim_create_autocmd('BufDelete', {
                callback = function(args)
                        M.state.sessions[args.buf] = nil
                end,
                group = group,
        })
end

---@param opts? QompassMariadbConfigOpts
---@return table
function M.setup(opts)
        M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

        if not has_mariadb() then
                notify(
                        'mariadb executable was not found on PATH. '
                                .. 'Install it (e.g. `pacman -S mariadb-clients` on Arch) to use :Mariadb* commands.',
                        vim.log.levels.WARN
                )
        end

        create_commands()
        create_autocmds()

        return M
end

return M