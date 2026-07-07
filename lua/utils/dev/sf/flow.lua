-- /qompassai/Diver/lua/utils/sf/flow.lua
-- Qompass AI Salesforce Flow Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local util = require('utils.dev.sf.util')
local M = {}
function M.list()
  if not util.ensure_sf() or not util.ensure_org() then
    return
  end
  util.open_term_cmd('sf flow list', 20)
end
function M.get()
  if not util.ensure_sf() or not util.ensure_org() then
    return
  end
  local name = vim.fn.input('Flow API name> ')
  if name == '' then
    return
  end
  util.open_term_cmd('sf flow get --flow-api-name ' .. util.shellescape(name), 20)
end
function M.run()
  if not util.ensure_sf() or not util.ensure_org() then
    return
  end
  local name = vim.fn.input('Flow API name> ')
  if name == '' then
    return
  end
  util.open_term_cmd('sf flow run --flow-api-name ' .. util.shellescape(name), 20)
end
function M.deactivate()
  if not util.ensure_sf() or not util.ensure_org() then
    return
  end
  local name = vim.fn.input('Flow API name> ')
  if name == '' then
    return
  end
  util.open_term_cmd('sf flow deactivate --flow-api-name ' .. util.shellescape(name), 20)
end
function M.interview_list()
  if not util.ensure_sf() or not util.ensure_org() then
    return
  end
  util.open_term_cmd('sf flow interview list', 20)
end
function M.interview_resume()
  if not util.ensure_sf() or not util.ensure_org() then
    return
  end
  local id = vim.fn.input('Interview ID> ')
  if id == '' then
    return
  end
  util.open_term_cmd('sf flow interview resume --id ' .. util.shellescape(id), 20)
end
return M
