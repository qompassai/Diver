-- #################################################################
-- qompassai/Diver/lua/config/data/init.lua
-- Qompass AI Diver Native Database Orchestrator
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Plugin-free re-implementation of vim-dadbod's db.vim :DB command for
-- Neovim 0.13+, dispatching across the native sibling backends:
--   lua/config/data/sqlite.lua   lua/config/data/duckdb.lua
--   lua/config/data/mysql.lua    lua/config/data/psql.lua
--
-- What this reproduces from db.vim:
--   - URL resolution: explicit arg > named connection (dbx.lua) > b:db >
--     g:db > $DATABASE_URL > last URL used this session.
--   - Scheme dispatch to the right backend (sqlite/duckdb file paths,
--     mysql/postgresql host-based connections), including scheme aliases
--     (sqlite3, mariadb, postgres, pg, ...).
--   - :DB[!] [url] [query] — no query and no range opens an interactive
--     REPL; a range or trailing text runs it and shows results in a
--     scratch buffer, exactly like db.vim's preview-window behavior.
--   - Range support for the current line, a visual selection, or the
--     whole buffer, via Neovim's range= command option.
--
-- What this deliberately does NOT reproduce, and why:
--   - Inline user:password@host URLs with inputsecret() prompting and an
--     in-memory password cache. Every sibling backend already refuses a
--     bare password field for the same reason db.vim's model is risky: a
--     password embedded in a URL or passed on argv is visible to other
--     local users via `ps`. Use ?service=, ?passfile=, or ?defaults_file=
--     in the URL instead, which the sibling backends read from a file.
--   - dbext buffer-variable clobbering (db#clobber_dbext). That was a
--     compatibility shim for a second, older plugin this project does not
--     use.
--   - `< filename` input redirection and window/tab-scoped w:db/t:db
--     tiers. Buffer-local (b:db) and global (g:db) cover the common case;
--     add window/tab tiers here later if you actually need them.
--   - Mid-query cancellation. Queries run through vim.system with a
--     bounded timeout (shared with the sibling backends) instead of an
--     open-ended cancellable job, so there is nothing long-running to
--     cancel. Interactive REPL sessions (:DB with no query) are real
--     :terminal buffers and can be closed/killed the normal Neovim way.
--
-- Commands:
--   :DB[!] [url] [query]   Attach (bang = readonly) and run or connect.
--   :DBUrl {url}            Set b:db for the current buffer.
--   :DBDetach                Detach whichever backend owns this buffer.
--   :DBInfo                  Show which backend/url owns this buffer.
--
-- Named connections: if ~/.config/nvim/dbx.lua exists and returns a table
-- of { name = "scheme://...", ... }, the first :DB argument is checked
-- against that table before being parsed as a literal URL, so
-- `:DB work SELECT 1;` can mean "the connection named work in dbx.lua".
--
-- Optional operator-pending mapping (not bound automatically):
--   vim.keymap.set('n', '<leader>dr', require('config.data').operator)
--   vim.keymap.set('x', '<leader>dr', ':DB<CR>')

local api = vim.api

local sqlite = require('config.data.sqlite')
local duckdb = require('config.data.duckdb')
local mysql = require('config.data.mysql')
local psql = require('config.data.psql')

local M = {}

local RESULT_LINE_COUNT_MAX = 5000

local BACKENDS = {
        sqlite = sqlite,
        duckdb = duckdb,
        mysql = mysql,
        psql = psql,
}

-- File-path backends take (bufnr, path, readonly). Connection backends
-- take (bufnr, conn_table, readonly). Both shapes line up positionally,
-- so dispatch through this table works without branching on backend kind.
local FILE_BACKENDS = {
        sqlite = true,
        duckdb = true,
}

local SCHEME_ALIASES = {
        db = 'sqlite',
        ddb = 'duckdb',
        duckdb = 'duckdb',
        mariadb = 'mysql',
        mysql = 'mysql',
        pg = 'psql',
        postgres = 'psql',
        postgresql = 'psql',
        psql = 'psql',
        sqlite = 'sqlite',
        sqlite3 = 'sqlite',
}

local FILE_EXTENSION_BACKENDS = {
        db = 'sqlite',
        ddb = 'duckdb',
        duckdb = 'duckdb',
        sqlite = 'sqlite',
        sqlite3 = 'sqlite',
}

local defaults = {
        connections_file = '~/.config/nvim/dbx.lua',
        notify = true,
}

---@class QompassDbConfigOpts
---@field connections_file? string
---@field notify? boolean

---@type QompassDbConfigOpts
M.config = vim.deepcopy(defaults)

M.state = {
        ---@type table<integer, string>
        buffer_backend = {},
        ---@type table<integer, boolean>
        buffer_readonly = {},
        ---@type table<string, string>|nil
        connections = nil,
        ---@type string|nil
        last_url = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
        if not M.config.notify then
                return
        end

        vim.notify(message, level or vim.log.levels.INFO, {
                title = 'db',
        })
end

---@param text string
---@return string
local function decode_percent(text)
        return (text:gsub('%%(%x%x)', function(hex)
                return string.char(tonumber(hex, 16))
        end))
end

---@param query string
---@return table<string, string>
local function parse_query_string(query)
        local params = {}

        if query == '' then
                return params
        end

        for pair in query:gmatch('[^&]+') do
                local key, value = pair:match('^([^=]+)=?(.*)$')

                if key ~= nil then
                        params[key] = decode_percent(value or '')
                end
        end

        return params
end

---@return table<string, string>
local function load_connections()
        if M.state.connections ~= nil then
                return M.state.connections
        end

        local path = vim.fn.expand(M.config.connections_file)

        if vim.fn.filereadable(path) ~= 1 then
                M.state.connections = {}
                return M.state.connections
        end

        local ok, result = pcall(dofile, path)

        if not ok or type(result) ~= 'table' then
                notify('failed to load ' .. path, vim.log.levels.WARN)
                M.state.connections = {}
                return M.state.connections
        end

        M.state.connections = result
        return M.state.connections
end

---@param path string
---@return string|nil
local function infer_backend_from_path(path)
        local extension = path:match('%.([%w]+)$')

        if extension == nil then
                return nil
        end

        return FILE_EXTENSION_BACKENDS[extension:lower()]
end

---@class DbParsedUrl
---@field backend string
---@field path? string
---@field conn? table

---@param url string
---@return DbParsedUrl|nil
---@return string|nil
local function parse_url(url)
        if not url:match('^[%w+.-]+:') then
                local backend = infer_backend_from_path(url)

                if backend == nil then
                        return nil, 'cannot infer a database backend from: ' .. url .. ' (use a scheme:// URL)'
                end

                return { backend = backend, path = vim.fn.expand(url) }
        end

        local scheme, rest = url:match('^([%w+.-]+):(.*)$')
        local backend = SCHEME_ALIASES[scheme:lower()]

        if backend == nil then
                return nil, 'unknown or unsupported scheme: ' .. scheme
        end

        if FILE_BACKENDS[backend] then
                local path = rest

                if path:sub(1, 2) == '//' then
                        path = path:sub(3)
                end

                return { backend = backend, path = vim.fn.expand(decode_percent(path)) }
        end

        local authority_and_path = rest

        if authority_and_path:sub(1, 2) == '//' then
                authority_and_path = authority_and_path:sub(3)
        end

        local authority, path_and_query = authority_and_path:match('^([^/]*)(.*)$')
        local path_part, query_part = path_and_query:match('^/?([^?]*)%??(.*)$')

        local userinfo, hostport = authority:match('^(.+)@(.+)$')

        if userinfo == nil then
                hostport = authority
        elseif userinfo:find(':') ~= nil then
                return nil, 'embedded passwords are not supported; use ?service=, ?passfile=, or ?defaults_file='
        end

        local host, port_text = (hostport or ''):match('^([^:]*):?(.*)$')
        local port = port_text ~= '' and tonumber(port_text) or nil

        local params = parse_query_string(query_part or '')
        local database = path_part ~= '' and decode_percent(path_part) or nil

        ---@type table
        local conn = {
                database = database,
                host = host ~= '' and host or nil,
                port = port,
                user = userinfo,
        }

        for _, key in ipairs({ 'service', 'passfile', 'defaults_file', 'socket' }) do
                if params[key] ~= nil then
                        conn[key] = params[key]
                end
        end

        return { backend = backend, conn = conn }
end

---@param token string|nil
---@return string|nil
---@return string|nil
local function resolve_url(token)
        if token ~= nil and token ~= '' then
                local named = load_connections()[token]
                return named or token, nil
        end

        local buffer_url = vim.b.db

        if type(buffer_url) == 'string' and buffer_url ~= '' then
                return buffer_url, nil
        end

        local global_url = vim.g.db

        if type(global_url) == 'string' and global_url ~= '' then
                return global_url, nil
        end

        local env_url = vim.env.DATABASE_URL

        if env_url ~= nil and env_url ~= '' then
                return env_url, nil
        end

        if M.state.last_url ~= nil then
                return M.state.last_url, nil
        end

        return nil, 'no database URL given, and none found in b:db, g:db, or $DATABASE_URL'
end

---@param args string
---@return string|nil url_token
---@return string remainder
local function split_leading_url(args)
        local first, rest = args:match('^(%S+)%s*(.*)$')

        if first == nil then
                return nil, args
        end

        local looks_like_url = first:match('^[%w+.-]+:') ~= nil
                or first:match('^[./~]') ~= nil
                or load_connections()[first] ~= nil

        if looks_like_url then
                return first, rest
        end

        return nil, args
end

---@param bufnr integer
---@param backend_key string
---@param attach_args string|table
---@param readonly boolean
---@return boolean
---@return string|nil
local function ensure_attached(bufnr, backend_key, attach_args, readonly)
        local previous = M.state.buffer_backend[bufnr]

        if previous ~= nil and previous ~= backend_key then
                BACKENDS[previous].detach(bufnr)
        end

        local module = BACKENDS[backend_key]
        local session, err = module.attach(bufnr, attach_args, readonly)

        if session == nil then
                return false, err
        end

        M.state.buffer_backend[bufnr] = backend_key
        M.state.buffer_readonly[bufnr] = readonly == true

        return true, nil
end

---@param rows table[]
---@return string[]
local function collect_columns(rows)
        local seen = {}
        local columns = {}

        for _, row in ipairs(rows) do
                for key in pairs(row) do
                        if not seen[key] then
                                seen[key] = true
                                columns[#columns + 1] = key
                        end
                end
        end

        table.sort(columns)
        return columns
end

---@param text string
---@param width integer
---@return string
local function pad(text, width)
        return text .. string.rep(' ', width - #text)
end

---@param rows table[]
---@return string[]
local function render_rows(rows)
        if #rows == 0 then
                return { '-- no rows --' }
        end

        local columns = collect_columns(rows)
        local widths = {}

        for _, column in ipairs(columns) do
                widths[column] = #column
        end

        for _, row in ipairs(rows) do
                for _, column in ipairs(columns) do
                        local value = row[column]
                        local text = value ~= nil and tostring(value) or 'NULL'

                        if #text > widths[column] then
                                widths[column] = #text
                        end
                end
        end

        local lines = {}
        local header_cells = {}

        for _, column in ipairs(columns) do
                header_cells[#header_cells + 1] = pad(column, widths[column])
        end

        lines[#lines + 1] = table.concat(header_cells, ' | ')

        local separator_cells = {}

        for _, column in ipairs(columns) do
                separator_cells[#separator_cells + 1] = string.rep('-', widths[column])
        end

        lines[#lines + 1] = table.concat(separator_cells, '-+-')

        for _, row in ipairs(rows) do
                local cells = {}

                for _, column in ipairs(columns) do
                        local value = row[column]
                        cells[#cells + 1] = pad(value ~= nil and tostring(value) or 'NULL', widths[column])
                end

                lines[#lines + 1] = table.concat(cells, ' | ')
        end

        return lines
end

---@param lines string[]
---@param title string
local function show_result_buffer(lines, title)
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
        vim.bo[bufnr].filetype = 'dbresult'

        vim.cmd('botright split')
        api.nvim_win_set_buf(api.nvim_get_current_win(), bufnr)
        api.nvim_win_set_height(api.nvim_get_current_win(), math.min(20, #lines + 1))
end

---@param backend_key string
---@param bufnr integer
---@param sql string
---@param title string
local function run_query_and_show(backend_key, bufnr, sql, title)
        local module = BACKENDS[backend_key]
        local readonly = M.state.buffer_readonly[bufnr]

        if readonly == nil then
                readonly = true
        end

        module.query_buffer(bufnr, sql, function(rows, err)
                if rows == nil then
                        notify(err or 'query failed', vim.log.levels.ERROR)
                        return
                end

                show_result_buffer(render_rows(rows), title)
        end, { readonly = readonly })
end

---@param bufnr integer
---@param line1 integer
---@param line2 integer
---@return string
local function buffer_sql(bufnr, line1, line2)
        local lines = api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
        return table.concat(lines, '\n')
end

---@param bufnr? integer
function M.detach(bufnr)
        bufnr = bufnr or api.nvim_get_current_buf()

        local backend_key = M.state.buffer_backend[bufnr]

        if backend_key == nil then
                notify('No database is attached to this buffer', vim.log.levels.WARN)
                return
        end

        BACKENDS[backend_key].detach(bufnr)
        M.state.buffer_backend[bufnr] = nil
        M.state.buffer_readonly[bufnr] = nil
end

---@param bufnr? integer
function M.info(bufnr)
        bufnr = bufnr or api.nvim_get_current_buf()

        local backend_key = M.state.buffer_backend[bufnr]

        if backend_key == nil then
                notify('No database is attached to this buffer', vim.log.levels.WARN)
                return
        end

        notify(vim.inspect({
                backend = backend_key,
                bufnr = bufnr,
                readonly = M.state.buffer_readonly[bufnr],
        }))
        BACKENDS[backend_key].info(bufnr)
end

---Operator-pending entry point: map this to a key, then a motion runs
---that range through :DB. Not bound automatically; see the header comment.
---@return string
function M.operator()
        vim.o.operatorfunc = "v:lua.require'config.data'.operator_execute"
        return 'g@'
end

---@param motion_type string
function M.operator_execute(motion_type)
        local range

        if motion_type == 'line' then
                range = "'[,']"
        elseif motion_type == 'block' then
                range = "'[,']"
        else
                range = "'[,']"
        end

        vim.cmd(range .. 'DB')
end

local function create_commands()
        api.nvim_create_user_command('DB', function(opts)
                local url_token, remainder = split_leading_url(opts.args)
                local url, resolve_err = resolve_url(url_token)

                if url == nil then
                        notify(resolve_err, vim.log.levels.ERROR)
                        return
                end

                local parsed, parse_err = parse_url(url)

                if parsed == nil then
                        notify(parse_err, vim.log.levels.ERROR)
                        return
                end

                local bufnr = api.nvim_get_current_buf()
                local attach_args = parsed.path or parsed.conn
                local attached, attach_err = ensure_attached(bufnr, parsed.backend, attach_args, opts.bang)

                if not attached then
                        notify(attach_err or 'failed to attach database', vim.log.levels.ERROR)
                        return
                end

                M.state.last_url = url

                local sql = remainder ~= '' and remainder or nil

                if sql == nil and opts.range > 0 then
                        sql = buffer_sql(bufnr, opts.line1, opts.line2)
                end

                if sql == nil then
                        BACKENDS[parsed.backend].terminal()
                        return
                end

                run_query_and_show(parsed.backend, bufnr, sql, 'db://' .. url .. ' [result]')
        end, {
                bang = true,
                desc = 'Attach (bang = readonly) and run or connect to a database URL',
                nargs = '*',
                range = true,
        })

        api.nvim_create_user_command('DBUrl', function(opts)
                if opts.args == '' then
                        notify('Usage: :DBUrl scheme://...', vim.log.levels.ERROR)
                        return
                end

                vim.b.db = opts.args
                notify('b:db set to ' .. opts.args)
        end, {
                desc = 'Set b:db for the current buffer',
                nargs = 1,
        })

        api.nvim_create_user_command('DBDetach', function()
                M.detach(api.nvim_get_current_buf())
        end, {
                desc = 'Detach whichever backend owns this buffer',
        })

        api.nvim_create_user_command('DBInfo', function()
                M.info(api.nvim_get_current_buf())
        end, {
                desc = "Show which backend/url owns this buffer",
        })
end

local function create_autocmds()
        local group = api.nvim_create_augroup('QompassNativeDb', {
                clear = true,
        })

        api.nvim_create_autocmd('BufDelete', {
                callback = function(args)
                        M.state.buffer_backend[args.buf] = nil
                        M.state.buffer_readonly[args.buf] = nil
                end,
                group = group,
        })
end

---@param opts? DbConfigOpts
---@return table
function M.setup(opts)
        M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

        sqlite.setup()
        duckdb.setup()
        mysql.setup()
        psql.setup()

        create_commands()
        create_autocmds()

        return M
end

return M