-- /qompassai/Diver/lua/acp/session.lua
-- Qompass AI ACP Session Lifecycle (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Owns the mapping from a running agent process to a single active ACP
-- session: spawn, initialize handshake, session/new, prompt turns, cancel,
-- teardown. UI rendering lives in acp/ui.lua; persistence in acp/store.lua.

local registry = require('acp.registry')
local rpc = require('acp.rpc')
local protocol = require('acp.protocol')

local M = {}

local SESSION_COUNT_MAX = 8
local HANDSHAKE_TIMEOUT_MS = 10000

---@class AcpSessionState
---@field id string?
---@field agent_name string
---@field client AcpClient
---@field cwd string
---@field on_update? fun(update: table)
---@field on_permission? fun(request: table): table

---@type table<string, AcpSessionState>
M.sessions = {}

local function generation_id()
  return tostring(vim.uv.hrtime())
end

---@param agent_name string
---@param opts { cwd?: string, on_update?: fun(update: table), on_permission?: fun(request: table): table }
---@param callback fun(session_key: string?, err: string?)
function M.start(agent_name, opts, callback)
  assert(vim.tbl_count(M.sessions) < SESSION_COUNT_MAX, 'ACP session bound exceeded')

  local spec = registry.get(agent_name)
  if not spec then
    callback(nil, 'Unknown ACP agent: ' .. tostring(agent_name))
    return
  end
  if spec.verified == false then
    vim.notify('ACP agent "' .. agent_name .. '" is unverified: ' .. (spec.notes or 'no notes'), vim.log.levels.WARN)
  end

  local cwd = opts.cwd or vim.fn.getcwd()
  local client, spawn_err
  client, spawn_err = rpc.start(spec.cmd, {
    cwd = cwd,
    on_exit = function(code)
      for key, session in pairs(M.sessions) do
        if session.client == client then
          M.sessions[key] = nil
          vim.notify('ACP agent "' .. session.agent_name .. '" exited (' .. code .. ')', vim.log.levels.WARN)
        end
      end
    end,
  })
  if not client then
    callback(nil, spawn_err)
    return
  end

  local key = agent_name .. ':' .. generation_id()
  ---@type AcpSessionState
  local state = {
    id = nil,
    agent_name = agent_name,
    client = client,
    cwd = cwd,
    on_update = opts.on_update,
    on_permission = opts.on_permission,
  }
  M.sessions[key] = state

  rpc.on(client, protocol.METHOD.SESSION_UPDATE, function(params)
    if state.on_update then
      state.on_update(params)
    end
    return true, nil
  end)

  rpc.on(client, protocol.METHOD.PERMISSION_REQUEST, function(params)
    if state.on_permission then
      return state.on_permission(params), nil
    end
    return { outcome = 'denied' }, nil
  end)

  local settled = false
  local timer = vim.defer_fn(function()
    if settled then
      return
    end
    settled = true
    M.sessions[key] = nil
    rpc.stop(client)
    callback(nil, 'ACP initialize handshake timed out')
  end, HANDSHAKE_TIMEOUT_MS)

  rpc.request(client, protocol.METHOD.INITIALIZE, protocol.initialize_params(cwd), function(init_err)
    if settled then
      return
    end
    if init_err then
      settled = true
      timer:stop()
      M.sessions[key] = nil
      rpc.stop(client)
      callback(nil, 'ACP initialize failed: ' .. tostring(init_err.message or init_err))
      return
    end

    rpc.request(client, protocol.METHOD.SESSION_NEW, protocol.new_session_params(cwd), function(new_err, result)
      settled = true
      timer:stop()
      if new_err or type(result) ~= 'table' or type(result.sessionId) ~= 'string' then
        M.sessions[key] = nil
        rpc.stop(client)
        callback(nil, 'ACP session/new failed: ' .. tostring(new_err and new_err.message or 'invalid result'))
        return
      end
      state.id = result.sessionId
      callback(key, nil)
    end)
  end)
end

---@param session_key string
---@param text string
---@param callback? fun(err: string?)
function M.prompt(session_key, text, callback)
  local state = M.sessions[session_key]
  assert(state and state.id, 'Unknown or unready ACP session: ' .. tostring(session_key))
  rpc.request(state.client, protocol.METHOD.SESSION_PROMPT, protocol.prompt_params(state.id, text), function(err)
    if callback then
      callback(err and tostring(err.message or err) or nil)
    end
  end)
end

---@param session_key string
function M.cancel(session_key)
  local state = M.sessions[session_key]
  if not state or not state.id then
    return
  end
  rpc.notify(state.client, protocol.METHOD.SESSION_CANCEL, protocol.cancel_params(state.id))
end

---@param session_key string
function M.stop(session_key)
  local state = M.sessions[session_key]
  if not state then
    return
  end
  rpc.stop(state.client)
  M.sessions[session_key] = nil
end

function M.stop_all()
  for key in pairs(M.sessions) do
    M.stop(key)
  end
end

return M
