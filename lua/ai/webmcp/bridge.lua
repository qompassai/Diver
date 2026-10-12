-- /qompassai/Diver/lua/ai/webmcp/bridge.lua
-- Firenvim-style bridge without the plugin: a WebSocket server
-- inside Neovim exposing named RPC endpoints.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: Firenvim works by attaching to Neovim over its
-- built-in msgpack-RPC socket. This module does the same job
-- without any browser extension or plugin: it opens a WebSocket
-- server on localhost (using Diver's own native lua/ai/websocket),
-- and speaks a tiny JSON protocol:
--
--   -> { "id": 1, "method": "bridge.ping", "params": {} }
--   <- { "id": 1, "ok": true, "result": { "pong": true } }
--
-- Frames carrying "jsonrpc": "2.0" are routed to a per-client MCP
-- session (ai.webmcp.mcp_adapter) over the same socket: standard
-- MCP initialize / tools/list / tools/call against the same
-- endpoint table, with the same auth rules.
--
-- Only the named endpoints below exist. There is deliberately no
-- "run any Lua" endpoint: the browser side can only call what is
-- listed here, and every consequential call passes through
-- ai.recon.gate with an audit-log entry.
---@module 'ai.webmcp.bridge'

local M = {}

local DEFAULT_HOST = '127.0.0.1'
local DEFAULT_PORT = 17871
local PARAMS_MAX = 16384 ---@type integer Max encoded params bytes accepted

local active_host = nil ---@type string?
local active_port = nil ---@type integer?
local authed = {} ---@type table<string, boolean> client_id -> true after bridge.auth
local mcp_sessions = {} ---@type table<string, table> client_id -> MCP session (ai.webmcp.mcp_adapter)
local require_token = true ---@type boolean auth required for non-public endpoints
local server = nil ---@type table?

---Endpoints callable before authentication: health check and auth itself.
local PUBLIC_METHODS = {
    ['bridge.auth'] = true,
    ['bridge.ping'] = true,
}

---@param kind string 'read' | 'write' | 'execute'
---@return table
local function ann_for(kind)
    return require('security.annotations').for_endpoint(kind)
end

---Endpoint table: name -> { kind, desc, inputSchema, handler }.
---handler(params, respond) where respond(ok, payload).
---@type table<string, table>
local endpoints = {}

---The endpoint catalog in MCP/WebMCP descriptor shape, name-sorted.
---Single source for the bridge.tools endpoint and the MCP adapter.
---@return table[]
local function tool_defs()
    local out = {}
    for name, ep in pairs(endpoints) do
        out[#out + 1] = {
            annotations = ann_for(ep.kind),
            description = ep.desc,
            inputSchema = ep.inputSchema,
            name = name,
        }
    end
    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

---Verify a capability token for one client. On success the client
---is marked authed. Returns the token claims, or nil plus the
---error message the native bridge.auth endpoint reports.
---@param client_id string
---@param token any
---@return table? claims
---@return string? err
local function try_auth(client_id, token)
    if type(token) ~= 'string' or token == '' then
        return nil, 'params.token must be a non-empty string'
    end
    local ok, token_mod = pcall(require, 'ai.security.token')
    if not ok then
        return nil, 'token module unavailable'
    end
    local valid, claims = token_mod.verify(token, 'bridge')
    if not valid then
        return nil, 'auth failed: ' .. tostring(claims):sub(1, 120)
    end
    authed[client_id] = true
    return claims, nil
end

endpoints['bridge.auth'] = {
    desc = 'Authenticate this connection with a capability token from :ReconToken. '
        .. 'Required before any other endpoint when the bridge runs with require_token.',
    handler = function(params, respond, ctx)
        local claims, err = try_auth(ctx.client_id, params.token)
        if claims == nil then
            respond(false, err)
            return
        end
        respond(true, {
            authed = true,
            exp = claims.exp,
            scope = claims.scope,
        })
    end,
    inputSchema = {
        properties = {
            token = {
                description = 'v1.<payload>.<signature> token',
                type = 'string',
            },
        },
        required = {
            'token',
        },
        type = 'object',
    },
    kind = 'write',
}

endpoints['bridge.ping'] = {
    desc = 'Health check. Returns { pong = true }.',
    handler = function(_, respond)
        respond(true, {
            pong = true,
        })
    end,
    inputSchema = {
        properties = {},
        type = 'object',
    },
    kind = 'read',
}

endpoints['bridge.tools'] = {
    desc = 'List every endpoint with its WebMCP annotations.',
    handler = function(_, respond)
        respond(true, {
            tools = tool_defs(),
        })
    end,
    inputSchema = {
        properties = {},
        type = 'object',
    },
    kind = 'read',
}

endpoints['recon.skill'] = {
    desc = 'Run a recon skill against a target. Gated and audit-logged.',
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
        skills.execute(
            params.name,
            {
                args = params.args,
                target = params.target,
            },
            'bridge',
            function(ok2, result)
                respond(ok2, result)
            end
        )
    end,
    inputSchema = {
        properties = {
            args = {
                items = {
                    type = 'string',
                },
                type = 'array',
            },
            name = {
                description = 'Skill name without the recon. prefix',
                type = 'string',
            },
            target = {
                description = 'Target host, domain, or URL',
                type = 'string',
            },
        },
        required = {
            'name',
            'target',
        },
        type = 'object',
    },
    kind = 'execute',
}

endpoints['recon.skill.describe'] = {
    desc = 'Full procedure text of one recon skill.',
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
        respond(true, {
            skill = def,
        })
    end,
    inputSchema = {
        properties = {
            name = {
                description = 'Skill name without the recon. prefix',
                type = 'string',
            },
        },
        required = {
            'name',
        },
        type = 'object',
    },
    kind = 'read',
}

endpoints['recon.skills'] = {
    desc = 'List loaded recon skills with safety annotations.',
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
                annotations = def.annotations,
                description = def.description,
                inputSchema = def.inputSchema,
                name = def.name,
                title = def.title,
            }
        end
        respond(true, {
            skills = out,
        })
    end,
    inputSchema = {
        properties = {},
        type = 'object',
    },
    kind = 'read',
}

endpoints['recon.tool'] = {
    desc = 'Run one recon CLI tool directly. Gated and audit-logged.',
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
        local ann = require('security.annotations')
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
            local args = {
                params.target,
            }
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
    inputSchema = {
        properties = {
            args = {
                items = {
                    type = 'string',
                },
                type = 'array',
            },
            target = {
                description = 'Target host, domain, or URL',
                type = 'string',
            },
            tool = {
                description = 'Tool key from recon.tools',
                type = 'string',
            },
        },
        required = {
            'tool',
            'target',
        },
        type = 'object',
    },
    kind = 'execute',
}

endpoints['recon.tools'] = {
    desc = 'List recon CLI tools and whether each is installed.',
    handler = function(_, respond)
        local ok, tools = pcall(require, 'ai.recon.tools')
        if not ok then
            respond(false, 'recon tools unavailable')
            return
        end
        respond(true, {
            tools = tools.list(),
        })
    end,
    inputSchema = {
        properties = {},
        type = 'object',
    },
    kind = 'read',
}

endpoints['scip.languages'] = {
    desc = 'Languages with SCIP indexer support.',
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
        respond(true, {
            languages = langs,
        })
    end,
    inputSchema = {
        properties = {},
        type = 'object',
    },
    kind = 'read',
}

endpoints['scip.status'] = {
    desc = 'SCIP index status for a project root (top-level exists/fresh mirror the nested status).',
    handler = function(params, respond)
        local ok, query = pcall(require, 'dev.scip.query')
        if not ok then
            respond(false, 'dev.scip.query unavailable')
            return
        end
        local ok2, status, status_err = pcall(query.status, {
            root = params.root,
        })
        if not ok2 then
            respond(false, 'scip status failed')
            return
        end
        if status == nil then
            respond(false, 'scip status failed: ' .. tostring(status_err):sub(1, 200))
            return
        end
        respond(true, {
            exists = status.exists,
            fresh = status.fresh,
            status = status,
        })
    end,
    inputSchema = {
        properties = {
            root = {
                description = 'Project root (default: cwd)',
                type = 'string',
            },
        },
        type = 'object',
    },
    kind = 'read',
}

---@param id any
---@param ok boolean
---@param payload any
---@return string
local function encode_reply(id, ok, payload)
    local reply = {
        id = id,
        ok = ok,
    }
    if ok then
        reply.result = payload
    else
        reply.error = tostring(payload):sub(1, 512)
    end
    local encoded = vim.json.encode(reply)
    assert(type(encoded) == 'string')
    return encoded
end

---Run one endpoint behind the bridge's crash guard: a handler
---error becomes an error reply, never a dead socket.
---@param ep table
---@param params table
---@param ctx table
---@param respond fun(ok: boolean, payload: any)
local function run_endpoint(ep, params, ctx, respond)
    local ok, err = pcall(ep.handler, params, respond, ctx)
    if not ok then
        respond(false, 'handler error: ' .. tostring(err):sub(1, 300))
    end
end

---Dispatch one call for the MCP adapter: same endpoint table and
---crash guard as the native path. Authorization is the caller's
---job (the adapter mirrors the native rules). Returns false for
---unknown names so the adapter can answer with an MCP error.
---@param name string
---@param params table
---@param ctx table
---@param respond fun(ok: boolean, payload: any)
---@return boolean known
local function dispatch_endpoint(name, params, ctx, respond)
    local ep = endpoints[name]
    if ep == nil then
        return false
    end
    run_endpoint(ep, params, ctx, respond)
    return true
end

---Route one JSON-RPC frame to the client's MCP session, creating
---the session on first use. An initialize frame may carry the
---capability token at params._meta.token; a native bridge.auth
---frame on the same socket works too -- auth state is shared.
---@param client_id string
---@param raw string
---@param msg table the already-decoded frame
local function route_mcp(client_id, raw, msg)
    if msg.method == 'initialize' and type(msg.params) == 'table' and type(msg.params._meta) == 'table' then
        try_auth(client_id, msg.params._meta.token)
    end
    local session = mcp_sessions[client_id]
    if session == nil then
        session = require('ai.webmcp.mcp_adapter').new_session({
            dispatch = function(name, params, respond)
                return dispatch_endpoint(name, params, { client_id = client_id }, respond)
            end,
            is_authed = function()
                return authed[client_id] == true
            end,
            public_methods = PUBLIC_METHODS,
            require_token = function()
                return require_token
            end,
            tool_defs = tool_defs,
            write = function(line)
                if server ~= nil then
                    server:try_send_data_to_client(client_id, line)
                end
            end,
        })
        mcp_sessions[client_id] = session
    end
    session.handle_line(raw)
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
    if msg.jsonrpc == '2.0' then
        route_mcp(client_id, raw, msg)
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
    local ctx = {
        client_id = client_id,
    }
    run_endpoint(ep, params, ctx, function(ok3, payload)
        reply(ok3, payload, id)
    end)
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
    port = math.floor(port)
    require_token = opts.require_token ~= false
    authed = {}
    local ws = require('ai.websocket.server')
    local srv = ws.WebsocketServer.new({
        host = host,
        on_client_disconnect = function(_, client_id)
            authed[client_id] = nil
            mcp_sessions[client_id] = nil
        end,
        on_message = on_message,
        port = port,
    })
    srv:try_start()
    if not srv:is_active() then
        return {
            running = false,
            error = 'bind/listen failed on ' .. host .. ':' .. port,
        }
    end
    server = srv
    active_host = host
    active_port = port
    return M.status()
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
        authed_clients = authed_clients,
        clients = clients,
        host = active_host,
        port = active_port,
        require_token = require_token,
        running = server ~= nil,
    }
end

---Stop the bridge server. Idempotent.
function M.stop()
    if server ~= nil then
        server:try_stop()
        server = nil
        active_host = nil
        active_port = nil
        authed = {}
        mcp_sessions = {}
    end
end

return M
