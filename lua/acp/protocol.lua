-- /qompassai/Diver/lua/acp/protocol.lua
-- Qompass AI ACP Method Names and Message Builders (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://agentclientprotocol.com
--
-- This file intentionally holds no I/O and no state -- just method-name
-- constants and pure functions that build request parameter tables. All
-- actual transport lives in acp/rpc.lua; all session state lives in
-- acp/session.lua.

local M = {}

M.METHOD = {
  INITIALIZE = 'initialize',
  SESSION_NEW = 'session/new',
  SESSION_PROMPT = 'session/prompt',
  SESSION_CANCEL = 'session/cancel',
  SESSION_UPDATE = 'session/update', -- agent -> client notification (streaming)
  PERMISSION_REQUEST = 'permission/request', -- agent -> client request
}

M.PROTOCOL_VERSION = 1

---@param cwd string
---@return table
function M.initialize_params(cwd)
  assert(type(cwd) == 'string' and cwd ~= '', 'cwd must be a nonempty string')
  return {
    protocolVersion = M.PROTOCOL_VERSION,
    clientInfo = {
      name = 'qompassai-diver',
      version = '1.0.0',
    },
    cwd = cwd,
  }
end

---@param cwd string
---@return table
function M.new_session_params(cwd)
  assert(type(cwd) == 'string' and cwd ~= '', 'cwd must be a nonempty string')
  return {
    cwd = cwd,
    mcpServers = {},
  }
end

---@param session_id string
---@param text string
---@return table
function M.prompt_params(session_id, text)
  assert(type(session_id) == 'string' and session_id ~= '', 'session_id must be a nonempty string')
  assert(type(text) == 'string' and text ~= '', 'text must be a nonempty string')
  return {
    sessionId = session_id,
    prompt = {
      {
        type = 'text',
        text = text,
      },
    },
  }
end

---@param session_id string
---@return table
function M.cancel_params(session_id)
  assert(type(session_id) == 'string' and session_id ~= '', 'session_id must be a nonempty string')
  return {
    sessionId = session_id,
  }
end

return M
