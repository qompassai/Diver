-- /qompassai/Diver/lua/ai/dataaccess/commands.lua
-- Qompass AI Data Access User Commands (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing surface of the data-access layer:
--
--   :DataQuery {adapter} {target} [credfile]
--       Run one query through the managed, security-scanned layer.
--       {target} is a database path for sqlite/duckdb, or
--       user@host:port/database for mysql/mariadb/psql/redis.
--       Passwords are never accepted here (command-line history would
--       keep them): connection adapters authenticate through [credfile]
--       (mysql defaults_file, psql passfile) or redis's own env-based
--       password prompt flow. SQL is asked interactively; writes ask
--       for operator confirmation before running.
--   :DataSessions   Open the session/event dashboard.
--   :DataClose       Pick a session and release it.
--
-- Requiring this module registers nothing; M.setup() creates the
-- commands. Every command defers all work -- including sibling
-- requires -- to its callback, so setup itself performs no I/O.

local M = {}

local setup_done = false

---@param what string
---@param err any
local function notify_failed(what, err)
    vim.notify(what .. ' failed: ' .. tostring(err), vim.log.levels.ERROR, { title = 'dataaccess' })
end

---@param rows table
local function show_rows(rows)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'json'
    local lines = {}
    for _, row in ipairs(rows) do
        local ok, text = pcall(vim.json.encode, row)
        if ok and type(text) == 'string' then
            lines[#lines + 1] = text
        end
    end
    if #lines == 0 then
        lines = { '(no rows)' }
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, buf)
end

---@param adapter string
---@param target string
---@param credfile string?
local function run_query(adapter, target, credfile)
    local dataaccess = require('ai.dataaccess')
    vim.ui.input({ prompt = adapter .. ' query: ' }, function(text)
        if text == nil or text == '' then
            return
        end
        local dsn, dsn_err = dataaccess.parse_target(adapter, target, credfile)
        if dsn == nil then
            notify_failed('DataQuery', dsn_err)
            return
        end
        dataaccess.query(adapter, dsn, text, {}, function(ok, result)
            if not ok then
                notify_failed('DataQuery', result)
                return
            end
            if type(result) ~= 'table' then
                vim.notify('dataaccess: query ok', vim.log.levels.INFO, { title = 'dataaccess' })
                return
            end
            show_rows(result)
        end)
    end)
end

local function close_session()
    local dataaccess = require('ai.dataaccess')
    local sessions = dataaccess.sessions()
    if #sessions == 0 then
        vim.notify('dataaccess: no sessions open', vim.log.levels.WARN, { title = 'dataaccess' })
        return
    end
    local labels = {}
    for _, session in ipairs(sessions) do
        labels[#labels + 1] = session.label .. ' (refs: ' .. session.refcount .. ')'
    end
    vim.ui.select(labels, { prompt = 'Close session:' }, function(choice, idx)
        if choice == nil or idx == nil then
            return
        end
        local ok, err = dataaccess.close(sessions[idx].key)
        if not ok then
            notify_failed('DataClose', err)
            return
        end
        vim.notify('dataaccess: session closed', vim.log.levels.INFO, { title = 'dataaccess' })
    end)
end

---@param opts table Ex command options (fargs).
local function data_query_command(opts)
    local args = opts.fargs
    if #args < 2 then
        notify_failed('DataQuery', 'usage: :DataQuery {adapter} {target} [credfile]')
        return
    end
    -- Extra arguments are almost certainly a misplaced credfile: failing
    -- loudly beats silently falling back to default authentication.
    if #args > 3 then
        notify_failed('DataQuery', 'usage: :DataQuery {adapter} {target} [credfile]')
        return
    end
    run_query(args[1], args[2], args[3])
end

---Register the :Data* user commands. Idempotent.
function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    vim.api.nvim_create_user_command('DataQuery', data_query_command, {
        nargs = '+',
        desc = 'Run one security-scanned query through the managed data-access layer',
    })
    vim.api.nvim_create_user_command('DataSessions', function()
        require('ai.dataaccess.ui').open()
    end, {
        nargs = 0,
        desc = 'Open the data-access session dashboard',
    })
    vim.api.nvim_create_user_command('DataClose', close_session, {
        nargs = 0,
        desc = 'Pick a data-access session and release it',
    })
end

return M
