-- #################################################################
-- qompassai/Diver/lua/config/data/redis.lua
-- Qompass AI Diver Native Redis Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Plugin-free Redis tooling for Neovim 0.13+.
--
-- Talks to the `redis-cli` CLI directly through vim.system and :terminal.
-- No vim-dadbod, no plugin, no FFI binding. Sibling of
-- lua/config/data/mysql.lua and lua/config/data/psql.lua: connection-based
-- like both of them, since Redis is client-server, not an embedded file.
--
-- Ported from db/adapter/redis.vim's five functions. Mapping:
--   input_extension()  -> M.redis_ftd() registers the *.redis extension;
--                          we send commands over stdin directly rather
--                          than through a named temp file, so there is no
--                          literal equivalent to reproduce.
--   canonicalize(url)   -> not needed. The vim version rewrote "redis:" or
--                          "redis:/" into "redis:///" so a missing host
--                          fell through to a fixed default. Here, omitting
--                          conn.host/conn.port simply omits -h/-p from
--                          argv, and redis-cli's own built-in default
--                          (127.0.0.1:6379) takes over — no string surgery
--                          needed.
--   interactive(url)    -> M.terminal(), using the same flag mapping
--                          (-h, -p, --user, -n) plus --tls for rediss.
--   auth_input/pattern  -> not reproduced. Those existed to probe for an
--                          auth error and then inputsecret()-prompt for a
--                          password. This module asks for the password
--                          upfront (via REDISCLI_AUTH, see below) instead
--                          of trying blind and retrying interactively; a
--                          missing/wrong password just surfaces as a
--                          normal NOAUTH error.
--
-- Credentials: unlike lua/config/data/mysql.lua and psql.lua, this module
-- DOES accept a bare password field, because Redis's own documentation
-- explicitly recommends REDISCLI_AUTH as the safe way to supply one:
--   "For security reasons, provide the password to redis-cli
--    automatically via the REDISCLI_AUTH environment variable."
--   https://redis.io/docs/latest/develop/tools/cli/
-- MySQL's and Postgres's equivalents (MYSQL_PWD, plain env password) are
-- explicitly the opposite: their own docs call the env-var route insecure
-- and deprecated. conn.password here is passed to the subprocess via
-- vim.system's env option, so it never touches argv or `ps`, and never
-- gets the -a flag (which redis-cli itself warns is unsafe).
--
-- Readonly: Redis has no client-side readonly flag and no session-level
-- read-only GUC like Postgres/MySQL. opts.readonly here adds a client-side
-- check that rejects a fixed list of known write command names before
-- sending anything — this is a typo guard for accidental agent mistakes,
-- NOT a security boundary. It is trivially bypassed (EVAL/FUNCTION can run
-- arbitrary write commands from inside a script, MULTI/EXEC is not
-- inspected line-by-line, etc.). For real enforcement, connect as a Redis
-- ACL user restricted to read-only commands and pass that as conn.user.
--
-- Two access paths are provided on purpose:
--   1. Human commands (:Redis*) for interactive use in a buffer. These
--      follow whatever readonly state the buffer's session was attached
--      with (:RedisAttach! for readonly, :RedisAttach for read/write).
--   2. A buffer-independent Lua API (M.query / M.query_sync) for AI agents
--      or scripts that call this module directly, with no buffer, no
--      window, and no notify() side effects — just a value or an error.
--      Agent calls default to readonly = true. A caller must pass
--      { readonly = false } explicitly to allow write commands.
--
-- Redis has no rows/columns, so the agent API does not force one. M.query
-- returns whatever --json decodes to for that command: a string, a
-- number, an array, an object, or nil. This is a deliberate difference
-- from the sqlite/duckdb/mysql/psql siblings' array-of-row-tables shape;
-- see the "init.lua change" note at the bottom of this header.
--
-- Commands:
--   :RedisAttach[!] key=val ...   Attach a connection (bang = readonly).
--                                 Keys: host, port, user, database,
--                                 password, tls.
--   :RedisDetach                   Detach the current buffer's connection.
--   :RedisRun                      Run the buffer, or a visual range, as
--                                   one Redis command per line.
--   :RedisKeys [pattern]           Scan keys matching pattern (default *)
--                                   using --scan, not the blocking KEYS.
--   :RedisServerInfo [section]     Run the Redis INFO command.
--   :RedisTerminal                 Open an interactive redis-cli REPL.
--   :RedisInfo                     Show the current buffer's connection
--                                   info. (Session info, not server INFO —
--                                   named to match the other three
--                                   siblings' M.info(bufnr) convention;
--                                   use :RedisServerInfo for the Redis
--                                   INFO command.)
--
-- Agent API:
--   require('config.data.redis').query(conn, command, on_result, opts)
--   require('config.data.redis').query_sync(conn, command, opts)
--   require('config.data.redis').query_buffer(bufnr, command, on_result, opts)
--   -- opts.readonly defaults to true for all three; pass
--   -- { readonly = false } to allow a write command through.
--
-- Required change to lua/config/data/init.lua for this to render cleanly:
-- its render_rows() assumes an array of row-tables, which is what
-- sqlite/duckdb/mysql/psql all return. Redis does not fit that shape, so
-- init.lua's result renderer needs a small, additive branch: if the
-- decoded value is not an array of tables, render it directly (vim.inspect
-- for a table, tostring otherwise) instead of calling render_rows on it.
-- sqlite.lua and psql.lua need NO changes at all — their results were
-- already shaped correctly; only the generic renderer in init.lua needs
-- to stop assuming every backend returns that shape.

local api = vim.api
local fs = vim.fs

local M = {}

local KEY_COUNT_MAX = 8
local QUERY_TIMEOUT_MS = 15000
local RESULT_LINE_COUNT_MAX = 5000
local COMMAND_BYTES_MAX = 1048576

local CONNECTION_KEYS = {
        database = true,
        host = true,
        password = true,
        port = true,
        tls = true,
        user = true,
}

-- Best-effort, non-exhaustive typo guard for opts.readonly. Not a security
-- boundary: EVAL/FUNCTION/MULTI can still write, and this list will never
-- cover every write command Redis modules and future versions add.
local WRITE_COMMAND_NAMES = {
        APPEND = true, COPY = true, DECR = true, DECRBY = true, DEL = true,
        EVAL = true, EVALSHA = true, EXPIRE = true, EXPIREAT = true,
        FCALL = true, FLUSHALL = true, FLUSHDB = true, FUNCTION = true,
        GETDEL = true, GETSET = true, HDEL = true, HINCRBY = true,
        HINCRBYFLOAT = true, HMSET = true, HSET = true, HSETNX = true,
        INCR = true, INCRBY = true, INCRBYFLOAT = true, LINSERT = true,
        LPOP = true, LPUSH = true, LPUSHX = true, LREM = true, LSET = true,
        LTRIM = true, MOVE = true, MSET = true, MSETNX = true,
        PERSIST = true, PEXPIRE = true, PFADD = true, PFMERGE = true,
        PSETEX = true, RENAME = true, RENAMENX = true, RESTORE = true,
        RPOP = true, RPUSH = true, RPUSHX = true, SADD = true, SET = true,
        SETEX = true, SETNX = true, SETRANGE = true, SDIFFSTORE = true,
        SINTERSTORE = true, SMOVE = true, SPOP = true, SREM = true,
        SUNIONSTORE = true, UNLINK = true, XADD = true, XDEL = true,
        XTRIM = true, ZADD = true, ZINCRBY = true, ZPOPMAX = true,
        ZPOPMIN = true, ZREM = true, ZREMRANGEBYRANK = true,
        ZREMRANGEBYSCORE = true, ZREMRANGEBYLEX = true,
}

local defaults = {
        notify = true,
}

---@class QompassRedisConfigOpts
---@field notify? boolean

---@type QompassRedisConfigOpts
M.config = vim.deepcopy(defaults)

---@class QompassRedisConnection
---@field database? integer
---@field host? string
---@field password? string
---@field port? integer
---@field tls? boolean
---@field user? string

---@class QompassRedisSession
---@field bufnr integer
---@field conn QompassRedisConnection
---@field readonly boolean
---@field root string

---@class QompassRedisQueryOpts
---@field readonly? boolean

M.state = {
        ---@type table<integer, QompassRedisSession>
        sessions = {},
}

---@param message string
---@param level? integer
local function notify(message, level)
        if not M.config.notify then
                return
        end

        vim.notify(message, level or vim.log.levels.INFO, {
                title = 'redis',
        })
end

---@return boolean
local function has_redis_cli()
        return vim.fn.executable('redis-cli') == 1
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

---@param conn QompassRedisConnection
---@return boolean
---@return string|nil
local function validate_connection(conn)
        if type(conn) ~= 'table' then
                return false, 'connection must be a table'
        end

        if conn.host ~= nil and not string_is_safe(conn.host) then
                return false, 'host must be a non-empty string'
        end

        if conn.user ~= nil and not string_is_safe(conn.user) then
                return false, 'user must be a non-empty string'
        end

        if conn.password ~= nil and type(conn.password) ~= 'string' then
                return false, 'password must be a string'
        end

        if conn.port ~= nil then
                if type(conn.port) ~= 'number' or conn.port % 1 ~= 0 then
                        return false, 'port must be an integer'
                end

                if conn.port < 1 or conn.port > 65535 then
                        return false, 'port must be between 1 and 65535'
                end
        end

        if conn.database ~= nil then
                if type(conn.database) ~= 'number' or conn.database % 1 ~= 0 then
                        return false, 'database must be an integer'
                end

                if conn.database < 0 then
                        return false, 'database must be zero or greater'
                end
        end

        if conn.tls ~= nil and type(conn.tls) ~= 'boolean' then
                return false, 'tls must be a boolean'
        end

        return true, nil
end

---@param bufnr integer
---@return QompassRedisSession|nil
local function get_session(bufnr)
        if not buffer_is_usable(bufnr) then
                return nil
        end

        return M.state.sessions[bufnr]
end

---@param opts QompassRedisQueryOpts|nil
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

---@param command string
---@return boolean
---@return string|nil
local function check_readonly_command(command)
        local name = command:match('^%s*(%a+)')

        if name == nil then
                return true, nil
        end

        if WRITE_COMMAND_NAMES[name:upper()] then
                return false, string.format(
                        '%s looks like a write command; refusing under readonly (pass { readonly = false } to override)',
                        name:upper()
                )
        end

        return true, nil
end

---@param conn QompassRedisConnection
---@param mode_flags string[]
---@return string[]
local function build_argv(conn, mode_flags)
        local argv = { 'redis-cli', '--no-auth-warning' }

        if conn.tls then
                argv[#argv + 1] = '--tls'
        end

        if conn.host ~= nil then
                argv[#argv + 1] = '-h'
                argv[#argv + 1] = conn.host
        end

        if conn.port ~= nil then
                argv[#argv + 1] = '-p'
                argv[#argv + 1] = tostring(conn.port)
        end

        if conn.user ~= nil then
                argv[#argv + 1] = '--user'
                argv[#argv + 1] = conn.user
        end

        if conn.database ~= nil then
                argv[#argv + 1] = '-n'
                argv[#argv + 1] = tostring(conn.database)
        end

        for _, flag in ipairs(mode_flags or {}) do
                argv[#argv + 1] = flag
        end

        return argv
end

---@param conn QompassRedisConnection
---@return table<string, string>|nil
local function build_env(conn)
        if conn.password == nil then
                return nil
        end

        return { REDISCLI_AUTH = conn.password }
end

---@param bufnr integer
---@param conn QompassRedisConnection
---@param readonly? boolean
---@return QompassRedisSession|nil
---@return string|nil
function M.attach(bufnr, conn, readonly)
        bufnr = bufnr or api.nvim_get_current_buf()

        if not buffer_is_usable(bufnr) then
                return nil, 'invalid buffer'
        end

        if not has_redis_cli() then
                return nil, 'redis-cli executable was not found on PATH'
        end

        local valid, validation_error = validate_connection(conn)

        if not valid then
                return nil, validation_error
        end

        ---@type QompassRedisSession
        local session = {
                bufnr = bufnr,
                conn = vim.deepcopy(conn),
                readonly = readonly == true,
                root = resolve_root(bufnr),
        }

        M.state.sessions[bufnr] = session
        notify(
                'Attached '
                        .. (conn.host or '127.0.0.1')
                        .. ':'
                        .. tostring(conn.port or 6379)
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
                        port = session.conn.port,
                        tls = session.conn.tls,
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
        vim.bo[bufnr].filetype = 'redisresult'

        vim.cmd('botright split')
        api.nvim_win_set_buf(api.nvim_get_current_win(), bufnr)
        api.nvim_win_set_height(api.nvim_get_current_win(), math.min(20, #lines + 1))
end

---@param conn QompassRedisConnection
---@param input string
---@param mode_flags string[]
---@param on_done fun(result: vim.SystemCompleted)
local function run_process(conn, input, mode_flags, on_done)
        assert(type(input) == 'string')
        assert(#input <= COMMAND_BYTES_MAX, 'command exceeds size bound')

        vim.system(build_argv(conn, mode_flags), {
                env = build_env(conn),
                stdin = input,
                text = true,
                timeout = QUERY_TIMEOUT_MS,
        }, function(result)
                vim.schedule(function()
                        on_done(result)
                end)
        end)
end

---@param session QompassRedisSession
---@param input string
---@param title string
local function run_and_show(session, input, title)
        run_process(session.conn, input, {}, function(result)
                if result.code ~= 0 then
                        local message = result.stderr ~= '' and result.stderr
                                or 'redis-cli exited with code ' .. result.code
                        notify(message, vim.log.levels.ERROR)
                        return
                end

                local output = result.stdout or ''
                local lines = vim.split(output, '\n', {
                        plain = true,
                        trimempty = true,
                })

                if #lines == 0 then
                        lines = { '-- no output --' }
                end

                show_result_buffer(lines, title)
        end)
end

---Run a single Redis command and return its decoded --json value.
---
---This is the agent-facing entry point: it takes an explicit connection
---rather than reading buffer state, produces no notify() calls, and hands
---back whatever --json decodes to (string, number, array, object, or nil)
---or an error string. Safe to call from a script, a keymap, or an
---external Lua caller with no buffer/window.
---
---opts.readonly defaults to true and is a typo guard only, checked
---against a fixed, non-exhaustive list of write command names — see the
---file header. It is not a security boundary.
---
---Send one command per call; --json covers a single command's reply.
---
---@param conn QompassRedisConnection
---@param command string Redis command to run, e.g. "GET mykey".
---@param on_result fun(value: any, err: string|nil)
---@param opts? QompassRedisQueryOpts
function M.query(conn, command, on_result, opts)
        if not has_redis_cli() then
                on_result(nil, 'redis-cli executable was not found on PATH')
                return
        end

        local valid, validation_error = validate_connection(conn)

        if not valid then
                on_result(nil, validation_error)
                return
        end

        if type(command) ~= 'string' or command:match('^%s*$') then
                on_result(nil, 'command must be a non-empty string')
                return
        end

        if resolve_query_readonly(opts) then
                local allowed, guard_error = check_readonly_command(command)

                if not allowed then
                        on_result(nil, guard_error)
                        return
                end
        end

        run_process(conn, command, { '-3', '--json' }, function(result)
                if result.code ~= 0 then
                        on_result(nil, result.stderr ~= '' and result.stderr
                                or 'redis-cli exited with code ' .. result.code)
                        return
                end

                local output = (result.stdout or ''):match('^%s*(.-)%s*$')

                if output == '' then
                        on_result(nil, nil)
                        return
                end

                local ok, decoded = pcall(vim.json.decode, output)

                if not ok then
                        on_result(nil, 'failed to decode redis-cli JSON output: ' .. tostring(decoded))
                        return
                end

                on_result(decoded, nil)
        end)
end

---Blocking variant of M.query for scripted/headless callers.
---
---opts.readonly defaults to true, matching M.query.
---
---@param conn QompassRedisConnection
---@param command string Redis command to run.
---@param opts? QompassRedisQueryOpts
---@return any value
---@return string|nil err
function M.query_sync(conn, command, opts)
        if not has_redis_cli() then
                return nil, 'redis-cli executable was not found on PATH'
        end

        local valid, validation_error = validate_connection(conn)

        if not valid then
                return nil, validation_error
        end

        if type(command) ~= 'string' or command:match('^%s*$') then
                return nil, 'command must be a non-empty string'
        end

        if resolve_query_readonly(opts) then
                local allowed, guard_error = check_readonly_command(command)

                if not allowed then
                        return nil, guard_error
                end
        end

        local result = vim.system(build_argv(conn, { '-3', '--json' }), {
                env = build_env(conn),
                stdin = command,
                text = true,
                timeout = QUERY_TIMEOUT_MS,
        }):wait()

        if result.code ~= 0 then
                return nil, result.stderr ~= '' and result.stderr
                        or 'redis-cli exited with code ' .. result.code
        end

        local output = (result.stdout or ''):match('^%s*(.-)%s*$')

        if output == '' then
                return nil, nil
        end

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok then
                return nil, 'failed to decode redis-cli JSON output: ' .. tostring(decoded)
        end

        return decoded, nil
end

---opts.readonly defaults to true, independent of the session's own
---readonly state, matching M.query and M.query_sync. Pass
---{ readonly = false } to allow a write command against a read/write
---session.
---
---@param bufnr integer
---@param command string
---@param on_result fun(value: any, err: string|nil)
---@param opts? QompassRedisQueryOpts
function M.query_buffer(bufnr, command, on_result, opts)
        local session = get_session(bufnr)

        if session == nil then
                on_result(nil, 'no connection is attached to this buffer')
                return
        end

        M.query(session.conn, command, on_result, opts)
end

---@param bufnr integer
---@param line1 integer
---@param line2 integer
---@return string
local function buffer_commands(bufnr, line1, line2)
        local lines = api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
        return table.concat(lines, '\n')
end

---@param opts vim.api.keyset.create_user_command.command_args
function M.run(opts)
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :RedisAttach first', vim.log.levels.ERROR)
                return
        end

        local input = buffer_commands(bufnr, opts.line1, opts.line2)

        if input:match('^%s*$') then
                notify('No commands to run', vim.log.levels.WARN)
                return
        end

        run_and_show(session, input, 'redis://' .. (session.conn.host or '127.0.0.1') .. ' [result]')
end

---@param pattern? string
function M.keys(pattern)
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :RedisAttach first', vim.log.levels.ERROR)
                return
        end

        local argv = build_argv(session.conn, { '--scan' })

        if pattern ~= nil and pattern ~= '' then
                argv[#argv + 1] = '--pattern'
                argv[#argv + 1] = pattern
        end

        vim.system(argv, {
                env = build_env(session.conn),
                text = true,
                timeout = QUERY_TIMEOUT_MS,
        }, function(result)
                vim.schedule(function()
                        if result.code ~= 0 then
                                notify(result.stderr ~= '' and result.stderr
                                        or 'redis-cli exited with code ' .. result.code, vim.log.levels.ERROR)
                                return
                        end

                        local lines = vim.split(result.stdout or '', '\n', {
                                plain = true,
                                trimempty = true,
                        })

                        if #lines == 0 then
                                lines = { '-- no keys --' }
                        end

                        show_result_buffer(lines, 'redis://' .. (session.conn.host or '127.0.0.1') .. ' [keys]')
                end)
        end)
end

---@param section? string
function M.server_info(section)
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :RedisAttach first', vim.log.levels.ERROR)
                return
        end

        local command = section and section ~= '' and ('INFO ' .. section) or 'INFO'

        run_and_show(session, command, 'redis://' .. (session.conn.host or '127.0.0.1') .. ' [info]')
end

function M.terminal()
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No connection is attached to this buffer. Use :RedisAttach first', vim.log.levels.ERROR)
                return
        end

        if not has_redis_cli() then
                notify('redis-cli executable was not found on PATH', vim.log.levels.ERROR)
                return
        end

        local argv = build_argv(session.conn, {})

        vim.cmd('botright split')
        vim.fn.jobstart(argv, {
                env = build_env(session.conn),
                term = true,
        })
        vim.cmd('startinsert')
end

---@param args string
---@return QompassRedisConnection|nil
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

                if key == 'port' or key == 'database' then
                        conn[key] = tonumber(value)

                        if conn[key] == nil then
                                return nil, key .. ' must be numeric'
                        end
                elseif key == 'tls' then
                        conn.tls = value == '1' or value:lower() == 'true'
                else
                        conn[key] = value
                end
        end

        return conn, nil
end

local function create_commands()
        api.nvim_create_user_command('RedisAttach', function(opts)
                if opts.args == '' then
                        notify(
                                'Usage: :RedisAttach[!] host=... port=... user=... database=... password=... tls=1',
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
                desc = 'Attach a Redis connection to the current buffer (bang = readonly)',
                nargs = 1,
        })

        api.nvim_create_user_command('RedisDetach', function()
                M.detach(api.nvim_get_current_buf())
        end, {
                desc = 'Detach the Redis connection from the current buffer',
        })

        api.nvim_create_user_command('RedisRun', function(opts)
                M.run(opts)
        end, {
                desc = 'Run the buffer, or a visual range, as Redis commands (one per line)',
                range = '%',
        })

        api.nvim_create_user_command('RedisKeys', function(opts)
                M.keys(opts.args ~= '' and opts.args or nil)
        end, {
                desc = 'Scan keys matching a pattern (default *) using --scan, not KEYS',
                nargs = '?',
        })

        api.nvim_create_user_command('RedisServerInfo', function(opts)
                M.server_info(opts.args ~= '' and opts.args or nil)
        end, {
                desc = 'Run the Redis INFO command, optionally for one section',
                nargs = '?',
        })

        api.nvim_create_user_command('RedisTerminal', function()
                M.terminal()
        end, {
                desc = 'Open an interactive redis-cli REPL for the attached connection',
        })

        api.nvim_create_user_command('RedisInfo', function()
                M.info(api.nvim_get_current_buf())
        end, {
                desc = "Show the current buffer's Redis connection info",
        })
end

local function create_autocmds()
        local group = api.nvim_create_augroup('QompassNativeRedis', {
                clear = true,
        })

        api.nvim_create_autocmd('BufDelete', {
                callback = function(args)
                        M.state.sessions[args.buf] = nil
                end,
                group = group,
        })
end

function M.redis_ftd()
        vim.filetype.add({
                extension = {
                        redis = 'redis',
                },
        })
end

---@param opts? QompassRedisConfigOpts
---@return table
function M.setup(opts)
        M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

        if not has_redis_cli() then
                notify(
                        'redis-cli executable was not found on PATH. '
                                .. 'Install it (e.g. `pacman -S redis` on Arch) to use :Redis* commands.',
                        vim.log.levels.WARN
                )
        end

        M.redis_ftd()
        create_commands()
        create_autocmds()

        return M
end

return M