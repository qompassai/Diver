-- /qompassai/Diver/lua/ai/mcp/tools.lua
-- Qompass AI MCP Tool Inspection and Calls (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- List a server's tools, inspect a tool's input schema, and call a tool.
-- A tool call NEVER runs without explicit confirmation:
--
--   * If 'ai.security' is requireable and exports
--     confirm_tool_call(server, tool, args, callback) -- the real,
--     present contract in lua/ai/security/init.lua -- it is consulted
--     first (guarded pcall). It is async: the decision arrives as
--     callback(allowed, reason); default-deny, with a persistent
--     allowlist that skips the prompt for approved pairs.
--   * Otherwise (module absent or unusable) a vim.ui.select prompt names
--     the server, the tool, and the JSON-encoded arguments, and the call
--     proceeds only on the explicit "Run tool" choice.
--
-- Every tools/list response is vetted by ai.security.mcp_vet BEFORE the
-- metadata can reach AI context (MCPTox: tool descriptions are
-- attacker-controlled). Any finding disables the server in the registry,
-- stops its running session, and surfaces as a list error; the findings
-- remain available through M.vet_findings(server_name).
--
-- Sessions are started lazily through ai.mcp.client; tool calls reuse the
-- running session and never spawn a second process for the same server.

local client = require('ai.mcp.client')

local M = {}

local TOOLS_COUNT_MAX = 128
local TOOL_CALL_TIMEOUT_MS = 60000
local ARGS_JSON_BYTES_MAX = 64 * 1024

---@class McpTool
---@field name string
---@field description string
---@field input_schema table

---@param raw any
---@return McpTool? tool
local function tool_from_raw(raw)
    if type(raw) ~= 'table' or type(raw.name) ~= 'string' or raw.name == '' then
        return nil
    end
    return {
        name = raw.name,
        description = type(raw.description) == 'string' and raw.description or '',
        input_schema = type(raw.inputSchema) == 'table' and raw.inputSchema or {},
    }
end

---@param server_name string
---@param callback fun(err: string?, tools: McpTool[]?)
local function ensure_ready(server_name, callback)
    if client.is_ready(server_name) then
        callback(nil)
        return
    end
    client.start(server_name, function(err)
        callback(err)
    end)
end

---@type table<string, McpVetFinding[]> Most recent vet findings per server
local last_vet = {}

--- Vet a server's parsed tools/list before the metadata can reach AI
--- context. Every finding the vet emits is high severity: a poisoned tool
--- description is reason enough to distrust the server, so on any finding
--- the server is disabled in the registry and its running session (if any)
--- is stopped. Callers already treat a non-nil error as fatal.
---@param server_name string
---@param tools McpTool[]
---@return string? block_err Non-nil when vetting blocked the server
local function vet_tools(server_name, tools)
    assert(type(server_name) == 'string' and server_name ~= '')
    assert(type(tools) == 'table')
    -- Lazy require: ai.security is optional; a missing vet module must not
    -- break tool listing.
    local ok, vet_mod = pcall(require, 'ai.security.mcp_vet')
    if not ok or type(vet_mod) ~= 'table' or type(vet_mod.vet_tool_metadata) ~= 'function' then
        return nil
    end
    local meta = {} ---@type McpToolMeta[]
    for _, tool in ipairs(tools) do
        meta[#meta + 1] = { name = tool.name, description = tool.description }
    end
    local vet_ok, findings_or_err = pcall(vet_mod.vet_tool_metadata, meta)
    ---@type McpVetFinding[]
    local findings
    if vet_ok then
        findings = findings_or_err
    else
        -- Hostile or malformed metadata tripped the vet's own bounds.
        findings = {
            {
                severity = 'high',
                code = 'mcp.vet_rejected',
                detail = 'tool metadata rejected by vetting: ' .. tostring(findings_or_err),
            },
        }
    end
    last_vet[server_name] = findings
    if #findings == 0 then
        return nil
    end
    local codes = {}
    for _, finding in ipairs(findings) do
        codes[#codes + 1] = finding.code
    end
    local summary = ('mcp vet %q: %d finding(s): %s'):format(server_name, #findings, table.concat(codes, ', '))
    vim.notify(summary .. ' — server disabled', vim.log.levels.ERROR)
    -- Lazy require: registry must never be a load-time dependency here.
    local reg_ok, registry = pcall(require, 'ai.mcp.registry')
    if reg_ok and type(registry) == 'table' and type(registry.disable) == 'function' then
        pcall(registry.disable, server_name)
    end
    -- A disabled-but-running server would still answer tool calls through
    -- the already-open session, so stop it as well.
    pcall(client.stop, server_name)
    return summary .. ' — server disabled; re-enable with :McpEnable after review'
end

---@param server_name string
---@param callback fun(err: string?, tools: McpTool[]?)
function M.list(server_name, callback)
    assert(type(server_name) == 'string' and server_name ~= '', 'server_name must be non-empty')
    assert(type(callback) == 'function', 'callback must be a function')
    ensure_ready(server_name, function(start_err)
        if start_err ~= nil then
            callback(start_err, nil)
            return
        end
        client.request(server_name, 'tools/list', {}, function(err, result)
            if err ~= nil then
                callback(err, nil)
                return
            end
            if result == nil or type(result.tools) ~= 'table' then
                callback('server returned no tools array', nil)
                return
            end
            local tools = {}
            for index, raw in ipairs(result.tools) do
                if index > TOOLS_COUNT_MAX then
                    break
                end
                local tool = tool_from_raw(raw)
                if tool ~= nil then
                    tools[#tools + 1] = tool
                end
            end
            -- Vet before the metadata can reach AI context. A blocked
            -- server surfaces as an error, which every caller already
            -- handles.
            local block_err = vet_tools(server_name, tools)
            if block_err ~= nil then
                callback(block_err, nil)
                return
            end
            callback(nil, tools)
        end)
    end)
end

--- Findings from the most recent vetting of a server's tools/list.
--- Empty when the server was never listed or the vet module is absent.
---@param server_name string
---@return McpVetFinding[]
function M.vet_findings(server_name)
    assert(type(server_name) == 'string' and server_name ~= '', 'server_name must be non-empty')
    return last_vet[server_name] or {}
end

---@param server_name string
---@param tool_name string
---@param callback fun(err: string?, tool: McpTool?)
function M.describe(server_name, tool_name, callback)
    assert(type(tool_name) == 'string' and tool_name ~= '', 'tool_name must be non-empty')
    M.list(server_name, function(err, tools)
        if err ~= nil then
            callback(err, nil)
            return
        end
        assert(tools ~= nil, 'list returned no error and no tools')
        for _, tool in ipairs(tools) do
            if tool.name == tool_name then
                callback(nil, tool)
                return
            end
        end
        callback('unknown tool: ' .. tool_name, nil)
    end)
end

---Consult the security policy module, when present. The decision is async:
---on_decision(allowed: boolean, reason: string). Falls back to an explicit
---vim.ui.select prompt when the module is absent or unusable.
---@param server_name string
---@param tool_name string
---@param args table
---@param on_decision fun(allowed: boolean, reason: string)
local function confirm_with_policy(server_name, tool_name, args, on_decision)
    local ok, security = pcall(require, 'ai.security')
    if ok and type(security) == 'table' and type(security.confirm_tool_call) == 'function' then
        local confirm = security.confirm_tool_call
        local sok, call_err = pcall(confirm, server_name, tool_name, args, on_decision)
        if sok then
            return
        end
        on_decision(false, 'security module error: ' .. tostring(call_err))
        return
    end
    -- No policy module: explicit user confirmation naming everything.
    local args_text = vim.json.encode(args)
    if #args_text > ARGS_JSON_BYTES_MAX then
        args_text = args_text:sub(1, ARGS_JSON_BYTES_MAX) .. '... (truncated)'
    end
    local prompt = string.format('Run tool %s on %s?', tool_name, server_name)
    prompt = prompt .. ' args: ' .. args_text
    local ui_ok, ui_err = pcall(vim.ui.select, { 'Run tool', 'Cancel' }, {
        prompt = prompt,
    }, function(choice)
        if choice == 'Run tool' then
            on_decision(true, 'confirmed in prompt')
        else
            on_decision(false, 'cancelled')
        end
    end)
    if not ui_ok then
        on_decision(false, 'confirmation UI unavailable: ' .. tostring(ui_err))
    end
end

---@param server_name string
---@param tool_name string
---@param args table
---@param callback fun(err: string?, result: table?)
local function execute_call(server_name, tool_name, args, callback)
    client.request(server_name, 'tools/call', {
        name = tool_name,
        arguments = args,
    }, callback, TOOL_CALL_TIMEOUT_MS)
end

---@param server_name string
---@param tool_name string
---@param args table
---@param callback fun(err: string?, result: table?)
function M.call(server_name, tool_name, args, callback)
    assert(type(server_name) == 'string' and server_name ~= '', 'server_name must be non-empty')
    assert(type(tool_name) == 'string' and tool_name ~= '', 'tool_name must be non-empty')
    assert(type(args) == 'table', 'args must be a table')
    assert(type(callback) == 'function', 'callback must be a function')
    confirm_with_policy(server_name, tool_name, args, function(allowed, reason)
        if not allowed then
            callback('tool call denied: ' .. tostring(reason), nil)
            return
        end
        ensure_ready(server_name, function(start_err)
            if start_err ~= nil then
                callback(start_err, nil)
                return
            end
            execute_call(server_name, tool_name, args, callback)
        end)
    end)
end

return M
