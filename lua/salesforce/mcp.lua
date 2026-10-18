-- /qompassai/Diver/lua/salesforce/mcp.lua
-- Qompass AI Diver Salesforce Hosted MCP Client
--
-- Plain words: connects Neovim to Salesforce Hosted MCP Servers over
-- Streamable HTTP. Salesforce hosts the MCP server; this module is the
-- client. It lists the server's tools (SObject ops, Flows, Apex actions,
-- Data 360, Prompt Builder) and calls them with your Salesforce
-- credentials, so agents can read/write org data without leaving nvim.
--
-- Auth model: OAuth 2.0 + PKCE through a Salesforce External Client App
-- (NOT a Connected App — those are rejected by the MCP gateway). The
-- initial browser authorization is a one-time manual step; afterwards the
-- refresh token lives in `pass` (salesforce/mcp-refresh-token) and this
-- module refreshes the JWT access token automatically. Secrets never hit
-- logs, notifications, or disk outside `pass`.
--
-- What this module does NOT do: the initial OAuth browser dance (human
-- step, documented in ~/workspace/salesforce-mcp/SETUP.md), or any
-- Salesforce org provisioning. It also never stores the client secret —
-- public-client PKCE flow, per Salesforce's recommended setup.
--
-- MCP transport: Streamable HTTP (POST JSON-RPC to the server URL).
-- This is separate from ai.mcp.client, which speaks stdio JSON-RPC to
-- local server processes. A remote hosted server cannot be spawned, so
-- a different transport was required.
---@module 'salesforce.mcp'

local api = vim.api
local fn = vim.fn

local M = {}

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

M.API_HOST = 'https://api.salesforce.com'

M.MCP_PATH_PREFIX = '/platform/mcp/v1'

---MCP protocol version this client speaks.
M.PROTOCOL_VERSION = '2025-06-18'

---Known Salesforce hosted MCP servers. Full URL is built as
---https://api.salesforce.com/platform/mcp/v1/[sandbox/]platform/<name>
---@type table<string, string> server key -> human description
M.SERVERS = {
    ['api-catalog'] = 'API discovery',
    ['data-360'] = 'Data 360 SQL-based analytics',
    ['flows'] = 'Trigger Salesforce Flows',
    ['invocable-actions'] = 'Invoke Apex invocable actions',
    ['prompt-builder'] = 'Prompt Builder templates',
    ['sobject-all'] = 'Full sObject read + write access',
    ['sobject-deletes'] = 'Delete records',
    ['sobject-mutations'] = 'Create and update records',
    ['sobject-reads'] = 'Read-only sObject access',
}

local HTTP_TIMEOUT_MS = 30000
local PASS_ENTRY_CLIENT_ID = 'salesforce/mcp-client-id'
local PASS_ENTRY_REFRESH = 'salesforce/mcp-refresh-token'
local RESPONSE_BYTES_MAX = 8 * 1024 * 1024
local SERVER_KEY_BYTES_MAX = 64
local TOKEN_REFRESH_TIMEOUT_MS = 15000
local TOOL_NAME_BYTES_MAX = 256

-- ---------------------------------------------------------------------------
-- Validation helpers
-- ---------------------------------------------------------------------------

---@param server_key string
---@return boolean
local function is_known_server(server_key)
    return type(server_key) == 'string'
        and #server_key > 0
        and #server_key <= SERVER_KEY_BYTES_MAX
        and M.SERVERS[server_key] ~= nil
end

---@param name string
---@return boolean
local function is_valid_tool_name(name)
    return type(name) == 'string' and #name > 0 and #name <= TOOL_NAME_BYTES_MAX
end

-- ---------------------------------------------------------------------------
-- MCP over Streamable HTTP
-- ---------------------------------------------------------------------------

---Send one JSON-RPC request over Streamable HTTP.
---@param url string full MCP server URL
---@param access_token string Bearer token (never logged)
---@param method string MCP method
---@param params table? method params
---@param callback fun(result: table?, err: string?)
local function mcp_post(url, access_token, method, params, callback)
    assert(type(url) == 'string', 'url must be a string')
    assert(type(access_token) == 'string', 'access_token must be a string')
    assert(type(method) == 'string', 'method must be a string')
    assert(type(callback) == 'function', 'callback must be a function')
    local payload = fn.json_encode({
        jsonrpc = '2.0',
        id = 1,
        method = method,
        params = params or {},
    })
    vim.system({
        'curl',
        '-sS',
        '--max-time',
        tostring(HTTP_TIMEOUT_MS / 1000),
        '-X',
        'POST',
        url,
        '-H',
        'Content-Type: application/json',
        '-H',
        'Accept: application/json, text/event-stream',
        '-H',
        'Authorization: Bearer ' .. access_token,
        '-d',
        payload,
    }, { text = true, timeout = HTTP_TIMEOUT_MS }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                callback(nil, 'MCP request failed: curl error ' .. result.code)
                return
            end
            local stdout = result.stdout or ''
            if #stdout == 0 then
                callback(nil, 'MCP request failed: empty response')
                return
            end
            if #stdout > RESPONSE_BYTES_MAX then
                callback(nil, 'MCP request failed: response too large')
                return
            end
            -- Streamable HTTP may wrap JSON-RPC in SSE data: lines.
            -- Prefer the last data: payload; fall back to raw body.
            local json_text = stdout
            for line in stdout:gmatch('[^\r\n]+') do
                local data = line:match('^data:%s*(.+)$')
                if data and data ~= '[DONE]' then
                    json_text = data
                end
            end
            local ok, decoded = pcall(fn.json_decode, json_text)
            if not ok or type(decoded) ~= 'table' then
                callback(nil, 'MCP request failed: invalid JSON response')
                return
            end
            if decoded.error ~= nil then
                local msg = type(decoded.error) == 'table'
                        and type(decoded.error.message) == 'string'
                        and decoded.error.message
                    or 'unknown MCP error'
                callback(nil, 'MCP error: ' .. msg)
                return
            end
            callback(decoded.result, nil)
        end)
    end)
end

---Run the MCP initialize handshake, then invoke callback with session ok.
---@param url string
---@param access_token string
---@param callback fun(ok: boolean, err: string?)
local function mcp_initialize(url, access_token, callback)
    mcp_post(url, access_token, 'initialize', {
        protocolVersion = M.PROTOCOL_VERSION,
        capabilities = {},
        clientInfo = { name = 'diver-salesforce-mcp', version = '0.1.0' },
    }, function(result, err)
        if err then
            callback(false, err)
            return
        end
        if type(result) ~= 'table' then
            callback(false, 'initialize returned no result')
            return
        end
        -- Fire-and-forget initialized notification; ignore its outcome.
        mcp_post(url, access_token, 'notifications/initialized', {}, function() end)
        callback(true, nil)
    end)
end

-- ---------------------------------------------------------------------------
-- Secure secret access (via pass(1))
-- ---------------------------------------------------------------------------

---Read a secret from pass. Returns nil + err on failure; never logs the value.
---@param entry string pass entry path (validated)
---@return string? secret
---@return string? err
local function pass_read(entry)
    assert(type(entry) == 'string', 'entry must be a string')
    assert(#entry > 0 and #entry <= 256, 'entry length out of bounds')
    assert(not entry:match('%.%.'), 'entry must not contain ..')
    local result = vim.system({ 'pass', 'show', entry }, { text = true, timeout = 10000 }):wait()
    if result.code ~= 0 then
        return nil, 'pass entry not found: ' .. entry
    end
    local secret = (result.stdout or ''):gsub('%s+$', '')
    if #secret == 0 then
        return nil, 'pass entry empty: ' .. entry
    end
    if #secret > 65536 then
        return nil, 'pass entry too large'
    end
    return secret, nil
end

-- ---------------------------------------------------------------------------
-- OAuth token management
-- ---------------------------------------------------------------------------

---@class salesforce.TokenSet
---@field access_token string JWT access token
---@field instance_url string org instance URL (token issuer)
---@field expires_at integer epoch seconds when the token expires

---@type salesforce.TokenSet?
local cached_token = nil

---Exchange the stored refresh token for a fresh JWT access token.
---Calls back with (token_set | nil, err | nil).
---@param callback fun(token: salesforce.TokenSet?, err: string?)
local function refresh_access_token(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    local refresh_token, rerr = pass_read(PASS_ENTRY_REFRESH)
    if not refresh_token then
        callback(nil, rerr or 'no refresh token')
        return
    end
    local client_id, cerr = pass_read(PASS_ENTRY_CLIENT_ID)
    if not client_id then
        callback(nil, cerr or 'no client id')
        return
    end
    -- NOTE: refresh_token and client_id go into a POST body via curl argv.
    -- They are never interpolated into a shell string.
    -- The token endpoint host comes from the org's My Domain; default to
    -- login.salesforce.com and let the token response correct us.
    local token_url = 'https://login.salesforce.com/services/oauth2/token'
    vim.system({
        'curl',
        '-sS',
        '--max-time',
        tostring(TOKEN_REFRESH_TIMEOUT_MS / 1000),
        '-X',
        'POST',
        token_url,
        '--data-urlencode',
        'grant_type=refresh_token',
        '--data-urlencode',
        'client_id=' .. client_id,
        '--data-urlencode',
        'refresh_token=' .. refresh_token,
    }, { text = true, timeout = TOKEN_REFRESH_TIMEOUT_MS }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                callback(nil, 'token refresh failed: curl error')
                return
            end
            local ok, body = pcall(fn.json_decode, result.stdout or '')
            if not ok or type(body) ~= 'table' then
                callback(nil, 'token refresh failed: bad JSON response')
                return
            end
            if type(body.access_token) ~= 'string' or #body.access_token == 0 then
                local msg = type(body.error_description) == 'string' and body.error_description
                    or 'no access_token in response'
                callback(nil, 'token refresh failed: ' .. msg)
                return
            end
            local expires_in = tonumber(body.expires_in) or 3600
            cached_token = {
                access_token = body.access_token,
                instance_url = type(body.instance_url) == 'string' and body.instance_url or '',
                expires_at = os.time() + expires_in - 60, -- 60s safety margin
            }
            callback(cached_token, nil)
        end)
    end)
end

---Get a valid access token, refreshing if expired or absent.
---@param callback fun(token: salesforce.TokenSet?, err: string?)
local function ensure_token(callback)
    assert(type(callback) == 'function', 'callback must be a function')
    if cached_token ~= nil and os.time() < cached_token.expires_at then
        callback(cached_token, nil)
        return
    end
    refresh_access_token(callback)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Check auth configuration status without exposing secrets.
---@return table { client_id = boolean, refresh_token = boolean }
function M.auth_status()
    local _, cerr = pass_read(PASS_ENTRY_CLIENT_ID)
    local _, rerr = pass_read(PASS_ENTRY_REFRESH)
    return {
        client_id = cerr == nil,
        refresh_token = rerr == nil,
    }
end

---Call a tool on a Salesforce MCP server.
---@param server_key string
---@param tool_name string
---@param arguments table? tool arguments (JSON-encodable)
---@param opts table? { sandbox = boolean, confirm = boolean }
---@param callback fun(result: table?, err: string?)
function M.call_tool(server_key, tool_name, arguments, opts, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    if not is_valid_tool_name(tool_name) then
        callback(nil, 'invalid tool name')
        return
    end
    opts = opts or {}
    local url, uerr = M.server_url(server_key, opts.sandbox == true)
    if not url then
        callback(nil, uerr)
        return
    end
    local function do_call()
        ensure_token(function(token, terr)
            if terr then
                callback(nil, 'auth: ' .. terr .. ' (see :SfMcpSetup)')
                return
            end
            assert(token ~= nil, 'token must be present after ensure_token')
            mcp_initialize(url, token.access_token, function(ok, ierr)
                if not ok then
                    callback(nil, ierr)
                    return
                end
                mcp_post(url, token.access_token, 'tools/call', {
                    name = tool_name,
                    arguments = arguments or {},
                }, callback)
            end)
        end)
    end
    if opts.confirm == true then
        local choice = fn.confirm('Call Salesforce MCP tool "' .. tool_name .. '"?', '&Yes\n&No', 2)
        if choice ~= 1 then
            callback(nil, 'cancelled by user')
            return
        end
    end
    do_call()
end

---Forget the cached access token (forces refresh on next call).
function M.forget_token()
    cached_token = nil
end

---List tools exposed by a Salesforce MCP server.
---@param server_key string e.g. 'sobject-reads'
---@param opts table? { sandbox = boolean }
---@param callback fun(tools: table?, err: string?)
function M.list_tools(server_key, opts, callback)
    assert(type(callback) == 'function', 'callback must be a function')
    opts = opts or {}
    local url, uerr = M.server_url(server_key, opts.sandbox == true)
    if not url then
        callback(nil, uerr)
        return
    end
    ensure_token(function(token, terr)
        if terr then
            callback(nil, 'auth: ' .. terr .. ' (see :SfMcpSetup)')
            return
        end
        assert(token ~= nil, 'token must be present after ensure_token')
        mcp_initialize(url, token.access_token, function(ok, ierr)
            if not ok then
                callback(nil, ierr)
                return
            end
            mcp_post(url, token.access_token, 'tools/list', {}, function(result, lerr)
                if lerr then
                    callback(nil, lerr)
                    return
                end
                local tools = type(result) == 'table' and result.tools or nil
                if type(tools) ~= 'table' then
                    callback(nil, 'tools/list returned no tools array')
                    return
                end
                callback(tools, nil)
            end)
        end)
    end)
end

---Build the full server URL for a server key.
---@param server_key string e.g. 'sobject-reads'
---@param sandbox boolean use sandbox path segment
---@return string? url
---@return string? err
function M.server_url(server_key, sandbox)
    if not is_known_server(server_key) then
        return nil, 'unknown Salesforce MCP server: ' .. tostring(server_key)
    end
    local segment = sandbox and '/sandbox' or ''
    return M.API_HOST .. M.MCP_PATH_PREFIX .. segment .. '/platform/' .. server_key, nil
end

-- ---------------------------------------------------------------------------
-- User commands
-- ---------------------------------------------------------------------------

local commands_registered = false

---Register :SfMcp* user commands. Idempotent.
function M.setup()
    if commands_registered then
        return
    end
    commands_registered = true

    api.nvim_create_user_command('SfMcpAuthStatus', function()
        local st = M.auth_status()
        local lines = {
            'Salesforce MCP auth status:',
            '  client_id:     ' .. (st.client_id and 'present in pass' or 'MISSING'),
            '  refresh_token: ' .. (st.refresh_token and 'present in pass' or 'MISSING'),
            '  cached token:  ' .. (cached_token ~= nil and 'cached' or 'none (will refresh on next call)'),
        }
        api.nvim_echo({ { table.concat(lines, '\n'), 'Normal' } }, false, {})
    end, { desc = 'Show Salesforce MCP auth configuration status' })

    api.nvim_create_user_command('SfMcpCall', function(cmd_opts)
        local args = vim.split(cmd_opts.args or '', '%s+', { trimempty = true })
        if #args < 2 then
            api.nvim_echo({
                {
                    'Usage: :SfMcpCall <server> <tool> [json-args] [sandbox]',
                    'ErrorMsg',
                },
            }, false, {})
            return
        end
        local server_key = args[1]
        local tool_name = args[2]
        local arguments = {}
        local sandbox = false
        for i = 3, #args do
            if args[i] == 'sandbox' then
                sandbox = true
            elseif args[i]:sub(1, 1) == '{' then
                local ok, decoded = pcall(fn.json_decode, args[i])
                if ok and type(decoded) == 'table' then
                    arguments = decoded
                else
                    api.nvim_echo({ { 'SfMcpCall: invalid JSON args', 'ErrorMsg' } }, false, {})
                    return
                end
            end
        end
        M.call_tool(server_key, tool_name, arguments, { sandbox = sandbox, confirm = true }, function(result, err)
            if err then
                api.nvim_echo({ { 'SfMcpCall: ' .. err, 'ErrorMsg' } }, false, {})
                return
            end
            local text = fn.json_encode(result or {})
            if #text > 8000 then
                text = text:sub(1, 8000) .. '\n... (truncated)'
            end
            api.nvim_echo({ { text, 'Normal' } }, false, {})
        end)
    end, {
        desc = 'Call a tool on a Salesforce MCP server (with confirmation)',
        nargs = '+',
    })

    api.nvim_create_user_command('SfMcpForgetToken', function()
        M.forget_token()
        api.nvim_echo({ { 'Salesforce MCP cached token cleared.', 'Normal' } }, false, {})
    end, { desc = 'Clear cached Salesforce MCP access token' })
end
api.nvim_create_user_command('SfMcpServers', function()
    local lines = { 'Salesforce Hosted MCP servers:' }
    local keys = {}
    for k in pairs(M.SERVERS) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        lines[#lines + 1] = string.format('  %-18s %s', k, M.SERVERS[k])
    end
    api.nvim_echo({ { table.concat(lines, '\n'), 'Normal' } }, false, {})
end, { desc = 'List Salesforce hosted MCP servers' })

api.nvim_create_user_command('SfMcpSetup', function()
    local lines = {
        'Salesforce MCP setup (one-time, ~10 min + up to 30 min propagation):',
        '',
        '  1. In Salesforce Setup: enable MCP Servers, activate the',
        '     server you want (e.g. sobject-reads).',
        '  2. Create an External Client App with OAuth scopes',
        '     mcp_api + refresh_token, PKCE required, JWT tokens on.',
        '  3. Complete the browser OAuth flow once, then store:',
        '       pass insert ' .. PASS_ENTRY_CLIENT_ID,
        '       pass insert ' .. PASS_ENTRY_REFRESH,
        '  4. Full guide: ~/workspace/salesforce-mcp/SETUP.md',
    }
    api.nvim_echo({ { table.concat(lines, '\n'), 'Normal' } }, false, {})
end, { desc = 'Show Salesforce MCP one-time setup steps' })

api.nvim_create_user_command('SfMcpTools', function(cmd_opts)
    local args = vim.split(cmd_opts.args or '', '%s+', { trimempty = true })
    local server_key = args[1] or 'sobject-reads'
    local sandbox = args[2] == 'sandbox'
    M.list_tools(server_key, { sandbox = sandbox }, function(tools, err)
        if err then
            api.nvim_echo({ { 'SfMcpTools: ' .. err, 'ErrorMsg' } }, false, {})
            return
        end
        assert(tools ~= nil, 'tools must be present on success')
        local lines = {
            string.format('Tools on %s%s (%d):', server_key, sandbox and ' (sandbox)' or '', #tools),
        }
        for _, t in ipairs(tools) do
            local name = type(t.name) == 'string' and t.name or '?'
            local desc = type(t.description) == 'string' and t.description or ''
            if #desc > 80 then
                desc = desc:sub(1, 77) .. '...'
            end
            lines[#lines + 1] = string.format('  %-40s %s', name, desc)
        end
        api.nvim_echo({ { table.concat(lines, '\n'), 'Normal' } }, false, {})
    end)
end, {
    desc = 'List tools on a Salesforce MCP server (:SfMcpTools [server] [sandbox])',
    nargs = '*',
})

return M
