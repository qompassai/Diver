-- /qompassai/Diver/lua/acp/permissions.lua
-- Qompass AI ACP Permission Prompts (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- ACP agents request permission before running tools (file writes, shell
-- commands, etc.) via the agent -> client `permission/request` method.
-- This module is the default on_permission handler passed to
-- acp.session.start(); it is synchronous from the agent's perspective, but
-- Neovim's vim.ui.select is itself async, so the actual RPC reply is sent
-- by acp/rpc.lua only after the user responds (see session.lua's handler
-- wiring, which awaits this function's return through a blocking wait
-- bounded by PROMPT_TIMEOUT_MS below).

local M = {}

local PROMPT_TIMEOUT_MS = 60000

---@param request table Must include a human-readable `title`/`description`.
---@return table outcome { outcome: 'allowed'|'denied' }
function M.prompt(request)
  assert(type(request) == 'table', 'permission request must be a table')

  local description = type(request.title) == 'string' and request.title
    or type(request.description) == 'string' and request.description
    or '(no description provided)'

  local choice
  local done = false

  vim.ui.select({ 'Allow', 'Deny' }, {
    prompt = 'ACP permission request: ' .. description,
  }, function(selected)
    choice = selected
    done = true
  end)

  local completed = vim.wait(PROMPT_TIMEOUT_MS, function()
    return done
  end, 20)

  if not completed or choice ~= 'Allow' then
    return {
      outcome = 'denied',
    }
  end
  return {
    outcome = 'allowed',
  }
end

return M
