-- #################################################################
-- qompassai/Diver/lua/config/data/sqlite.lua
-- Qompass AI Diver Native SQLite Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Plugin-free SQLite tooling for Neovim 0.13+.
--
-- Talks to the `sqlite3` CLI directly through vim.system and :terminal.
-- No vim-dadbod, no vim-dadbod-ui, no vim-dadbod-completion, no FFI binding.
--
-- Commands:
--   :SqliteAttach [path]     Attach a database file to the current buffer.
--   :SqliteDetach            Detach the current buffer's database.
--   :SqliteRun               Run the buffer, or a visual range, as SQL.
--   :SqliteTables            List tables in the attached database.
--   :SqliteSchema [table]    Show schema for the database or one table.
--   :SqliteTerminal          Open an interactive sqlite3 REPL in a split.
--   :SqliteInfo              Show the current buffer's attachment info.
--
-- Auto-attach: opening a *.sql buffer looks for exactly one sibling
-- *.sqlite3/*.sqlite/*.db file next to it, or in the project root, and
-- attaches it automatically. Ambiguous or missing candidates are left for
-- :SqliteAttach rather than guessed.

local api = vim.api
local fs = vim.fs
local uv = vim.uv

local M = {}

local DIRECTORY_ENTRY_COUNT_MAX = 256
local QUERY_TIMEOUT_MS = 15000
local RESULT_LINE_COUNT_MAX = 5000
local SQL_BYTES_MAX = 1048576

local DB_EXTENSIONS = {
        db = true,
        sqlite = true,
        sqlite3 = true,
}

local defaults = {
        auto_attach = true,
        command_flags = { '-batch', '-header', '-column' },
        notify = true,
}

---@class QompassSqliteConfigOpts
---@field auto_attach? boolean
---@field command_flags? string[]
---@field notify? boolean

---@type QompassSqliteConfigOpts
M.config = vim.deepcopy(defaults)

---@class QompassSqliteSession
---@field bufnr integer
---@field path string
---@field root string

M.state = {
        ---@type table<integer, QompassSqliteSession>
        sessions = {},
}

---@param message string
---@param level? integer
local function notify(message, level)
        if not M.config.notify then
                return
        end

        vim.notify(message, level or vim.log.levels.INFO, {
                title = 'sqlite',
        })
end

---@return boolean
local function has_sqlite3()
        return vim.fn.executable('sqlite3') == 1
end

---@param path string
---@return boolean
local function path_is_safe(path)
        if type(path) ~= 'string' then
                return false
        end

        if path == '' then
                return false
        end

        if path:find('%z') ~= nil then
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

---@param name string
---@return boolean
local function is_db_filename(name)
        if type(name) ~= 'string' then
                return false
        end

        local extension = name:match('%.([%w]+)$')

        if extension == nil then
                return false
        end

        return DB_EXTENSIONS[extension:lower()] == true
end

---@param directory string
---@return string[]
local function list_db_candidates(directory)
        if not path_is_safe(directory) then
                return {}
        end

        local handle = uv.fs_scandir(directory)

        if handle == nil then
                return {}
        end

        local candidates = {}
        local entry_count = 0

        while entry_count < DIRECTORY_ENTRY_COUNT_MAX do
                local name, kind = uv.fs_scandir_next(handle)

                if name == nil then
                        break
                end

                entry_count = entry_count + 1

                if kind == 'file' and is_db_filename(name) then
                        candidates[#candidates + 1] = fs.joinpath(directory, name)
                end
        end

        return candidates
end

---@param bufnr integer
---@return QompassSqliteSession|nil
local function get_session(bufnr)
        if not buffer_is_usable(bufnr) then
                return nil
        end

        return M.state.sessions[bufnr]
end

---@param bufnr integer
---@param path string
---@return QompassSqliteSession|nil
---@return string|nil
function M.attach(bufnr, path)
        bufnr = bufnr or api.nvim_get_current_buf()

        if not buffer_is_usable(bufnr) then
                return nil, 'invalid buffer'
        end

        if not has_sqlite3() then
                return nil, 'sqlite3 executable was not found on PATH'
        end

        if not path_is_safe(path) then
                return nil, 'path must be a non-empty string'
        end

        local resolved = vim.fs.normalize(path)
        local stat = uv.fs_stat(resolved)

        if stat == nil then
                return nil, 'database file does not exist: ' .. resolved
        end

        if stat.type ~= 'file' then
                return nil, 'database path is not a regular file: ' .. resolved
        end

        ---@type QompassSqliteSession
        local session = {
                bufnr = bufnr,
                path = resolved,
                root = resolve_root(bufnr),
        }

        M.state.sessions[bufnr] = session
        notify('Attached ' .. resolved)

        return session, nil
end

---@param bufnr? integer
function M.detach(bufnr)
        bufnr = bufnr or api.nvim_get_current_buf()

        if M.state.sessions[bufnr] == nil then
                notify('No database is attached to this buffer', vim.log.levels.WARN)
                return
        end

        M.state.sessions[bufnr] = nil
        notify('Detached database from buffer ' .. bufnr)
end

---@param bufnr? integer
function M.info(bufnr)
        bufnr = bufnr or api.nvim_get_current_buf()

        local session = get_session(bufnr)

        if session == nil then
                notify('No database is attached to this buffer', vim.log.levels.WARN)
                return
        end

        notify(vim.inspect({
                bufnr = session.bufnr,
                path = session.path,
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
        vim.bo[bufnr].filetype = 'sqliteresult'

        vim.cmd('botright split')
        api.nvim_win_set_buf(api.nvim_get_current_win(), bufnr)
        api.nvim_win_set_height(api.nvim_get_current_win(), math.min(20, #lines + 1))
end

---@param session QompassSqliteSession
---@param sql string
---@param on_done fun(result: vim.SystemCompleted)
local function run_batch(session, sql, on_done)
        assert(type(session) == 'table')
        assert(type(sql) == 'string')
        assert(#sql <= SQL_BYTES_MAX, 'query exceeds size bound')

        local argv = { 'sqlite3' }

        for _, flag in ipairs(M.config.command_flags) do
                argv[#argv + 1] = flag
        end

        argv[#argv + 1] = session.path

        vim.system(argv, {
                stdin = sql,
                text = true,
                timeout = QUERY_TIMEOUT_MS,
        }, function(result)
                vim.schedule(function()
                        on_done(result)
                end)
        end)
end

---@param session QompassSqliteSession
---@param sql string
---@param title string
local function run_and_show(session, sql, title)
        run_batch(session, sql, function(result)
                if result.code ~= 0 then
                        local message = result.stderr ~= '' and result.stderr or 'sqlite3 exited with code ' .. result.code
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

---@param bufnr integer
---@param line1 integer
---@param line2 integer
local function buffer_sql(bufnr, line1, line2)
        local lines = api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
        return table.concat(lines, '\n')
end

---@param opts vim.api.keyset.create_user_command.command_args
function M.run(opts)
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No database is attached to this buffer. Use :SqliteAttach first', vim.log.levels.ERROR)
                return
        end

        local sql = buffer_sql(bufnr, opts.line1, opts.line2)

        if sql:match('^%s*$') then
                notify('No SQL to run', vim.log.levels.WARN)
                return
        end

        run_and_show(session, sql, 'sqlite://' .. session.path .. ' [result]')
end

function M.tables()
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No database is attached to this buffer. Use :SqliteAttach first', vim.log.levels.ERROR)
                return
        end

        run_and_show(session, '.tables\n', 'sqlite://' .. session.path .. ' [tables]')
end

---@param table_name? string
function M.schema(table_name)
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No database is attached to this buffer. Use :SqliteAttach first', vim.log.levels.ERROR)
                return
        end

        local sql = table_name and table_name ~= ''
                and string.format('.schema %s\n', table_name)
                or '.schema\n'

        run_and_show(session, sql, 'sqlite://' .. session.path .. ' [schema]')
end

function M.terminal()
        local bufnr = api.nvim_get_current_buf()
        local session = get_session(bufnr)

        if session == nil then
                notify('No database is attached to this buffer. Use :SqliteAttach first', vim.log.levels.ERROR)
                return
        end

        if not has_sqlite3() then
                notify('sqlite3 executable was not found on PATH', vim.log.levels.ERROR)
                return
        end

        vim.cmd('botright split')
        vim.fn.termopen({ 'sqlite3', session.path })
        vim.cmd('startinsert')
end

---@param bufnr integer
local function try_auto_attach(bufnr)
        if not M.config.auto_attach then
                return
        end

        if get_session(bufnr) ~= nil then
                return
        end

        if not has_sqlite3() then
                return
        end

        local filename = api.nvim_buf_get_name(bufnr)

        if filename == '' then
                return
        end

        local directory = fs.dirname(filename)
        local candidates = list_db_candidates(directory)

        if #candidates == 0 then
                local root = resolve_root(bufnr)

                if root ~= directory then
                        candidates = list_db_candidates(root)
                end
        end

        if #candidates ~= 1 then
                return
        end

        M.attach(bufnr, candidates[1])
end

local function create_commands()
        api.nvim_create_user_command('SqliteAttach', function(opts)
                local path = opts.args

                if path == '' then
                        notify('Usage: :SqliteAttach path/to/database.sqlite3', vim.log.levels.ERROR)
                        return
                end

                local session, err = M.attach(api.nvim_get_current_buf(), path)

                if session == nil then
                        notify(err or 'failed to attach database', vim.log.levels.ERROR)
                end
        end, {
                complete = 'file',
                desc = 'Attach a SQLite database file to the current buffer',
                nargs = 1,
        })

        api.nvim_create_user_command('SqliteDetach', function()
                M.detach(api.nvim_get_current_buf())
        end, {
                desc = 'Detach the SQLite database from the current buffer',
        })

        api.nvim_create_user_command('SqliteRun', function(opts)
                M.run(opts)
        end, {
                desc = 'Run the buffer, or a visual range, as SQL against the attached database',
                range = '%',
        })

        api.nvim_create_user_command('SqliteTables', function()
                M.tables()
        end, {
                desc = 'List tables in the attached SQLite database',
        })

        api.nvim_create_user_command('SqliteSchema', function(opts)
                M.schema(opts.args ~= '' and opts.args or nil)
        end, {
                desc = 'Show schema for the attached database or one table',
                nargs = '?',
        })

        api.nvim_create_user_command('SqliteTerminal', function()
                M.terminal()
        end, {
                desc = 'Open an interactive sqlite3 REPL for the attached database',
        })

        api.nvim_create_user_command('SqliteInfo', function()
                M.info(api.nvim_get_current_buf())
        end, {
                desc = 'Show the current buffer\'s SQLite attachment info',
        })
end

local function create_autocmds()
        local group = api.nvim_create_augroup('QompassNativeSqlite', {
                clear = true,
        })

        api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
                callback = function(args)
                        try_auto_attach(args.buf)
                end,
                group = group,
                pattern = '*.sql',
        })

        api.nvim_create_autocmd('BufDelete', {
                callback = function(args)
                        M.state.sessions[args.buf] = nil
                end,
                group = group,
        })
end

function M.sqlite_ftd()
        vim.filetype.add({
                extension = {
                        db = 'sql',
                        sqlite = 'sql',
                        sqlite3 = 'sql',
                },
                pattern = {
                        ['%.lite%.sql$'] = 'sql',
                },
        })
end

---@param opts? QompassSqliteConfigOpts
---@return table
function M.setup(opts)
        M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

        if not has_sqlite3() then
                notify(
                        'sqlite3 executable was not found on PATH. '
                                .. 'Install it (e.g. `pacman -S sqlite` on Arch) to use :Sqlite* commands.',
                        vim.log.levels.WARN
                )
        end

        M.sqlite_ftd()
        create_commands()
        create_autocmds()

        return M
end

return M