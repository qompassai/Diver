-- lua/utils/sf/org.lua
local cmdutil = require('utils.sf.cmdutil')
local util = require('utils.sf.util')

local M = {}

function M.current()
  if not util.ensure_sf() then return end
  util.open_term_cmd('sf config get target-org', 12)
end

function M.display(opts)
  if not util.ensure_sf() then return end
  local target = cmdutil.get_arg(opts)
  local cmd = 'sf org display'
  if target then
    cmd = cmd .. ' --target-org ' .. util.shellescape(target)
  end
  util.open_term_cmd(cmd, 20)
end

function M.list()
  if not util.ensure_sf() then return end
  util.open_term_cmd('sf org list', 20)
end

function M.login_web(opts)
  if not util.ensure_sf() then return end
  local alias = cmdutil.get_arg(opts)
  local cmd = 'sf org login web'
  if alias then
    cmd = cmd .. ' --alias ' .. util.shellescape(alias)
  end
  util.open_term_cmd(cmd, 20)
end

function M.logout(opts)
  if not util.ensure_sf() then return end
  local target = cmdutil.get_arg(opts) or vim.fn.input('Target org alias/username (blank = prompt by CLI)> ')
  local cmd = 'sf org logout'
  if target ~= '' then
    cmd = cmd .. ' --target-org ' .. util.shellescape(target)
  end
  util.open_term_cmd(cmd, 20)
end

function M.open(opts)
  if not util.ensure_sf() then return end
  local path = cmdutil.get_arg(opts)
  local cmd = 'sf org open'
  if path then
    cmd = cmd .. ' --path ' .. util.shellescape(path)
  end
  util.open_term_cmd(cmd, 20)
end

function M.set_default(opts)
  if not util.ensure_sf() then return end
  local target = cmdutil.get_arg(opts) or vim.fn.input('Target org alias/username> ')
  if target == '' then return end
  util.open_term_cmd('sf config set target-org=' .. util.shellescape(target), 12)
end

return M
