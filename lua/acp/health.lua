-- /qompassai/Diver/lua/acp/health.lua
-- Qompass AI ACP checkhealth (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Run with :checkhealth acp

local registry = require('acp.registry')

local M = {}

function M.check()
  local health = vim.health

  health.start('ACP: transport dependencies')
  if vim.fn.executable('curl') == 1 then
    health.ok('curl found (needed for :AcpRegistryRefresh)')
  else
    health.warn('curl not found; :AcpRegistryRefresh will fail')
  end
  if vim.fn.executable('sqlite3') == 1 then
    health.ok('sqlite3 found (needed for transcript persistence)')
  else
    health.warn('sqlite3 not found; acp.store will silently drop transcripts')
  end

  health.start('ACP: registered agents')
  local names = registry.list()
  if #names == 0 then
    health.warn('No agents registered in acp.registry')
    return
  end

  for _, name in ipairs(names) do
    local spec = registry.get(name)
    if not spec then
      health.error(name .. ': registry.get() returned nil for a listed name')
    elseif vim.fn.executable(spec.cmd[1]) ~= 1 then
      health.warn(name .. ': executable not found: ' .. spec.cmd[1])
    elseif spec.verified == false then
      health.warn(name .. ': executable found, but invocation is unverified (' .. (spec.notes or '') .. ')')
    else
      health.ok(name .. ': executable found (' .. spec.kind .. ')')
    end
  end
end

return M
