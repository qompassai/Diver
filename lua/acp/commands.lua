-- /qompassai/Diver/lua/acp/commands.lua
-- Qompass AI ACP User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

local api = vim.api
local registry = require('acp.registry')
local session = require('acp.session')
local permissions = require('acp.permissions')
local store = require('acp.store')
local ui = require('acp.ui')
local context = require('acp.context')

local M = {}

---@type string? Most recently started session, used as the implicit
---  target for :AcpPrompt/:AcpCancel/:AcpStop when no key is given.
local active_session

---@param callback fun(name: string?)
local function pick_agent(callback)
  local names = registry.list()
  if #names == 0 then
    vim.notify('No ACP agents registered', vim.log.levels.WARN)
    callback(nil)
    return
  end
  vim.ui.select(names, { prompt = 'ACP agent' }, callback)
end

local function start_agent(name)
  session.start(name, {
    on_update = function(update)
      if active_session then
        ui.append_update(active_session, name, update)
        if type(update.text) == 'string' then
          store.append(active_session, name, 'assistant', update.text)
        end
      end
    end,
    on_permission = permissions.prompt,
  }, function(key, err)
    if not key then
      vim.notify('Failed to start ACP agent "' .. name .. '": ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
    active_session = key
    ui.open(key, name, 'split')
    vim.notify('ACP session started: ' .. name)
  end)
end

api.nvim_create_user_command('AcpAgents', function()
  pick_agent(function(name)
    if name then
      start_agent(name)
    end
  end)
end, { desc = 'Pick and start an ACP agent session' })

api.nvim_create_user_command('AcpStart', function(command)
  local name = command.args ~= '' and command.args or nil
  if name then
    start_agent(name)
  else
    pick_agent(function(picked)
      if picked then
        start_agent(picked)
      end
    end)
  end
end, {
  nargs = '?',
  complete = function(lead)
    return vim.tbl_filter(function(name)
      return name:sub(1, #lead) == lead
    end, registry.list())
  end,
  desc = 'Start a named ACP agent session',
})

api.nvim_create_user_command('AcpPrompt', function(command)
  if not active_session then
    vim.notify('No active ACP session; run :AcpAgents first', vim.log.levels.WARN)
    return
  end
  local text = command.args
  if text == '' then
    vim.ui.input({ prompt = 'ACP prompt: ' }, function(value)
      if value and value ~= '' then
        local state = session.sessions[active_session]
        ui.append_user(active_session, state.agent_name, value)
        store.append(active_session, state.agent_name, 'user', value)
        session.prompt(active_session, value)
      end
    end)
    return
  end
  local state = session.sessions[active_session]
  ui.append_user(active_session, state.agent_name, text)
  store.append(active_session, state.agent_name, 'user', text)
  session.prompt(active_session, text)
end, { nargs = '*', desc = 'Send a prompt to the active ACP session' })

api.nvim_create_user_command('AcpCancel', function()
  if active_session then
    session.cancel(active_session)
  end
end, { desc = 'Cancel the active ACP session turn' })

api.nvim_create_user_command('AcpStop', function()
  if active_session then
    session.stop(active_session)
    ui.close(active_session)
    active_session = nil
  end
end, { desc = 'Stop the active ACP session' })

api.nvim_create_user_command('AcpRegistryRefresh', function()
  registry.refresh(function(ok, _, err)
    if ok then
      vim.notify('ACP registry cache updated')
    else
      vim.notify('ACP registry refresh failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
  end)
end, { desc = 'Refresh the cached official ACP agent registry' })

api.nvim_create_user_command('AcpContextScaffold', function()
  local created = context.scaffold()
  vim.notify(created .. ' agent/ context file(s) created')
end, { desc = 'Scaffold this project\'s agent/ context directory' })

api.nvim_create_user_command('AcpContextBrowse', function()
  context.browse()
end, { desc = 'Browse this project\'s agent/ context files' })

return M
