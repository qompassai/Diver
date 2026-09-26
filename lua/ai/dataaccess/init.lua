-- /qompassai/Diver/lua/ai/dataaccess/init.lua
-- Qompass AI Managed Data Access (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- One managed, session-reused data-access layer over diver's
-- lua/config/data/ adapters (sqlite, duckdb, mysql, mariadb, psql,
-- redis), for AI agents (herd agents, debugbridge, MCP servers) that
-- need to query data sources safely. Note: config.data.csv is a
-- rainbow-delimiter syntax module, not a query adapter (it exposes no
-- query_sync or connection API), so CSV files are deliberately not a
-- supported adapter here rather than inventing a CSV query protocol.
--
-- Plain words: this is the librarian for databases. Instead of every
-- agent opening its own connection, they all come here: one shared
-- session per database, every question and every answer checked for
-- attacks, reads running free, and writes waiting for a human to say
-- yes. A local socket lets outside coordinators use the same desk.
--
-- Safety contract, enforced in this order for every query:
--   1. Validate: adapter name, target (path traversal / metacharacter
--      rejection on file paths; secret-bearing connection fields
--      rejected, credential files must be 0600/0400), text bounds.
--   2. Scan the request through ai.security. High severity -> refuse
--      and log; medium/low -> log and notify; missing security -> fail
--      closed, refuse everything.
--   3. Writes need explicit operator confirmation (single-use,
--      expiring token) via ai.security's confirmation flow.
--   4. Run through the adapter's own query_sync (bounded subprocess;
--      this layer never reimplements adapter protocol details).
--   5. Scan the result set row by row before it reaches the agent.
--   6. Secrets never appear in argv, logs, errors, or socket replies:
--      mysql/psql take credential files, redis takes its password via
--      the subprocess environment, and everything logged is redacted.
--
-- M.setup() starts no database clients and opens no connections. It
-- wires the socket backend, starts the local listener best-effort,
-- and registers the :Data* commands. Sessions are created lazily on
-- first query and forgotten when their last holder releases them.

local M = {}

local paths = require('ai.dataaccess.paths')
local secrets = require('ai.dataaccess.secrets')
local sessions = require('ai.dataaccess.sessions')
local scan = require('ai.dataaccess.scan')
local confirm = require('ai.dataaccess.confirm')
local dalog = require('ai.dataaccess.log')
local api = require('ai.dataaccess.api')

local TEXT_BYTES_MAX = 65536
local PREVIEW_BYTES_MAX = 512
local TARGET_FIELD_MAX = 1024
local PORT_MIN = 1
local PORT_MAX = 65535

---@class DataAdapterSpec
---@field module string config.data module name.
---@field kind 'file'|'connection'
---@field allow_password boolean Whether a password field may pass through (redis only).

local ADAPTERS = {
    sqlite = { module = 'config.data.sqlite', kind = 'file', allow_password = false },
    duckdb = { module = 'config.data.duckdb', kind = 'file', allow_password = false },
    mysql = { module = 'config.data.mysql', kind = 'connection', allow_password = false },
    mariadb = { module = 'config.data.mariadb', kind = 'connection', allow_password = false },
    psql = { module = 'config.data.psql', kind = 'connection', allow_password = false },
    redis = { module = 'config.data.redis', kind = 'connection', allow_password = true },
}

local setup_done = false

---@param value any
---@return boolean
local function clean_bounded_string(value)
    return type(value) == 'string' and value ~= '' and value:find('%z') == nil
end

---Log a security-relevant event. Best-effort: a logging failure never
---blocks the query itself. Details must already be redacted.
---@param kind string
---@param detail table
local function audit(kind, detail)
    dalog.append(kind, detail)
end

---@param findings table[]
---@return table summary Secret-free finding summaries.
local function summarize_findings(findings)
    local summary = {}
    for _, finding in ipairs(findings) do
        if type(finding) == 'table' then
            summary[#summary + 1] = {
                code = tostring(finding.code or 'unknown'),
                severity = tostring(finding.severity or 'unknown'),
            }
        end
    end
    return summary
end

---@param findings table[]
local function notify_findings(findings)
    local codes = {}
    for _, finding in ipairs(findings) do
        if type(finding) == 'table' then
            codes[#codes + 1] = tostring(finding.code or 'unknown')
        end
    end
    vim.notify(
        'dataaccess: scan findings: ' .. table.concat(codes, ', '),
        vim.log.levels.WARN,
        { title = 'dataaccess' }
    )
end

---@param adapter_name any
---@return DataAdapterSpec? spec
local function adapter_spec(adapter_name)
    if type(adapter_name) ~= 'string' then
        return nil
    end
    return ADAPTERS[adapter_name]
end

---@param spec DataAdapterSpec
---@return table? adapter
---@return string? err
local function load_adapter(spec)
    local ok, mod = pcall(require, spec.module)
    if not ok or type(mod) ~= 'table' then
        return nil, 'adapter module unavailable: ' .. spec.module
    end
    if type(mod.query_sync) ~= 'function' then
        return nil, 'adapter has no query_sync: ' .. spec.module
    end
    return mod, nil
end

---Validate a credential-file field and return it unchanged. The file
---must exist and be owner-only (0600/0400); anything looser is
---refused rather than used.
---@param field string Field name for the error message.
---@param path any
---@return boolean ok
---@return string? err
local function check_credential_field(field, path)
    if path == nil then
        return true, nil
    end
    local ok, err = paths.validate_credential_file(path)
    if not ok then
        return false, field .. ': ' .. err
    end
    return true, nil
end

---Normalize a caller-supplied dsn into the adapter's target form:
---a validated path string for file adapters, a cleaned connection
---table for connection adapters. Never returns secrets in errors.
---@param spec DataAdapterSpec
---@param dsn any
---@return string|table? target
---@return string? err
---@return string? identity Secret-free session identity.
local function normalize_dsn(spec, dsn, adapter_name)
    if spec.kind == 'file' then
        local ok, err = paths.validate_db_path(adapter_name, dsn)
        if not ok then
            return nil, err, nil
        end
        return dsn, nil, dsn
    end
    local clean, clean_err = secrets.clean_conn(dsn, spec.allow_password)
    if clean == nil then
        return nil, clean_err, nil
    end
    local ok, cred_err = check_credential_field('defaults_file', clean.defaults_file)
    if not ok then
        return nil, cred_err, nil
    end
    ok, cred_err = check_credential_field('passfile', clean.passfile)
    if not ok then
        return nil, cred_err, nil
    end
    local label = secrets.label(adapter_name, clean)
    return clean, nil, label .. secrets.key_suffix(clean)
end

---@param text_preview string
---@return string preview
local function preview_of(text_preview)
    if #text_preview > PREVIEW_BYTES_MAX then
        return text_preview:sub(1, PREVIEW_BYTES_MAX) .. '...'
    end
    return text_preview
end

---@param label string
---@param adapter_name string
---@param is_write boolean
---@param verdict string
---@param findings table
---@param err string?
local function audit_refusal(label, adapter_name, is_write, verdict, findings, err)
    audit('query.' .. verdict, {
        adapter = adapter_name,
        label = label,
        write = is_write,
        findings = summarize_findings(findings),
        error = secrets.redact(err or ''),
    })
end

---Shared query core for the Lua API and the socket backend.
---Returns (true, rows) on success, (false, err) on failure, or
---(false, { confirmation_required = true, ... }) when a write needs
---the operator's approval first.
---@param adapter_name string
---@param dsn any Path string or connection table.
---@param text string SQL or command text.
---@param confirm_token string?
---@return boolean ok
---@return any result
local function execute(adapter_name, dsn, text, confirm_token)
    local spec = adapter_spec(adapter_name)
    if spec == nil then
        return false, 'unknown adapter: ' .. tostring(adapter_name)
    end
    if not clean_bounded_string(text) then
        return false, 'text must be a non-empty string without NUL bytes'
    end
    if #text > TEXT_BYTES_MAX then
        return false, 'text exceeds size bound'
    end
    local target, dsn_err, identity = normalize_dsn(spec, dsn, adapter_name)
    if target == nil then
        return false, dsn_err
    end
    assert(identity ~= nil, 'normalize_dsn returned no identity without error')
    local label = spec.kind == 'file' and (adapter_name .. ':' .. target) or identity
    local is_write = confirm.is_write(adapter_name, text)

    local verdict, findings, scan_err = scan.check_request(text)
    if verdict == 'refuse' then
        audit_refusal(label, adapter_name, is_write, 'request_refused', findings, scan_err)
        return false, 'request refused by security scan'
    end
    if verdict == 'notify' then
        audit('query.request_findings', {
            adapter = adapter_name,
            label = label,
            write = is_write,
            findings = summarize_findings(findings),
        })
        notify_findings(findings)
    end

    if is_write then
        local token = confirm_token
        if type(token) ~= 'string' or token == '' then
            local new_token, token_err = confirm.issue(label, preview_of(text))
            if new_token == nil then
                return false, token_err
            end
            audit('query.confirm_requested', { adapter = adapter_name, label = label })
            return false,
                {
                    confirmation_required = true,
                    confirm_token = new_token,
                    label = label,
                    preview = preview_of(text),
                }
        end
        local state = confirm.consume(token)
        if state ~= 'approved' then
            audit('query.confirm_denied', {
                adapter = adapter_name,
                label = label,
                token_state = state,
            })
            return false, 'write not approved (token ' .. state .. ')'
        end
    end

    local adapter, load_err = load_adapter(spec)
    if adapter == nil then
        return false, load_err
    end
    local session, session_err =
        sessions.acquire('dataaccess:' .. adapter_name .. '|' .. identity, adapter_name, adapter, target, label)
    if session == nil then
        return false, session_err
    end
    local rows, query_err = adapter.query_sync(target, text, { readonly = not is_write })
    if rows == nil then
        local redacted = secrets.redact(query_err)
        session.last_error = redacted
        sessions.release(session.key)
        audit('query.failed', { adapter = adapter_name, label = label, error = redacted })
        return false, redacted
    end

    local result_verdict, result_findings, result_err = scan.check_result(rows)
    if result_verdict == 'refuse' then
        sessions.release(session.key)
        audit_refusal(label, adapter_name, is_write, 'result_refused', result_findings, result_err)
        return false, 'result refused by security scan'
    end
    if result_verdict == 'notify' then
        audit('query.result_findings', {
            adapter = adapter_name,
            label = label,
            findings = summarize_findings(result_findings),
        })
        notify_findings(result_findings)
    end

    session.query_count = session.query_count + 1
    if is_write then
        session.write_count = session.write_count + 1
    end
    session.last_error = nil
    sessions.release(session.key)
    audit(is_write and 'query.write_ok' or 'query.ok', {
        adapter = adapter_name,
        label = label,
        rows = #rows,
    })
    return true, rows
end

---Run a query through the managed layer. Reads run free; writes
---prompt the operator through ai.security's confirmation flow and run
---only on approval. The result callback always runs exactly once.
---@param adapter_name string sqlite|duckdb|mysql|mariadb|psql|redis.
---@param dsn string|table Path string (file adapters) or connection table.
---@param text string SQL or command text.
---@param opts? { confirm_token?: string } Pre-approved write token.
---@param on_result fun(ok: boolean, result: any)
function M.query(adapter_name, dsn, text, opts, on_result)
    assert(type(on_result) == 'function', 'on_result must be a function')
    assert(opts == nil or type(opts) == 'table', 'opts must be a table or nil')
    local token = opts and opts.confirm_token or nil
    local ok, result = execute(adapter_name, dsn, text, token)
    if ok then
        on_result(true, result)
        return
    end
    if type(result) == 'table' and result.confirmation_required then
        confirm.prompt(result.confirm_token, result.label, result.preview, function(allowed, reason)
            if not allowed then
                on_result(false, 'write denied: ' .. tostring(reason))
                return
            end
            local ok2, result2 = execute(adapter_name, dsn, text, result.confirm_token)
            on_result(ok2, result2)
        end)
        return
    end
    on_result(false, result)
end

---Parse a :DataQuery target string. File adapters take a path;
---connection adapters take user@host:port/database (port optional).
---credfile, when given, is validated as an owner-only credential file
---and attached as the adapter's credential field.
---@param adapter_name string
---@param target any
---@param credfile any
---@return string|table? dsn
---@return string? err
function M.parse_target(adapter_name, target, credfile)
    local spec = adapter_spec(adapter_name)
    if spec == nil then
        return nil, 'unknown adapter: ' .. tostring(adapter_name)
    end
    if not clean_bounded_string(target) or #target > TARGET_FIELD_MAX then
        return nil, 'target must be a bounded non-empty string'
    end
    if spec.kind == 'file' then
        return target, nil
    end
    local user, rest = target:match('^([^@%s]+)@(.+)$')
    if user == nil or rest == nil then
        return nil, 'connection target must look like user@host:port/database'
    end
    -- Passwords are never accepted in the target string: a ':DataQuery'
    -- line persists in command-line history (shada), so user:password@host
    -- would leak the secret. Authenticate via [credfile] instead.
    if user:find(':', 1, true) ~= nil then
        return nil, 'user must not contain a password: use [credfile]'
    end
    local host, port_text, database = rest:match('^([^:/%s]+):(%d+)/(.-)$')
    if host == nil then
        host, database = rest:match('^([^:/%s]+)/(.+)$')
        if host == nil then
            host = rest:match('^([^:/%s]+)$')
        end
    end
    if host == nil or host == '' then
        return nil, 'connection target needs a host'
    end
    local conn = { host = host, user = user }
    if database ~= nil and database ~= '' then
        conn.database = database
    end
    if port_text ~= nil then
        local port = tonumber(port_text)
        if port == nil or port < PORT_MIN or port > PORT_MAX then
            return nil, 'port out of range'
        end
        conn.port = port
    end
    if credfile ~= nil then
        if not clean_bounded_string(credfile) then
            return nil, 'credfile must be a non-empty string'
        end
        local field = adapter_name == 'psql' and 'passfile' or 'defaults_file'
        if adapter_name == 'redis' then
            return nil, 'redis authenticates via its own password flow, not a credential file'
        end
        conn[field] = credfile
    end
    return conn, nil
end

---List sessions as secret-free summaries, sorted by label.
---@return table[] list
function M.sessions()
    local list = {}
    for _, session in ipairs(sessions.list()) do
        list[#list + 1] = {
            key = session.key,
            adapter_name = session.adapter_name,
            label = session.label,
            refcount = session.refcount,
            query_count = session.query_count,
            write_count = session.write_count,
            created_at = session.created_at,
            last_error = session.last_error,
        }
    end
    return list
end

---Release one session acquisition; the session is forgotten at zero.
---@param key string Session key.
---@return boolean ok
---@return string? err
function M.close(key)
    if type(key) ~= 'string' or key == '' then
        return false, 'key must be a non-empty string'
    end
    local session = sessions.get(key)
    local remaining = sessions.release(key)
    if session ~= nil then
        audit('session.closed', { label = session.label, remaining_refs = remaining })
    end
    return true, nil
end

---Socket backend: run a query. Write queries without an approved
---token answer ok=true with { confirmation_required = true } so the
---coordinator can raise the operator prompt through 'confirm'.
---@param params table<string, any>
---@return boolean ok
---@return any result
local function backend_query(params)
    local ok, result = execute(params.adapter, params.dsn, params.text, params.confirm_token)
    if ok then
        return true, { rows = result }
    end
    if type(result) == 'table' and result.confirmation_required then
        return true,
            {
                confirmation_required = true,
                confirm_token = result.confirm_token,
            }
    end
    return false, result
end

---Socket backend: raise the operator confirmation prompt for a token.
---Replies immediately; the operator's choice lands on the token and
---the coordinator retries 'query' with it.
---@param params table<string, any>
---@return boolean ok
---@return any result
local function backend_confirm(params)
    local label, preview = confirm.describe(params.token)
    if label == nil then
        return false, 'unknown or expired confirmation token'
    end
    assert(preview ~= nil, 'describe returned a label without a preview')
    confirm.prompt(params.token, label, preview, function(allowed, reason)
        audit('query.confirm_answered', {
            label = label,
            allowed = allowed,
            reason = secrets.redact(reason),
        })
    end)
    return true, 'confirmation prompted'
end

---Socket backend: report one session or all sessions.
---@param params table<string, any>
---@return boolean ok
---@return any result
local function backend_status(params)
    if params.key ~= nil then
        local session = sessions.get(params.key)
        if session == nil then
            return false, 'unknown session'
        end
        return true,
            {
                label = session.label,
                adapter_name = session.adapter_name,
                refcount = session.refcount,
                query_count = session.query_count,
                write_count = session.write_count,
            }
    end
    return true, M.sessions()
end

---Socket backend: release a session.
---@param params table<string, any>
---@return boolean ok
---@return any result
local function backend_close(params)
    return M.close(params.key)
end

---Socket backend: list sessions.
---@param _params table<string, any>
---@return boolean ok
---@return any result
local function backend_list(_params)
    return true, M.sessions()
end

---Set up the data-access layer. Idempotent: repeat calls are a no-op.
---Starts no database clients and opens no connections; the socket
---listener starts best-effort and a failure is reported, not fatal.
---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'dataaccess.setup expects a table or nil')
    if setup_done then
        return
    end
    setup_done = true
    api.set_backend({
        query = backend_query,
        confirm = backend_confirm,
        status = backend_status,
        close = backend_close,
        list = backend_list,
    })
    local ok, err = api.start()
    if not ok then
        vim.notify('dataaccess: socket not started: ' .. tostring(err), vim.log.levels.WARN, {
            title = 'dataaccess',
        })
    end
    require('ai.dataaccess.commands').setup()
    vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
            api.stop()
        end,
    })
end

return M
