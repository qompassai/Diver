-- /qompassai/Diver/lua/acp/config.lua
-- Explicit trusted endpoints; discovery cannot add executable tools or peers.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local util = require('acp.util')
local M = {}
local DEFAULTS = {
    agents = {},
    context = { command = { 'acp' }, global_root = false },
    curl = 'curl',
    mappings = false,
    store = { enabled = false },
    timeouts = { request_ms = 30000, turn_ms = 300000, poll_ms = 1000 },
}
M.options = vim.deepcopy(DEFAULTS)

function M.url(value)
    if not util.string(value, 4096) or value:find('[%s%c\\?#]') then
        return nil, 'Endpoint must be an absolute HTTP(S) URL without query or fragment'
    end
    local scheme, authority = value:match('^(https?)://([^/]+)')
    if not scheme or authority:find('[@%%]') then
        return nil, 'Invalid endpoint authority or embedded credentials'
    end
    local host, port = authority:match('^([%w.%-]+):?(%d*)$')
    if not host then
        host, port = authority:match('^(%[::1%]):?(%d*)$')
    end
    if not host or (port ~= '' and not util.integer(tonumber(port), 1, 65535)) then
        return nil, 'Unsupported endpoint host or port'
    end
    if scheme == 'http' and host ~= '127.0.0.1' and host ~= 'localhost' and host ~= '[::1]' then
        return nil, 'Remote endpoints require HTTPS; HTTP is allowed only on loopback'
    end
    return scheme .. '://' .. authority
end

local function agent_options(name, agent)
    if not util.string(name, 64) or not name:match('^[%w_-]+$') or type(agent) ~= 'table' then
        return nil, 'Invalid named agent configuration'
    end
    if agent.command or agent.cmd then
        return nil, 'Agent Client subprocess configurations must be migrated to HTTP endpoints'
    end
    agent.protocol = agent.protocol or 'a2a'
    if agent.protocol ~= 'a2a' and agent.protocol ~= 'acp-communication' then
        return nil, 'Expected a2a or acp-communication'
    end
    local origin, err = M.url(agent.url)
    if not origin then
        return nil, err
    end
    agent.url = agent.url:gsub('/$', '')
    agent.card_url = agent.card_url or (origin .. '/.well-known/agent-card.json')
    if M.url(agent.card_url) ~= origin then
        return nil, 'Agent Card and endpoint must have the same configured origin'
    end
    if agent.protocol == 'acp-communication' and not util.string(agent.agent_name, 128) then
        return nil, 'Communication ACP requires agent_name'
    end
    if
        agent.run_mode
        and agent.run_mode ~= 'async'
        and agent.run_mode ~= 'sync'
        and agent.run_mode ~= 'stream'
    then
        return nil, 'Communication ACP run_mode must be async, sync, or stream'
    end
    if
        agent.token_env
        and (not util.string(agent.token_env, 128) or not agent.token_env:match('^[%a_][%w_]*$'))
    then
        return nil, 'Invalid credential environment variable name'
    end
    agent.streaming = agent.streaming ~= false
    agent.version = agent.version or '1.0'
    if agent.version ~= '1.0' and agent.version ~= '0.3' then
        return nil, 'Supported A2A versions are 1.0 and 0.3 (no implicit downgrade)'
    end
    return true
end

function M.setup(options)
    if options ~= nil and type(options) ~= 'table' then
        return nil, 'acp.setup expects a table'
    end
    local merged = vim.tbl_deep_extend('force', vim.deepcopy(DEFAULTS), options or {})
    if
        type(merged.context) ~= 'table'
        or type(merged.timeouts) ~= 'table'
        or type(merged.store) ~= 'table'
    then
        return nil, 'context, timeouts, and store must be option tables'
    end
    if type(merged.agents) ~= 'table' or vim.tbl_count(merged.agents) > 32 then
        return nil, 'Configure at most 32 trusted agents'
    end
    for name, agent in pairs(merged.agents) do
        local ok, err = agent_options(name, agent)
        if not ok then
            return nil, tostring(name) .. ': ' .. err
        end
    end
    for _, key in ipairs({ 'poll_ms', 'request_ms', 'turn_ms' }) do
        if not util.integer(merged.timeouts[key], 10, 3600000) then
            return nil, 'Invalid timeout: ' .. key
        end
    end
    if not util.argv(merged.context.command) or not util.string(merged.curl) then
        return nil, 'Invalid executable configuration'
    end
    if merged.store.directory and not util.absolute(merged.store.directory) then
        return nil, 'store.directory must be an absolute path'
    end
    M.options = merged
    return true
end

function M.names(protocol)
    local names = {}
    for name, agent in pairs(M.options.agents) do
        if not protocol or protocol == agent.protocol then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end
return M
