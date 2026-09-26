-- /qompassai/Diver/lua/ai/webmcp/bridge.lua
-- Firenvim-style bridge without the plugin: a WebSocket server
-- inside Neovim exposing named RPC endpoints.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: Firenvim works by attaching to Neovim over its
-- built-in msgpack-RPC socket. This module does the same job
-- without any browser extension or plugin: it opens a WebSocket
-- server on localhost (using Diver's own native lua/websocket),
-- and speaks a tiny JSON protocol:
--
--   -> { "id": 1, "method": "bridge.ping", "params": {} }
--   <- { "id": 1, "ok": true, "result": { "pong": true } }
--
-- Only the named endpoints below exist. There is deliberately no
-- "run any Lua" endpoint: the browser side can only call what is
-- listed here, and every consequential call passes through
-- ai.recon.gate with an audit-log entry.
---@module 'ai.webmcp.bridge'

local M = {}

local DEFAULT_PORT = 17871
local DEFAULT_HOST = '127.0.0.1'
local PARAMS_MAX = 16384 ---@type integer Max encoded params bytes accepted

local server = nil ---@type table?
local active_port = nil ---@type integer?
local active_host = nil ---@type string?
local require_token = true ---@type boolean auth required for non-public endpoints
local authed = {} ---@type table<string, boolean> client_id -> true after bridge.auth

---Endpoints callable before authentication: health check and auth itself.
local PUBLIC_METHODS = { ['bridge.ping'] = true, ['bridge.auth'] = true }

---@param kind string 'read' | 'write' | 'execute'
---@return table
local function ann_for(kind)
    return require('ai.security.annotations').for_endpoint(kind)
end

---Endpoint table: name -> { kind, desc, inputSchema, handler }.
---handler(params, respond) where respond(ok, payload).
---@type table<string, table>
local endpoints = {}

endpoints['bridge.ping'] = {
    kind = 'read',
    desc = 'Health check. Returns { pong = true }.',
    inputSchema = { type = 'object', properties = {} },
    handler = function(_, respond)
        respond(true, { pong = true })
    end,
}

endpoints['bridge.auth'] = {
    kind = 'write',
    desc = 'Authenticate this connection with a capability token from :ReconToken. '
        .. 'Required before any other endpoint when the bridge runs with require_token.',
    inputSchema = {
        type = 'object',
        properties = {
            token = { type = 'string', description = 'v1.<payload>.<signature> token' },
        },
        required = { 'token' },
    },
    handler = function(params, respond, ctx)
        if type(params.token) ~= 'string' or params.token == '' then
            respond(false, 'params.token must be a non-empty string')
            return
        end
        local ok, token_mod = pcall(require, 'ai.security.token')
        if not ok then
            respond(false, 'token module unavailable')
            return
        end
        local valid, claims = token_mod.verify(params.token, 'bridge')
        if not valid then
            respond(false, 'auth failed: ' .. tostring(claims):sub(1, 120))
            return
        end
        authed[ctx.client_id] = true
        respond(true, { authed = true, scope = claims.scope, exp = claims.exp })
    end,
}

endpoints['bridge.tools'] = {
    kind = 'read',
    desc = 'List every endpoint with its WebMCP annotations.',
    inputSchema = { type = 'object', properties = {} },
    handler = function(_, respond)
        local out = {}
        for name, ep in pairs(endpoints) do
            out[#out + 1] = {
                name = name,
                description = ep.desc,
                inputSchema = ep.inputSchema,
                annotations = ann_for(ep.kind),
            }
        end
        table.sort(out, function(a, b)
            return a.name < b.name
        end)
        respond(true, { tools = out })
    end,
}

endpoints['scip.status'] = {
    kind = 'read',
    desc = 'SCIP index status for a project root.',
    inputSchema = {
        type = 'object',
        properties = {
            root = { type = 'string', description = 'Project root (default: cwd)' },
        },
    },
    handler = function(params, respond)
        local ok, query = pcall(require, 'scip.query')
        if not ok then
            respond(false, 'scip.query unavailable')
            return
        end
        local ok2, status = pcall(query.status, { root = params.root })
        if not ok2 then
            respond(false, 'scip status failed')
            return
        end
        respond(true, { status = status })
    end,
}

endpoints['scip.languages'] = {
    kind = 'read',
    desc = 'Languages with SCIP indexer support.',
    inputSchema = { type = 'object', properties = {} },
    handler = function(_, respond)
        local ok, lang = pcall(require, 'scip.lang')
        if not ok then
            respond(false, 'scip.lang unavailable')
            return
        end
        local ok2, langs = pcall(lang.languages)
        if not ok2 then
            respond(false, 'scip languages failed')
            return
        end
        respond(true, { languages = langs })
    end,
}

endpoints['recon.skills'] = {
    kind = 'read',
    desc = 'List loaded recon skills with safety annotations.',
    inputSchema = { type = 'object', properties = {} },
    handler = function(_, respond)
        local ok, skills = pcall(require, 'ai.mcp.skills')
        if not ok then
            respond(false, 'skills loader unavailable')
            return
        end
        local ok2, defs = pcall(skills.tool_defs)
        if not ok2 then
            respond(false, 'skill listing failed')
            return
        end
        -- Strip procedure bodies from the listing; fetch one skill at
        -- a time through recon.skill.describe if needed.
        local out = {}
        for _, def in ipairs(defs) do
            out[#out + 1] = {
                name = def.name,
                title = def.title,
                description = def.description,
                inputSchema = def.inputSchema,
                annotations = def.annotations,
            }
        end
        respond(true, { skills = out })
    end,
}

endpoints['recon.skill.describe'] = {
    kind = 'read',
    desc = 'Full procedure text of one recon skill.',
    inputSchema = {
        type = 'object',
        properties = {
            name = { type = 'string', description = 'Skill name without the recon. prefix' },
        },
        required = { 'name' },
    },
    handler = function(params, respond)
        if type(params.name) ~= 'string' or params.name == '' then
            respond(false, 'params.name must be a non-empty string')
            return
        end
        local ok, skills = pcall(require, 'ai.mcp.skills')
        if not ok then
            respond(false, 'skills loader unavailable')
            return
        end
        local skill = skills.get(params.name)
        if skill == nil then
            respond(false, 'unknown skill: ' .. params.name)
            return
        end
        local def = skills.tool_def(skill)
        def.procedure = skill.body
        respond(true, { skill = def })
    end,
}

endpoints['recon.skill'] = {
    kind = 'execute',
    desc = 'Run a recon skill against a target. Gated and audit-logged.',
    inputSchema = {
        type = 'object',
        properties = {
            name = { type = 'string', description = 'Skill name without the recon. prefix' },
            target = { type = 'string', description = 'Target host, domain, or URL' },
            args = { type = 'array', items = { type = 'string' } },
        },
        required = { 'name', 'target' },
    },
    handler = function(params, respond)
        if type(params.name) ~= 'string' or params.name == '' then
            respond(false, 'params.name must be a non-empty string')
            return
        end
        if type(params.target) ~= 'string' or params.target == '' then
            respond(false, 'params.target must be a non-empty string')
            return
        end
        local ok, skills = pcall(require, 'ai.mcp.skills')
        if not ok then
            respond(false, 'skills loader unavailable')
            return
        end
        skills.execute(params.name, { target = params.target, args = params.args }, 'bridge', function(ok2, result)
            respond(ok2, result)
        end)
    end,
}

endpoints['recon.tools'] = {
    kind = 'read',
    desc = 'List recon CLI tools and whether each is installed.',
    inputSchema = { type = 'object', properties = {} },
    handler = function(_, respond)
        local ok, tools = pcall(require, 'ai.recon.tools')
        if not ok then
            respond(false, 'recon tools unavailable')
            return
        end
        respond(true, { tools = tools.list() })
    end,
}

endpoints['recon.tool'] = {
    kind = 'execute',
    desc = 'Run one recon CLI tool directly. Gated and audit-logged.',
    inputSchema = {
        type = 'object',
        properties = {
            tool = { type = 'string', description = 'Tool key from recon.tools' },
            target = { type = 'string', description = 'Target host, domain, or URL' },
            args = { type = 'array', items = { type = 'string' } },
        },
        required = { 'tool', 'target' },
    },
    handler = function(params, respond)
        if type(params.tool) ~= 'string' or params.tool == '' then
            respond(false, 'params.tool must be a non-empty string')
            return
        end
        if type(params.target) ~= 'string' or params.target == '' then
            respond(false, 'params.target must be a non-empty string')
            return
        end
        local ok, tools = pcall(require, 'ai.recon.tools')
        if not ok then
            respond(false, 'recon tools unavailable')
            return
        end
        local def = tools.DEFS[params.tool]
        if def == nil then
            respond(false, 'unknown tool: ' .. params.tool)
            return
        end
        local ann = require('ai.security.annotations')
        local annotations = ann.blank()
        if def.active then
            annotations.consequentialHint = true
        else
            annotations.readOnlyHint = true
        end
        annotations.untrustedContentHint = true
        local gate = require('ai.recon.gate')
        gate.check('tool.' .. params.tool, params.target, annotations, 'bridge', function(allowed, reason)
            if not allowed then
                respond(false, 'denied: ' .. reason)
                return
            end
            local args = { params.target }
            if type(params.args) == 'table' then
                for _, a in ipairs(params.args) do
                    args[#args + 1] = a
                end
            end
            tools.run(params.tool, args, function(ok2, result)
                result.gate = reason
                respond(ok2, result)
            end)
        end)
    end,
}

---@param id any
---@param ok boolean
---@param payload any
---@return string
local function encode_reply(id, ok, payload)
    local reply = { id = id, ok = ok }
    if ok then
        reply.result = payload
    else
        reply.error = tostring(payload):sub(1, 512)
    end
    local encoded = vim.json.encode(reply)
    assert(type(encoded) == 'string')
    return encoded
end

---@param client_id string
---@param raw string
local function on_message_main(client_id, raw)
    local function reply(ok, payload, id)
        if server ~= nil then
            server:try_send_data_to_client(client_id, encode_reply(id, ok, payload))
        end
    end
    if #raw > PARAMS_MAX * 4 then
        reply(false, 'message too large', nil)
        return
    end
    local ok, msg = pcall(vim.json.decode, raw)
    if not ok or type(msg) ~= 'table' then
        reply(false, 'invalid JSON', nil)
        return
    end
    local id = msg.id
    if id == nil then
        reply(false, 'missing id', nil)
        return
    end
    if type(msg.method) ~= 'string' then
        reply(false, 'missing method', id)
        return
    end
    local ep = endpoints[msg.method]
    if ep == nil then
        reply(false, 'unknown method: ' .. msg.method:sub(1, 64), id)
        return
    end
    if require_token and not PUBLIC_METHODS[msg.method] and not authed[client_id] then
        reply(false, 'unauthorized: call bridge.auth with a valid token first', id)
        return
    end
    local params = msg.params
    if params == nil then
        params = {}
    end
    if type(params) ~= 'table' then
        reply(false, 'params must be an object', id)
        return
    end
    local ctx = { client_id = client_id }
    local ok2, err = pcall(ep.handler, params, function(ok3, payload)
        reply(ok3, payload, id)
    end, ctx)
    if not ok2 then
        reply(false, 'handler error: ' .. tostring(err):sub(1, 300), id)
    end
end

---Socket callbacks run in a fast event context where vim.fn is forbidden,
---but handlers do file IO and spawn subprocesses. Hop to the main loop;
---vim.schedule is FIFO so each connection's message order is preserved.
---@param _ table
---@param client_id string
---@param raw string
local function on_message(_, client_id, raw)
    vim.schedule(function()
        on_message_main(client_id, raw)
    end)
end

---Start the bridge WebSocket server. Safe to call twice: the second
---call returns the existing server's status.
---@param opts? table { host: string?, port: integer?, require_token: boolean? }
---@return table status { running: boolean, host: string?, port: integer? }
function M.start(opts)
    opts = opts or {}
    if server ~= nil then
        return M.status()
    end
    local host = opts.host or DEFAULT_HOST
    local port = opts.port or DEFAULT_PORT
    assert(type(host) == 'string', 'host must be a string')
    assert(type(port) == 'number', 'port must be a number')
    require_token = opts.require_token ~= false
    authed = {}
    local ws = require('websocket.server')
    local srv = ws.WebsocketServer.new({
        host = host,
        port = port,
        on_message = on_message,
        on_client_disconnect = function(_, client_id)
            authed[client_id] = nil
        end,
    })
    srv:try_start()
    if not srv:is_active() then
        return { running = false, error = 'bind/listen failed on ' .. host .. ':' .. port }
    end
    server = srv
    active_host = host
    active_port = port
    return M.status()
end

---Stop the bridge server. Idempotent.
function M.stop()
    if server ~= nil then
        server:try_stop()
        server = nil
        active_host = nil
        active_port = nil
        authed = {}
    end
end

---@return table status
function M.status()
    local clients = 0
    if server ~= nil then
        for _ in pairs(server.clients) do
            clients = clients + 1
        end
    end
    local authed_clients = 0
    for _ in pairs(authed) do
        authed_clients = authed_clients + 1
    end
    return {
        running = server ~= nil,
        host = active_host,
        port = active_port,
        clients = clients,
        authed_clients = authed_clients,
        require_token = require_token,
    }
end

---Endpoint names, for commands and completion.
---@return string[]
function M.methods()
    local out = {}
    for name in pairs(endpoints) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end

return M
