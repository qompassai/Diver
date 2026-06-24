-- lua/utils/sf/files.lua
local cmdutil = require('utils.sf.cmdutil')
local util = require('utils.sf.util')

local M = {}

function M.deploy_current()
  if not util.ensure_sf() or not util.ensure_project() then return end
  local file = vim.fn.expand('%:p')
  if file == '' then return end
  util.open_term_cmd('sf project deploy start --source-file ' .. util.shellescape(file), 20)
end

function M.deploy_file(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local file = cmdutil.get_arg(opts) or vim.fn.input('File to deploy> ', vim.fn.expand('%:p'), 'file')
  if file == '' then return end
  util.open_term_cmd('sf project deploy start --source-file ' .. util.shellescape(file), 20)
end

function M.deploy_manifest(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local file = cmdutil.get_arg(opts) or vim.fn.input('Manifest file> ', 'package.xml', 'file')
  if file == '' then return end
  util.open_term_cmd('sf project deploy start --manifest ' .. util.shellescape(file), 20)
end

function M.deploy_project(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local path = cmdutil.get_arg(opts) or 'force-app'
  util.open_term_cmd('sf project deploy start --source-dir ' .. util.shellescape(path), 20)
end

function M.deploy_validate(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local path = cmdutil.get_arg(opts) or 'force-app'
  util.open_term_cmd('sf project deploy validate --source-dir ' .. util.shellescape(path), 20)
end

function M.retrieve_current()
  if not util.ensure_sf() or not util.ensure_project() then return end
  local file = vim.fn.expand('%:p')
  if file == '' then return end
  util.open_term_cmd('sf project retrieve start --source-file ' .. util.shellescape(file), 20)
end

function M.retrieve_file(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local file = cmdutil.get_arg(opts) or vim.fn.input('File to retrieve> ', vim.fn.expand('%:p'), 'file')
  if file == '' then return end
  util.open_term_cmd('sf project retrieve start --source-file ' .. util.shellescape(file), 20)
end

function M.retrieve_manifest(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local file = cmdutil.get_arg(opts) or vim.fn.input('Manifest file> ', 'package.xml', 'file')
  if file == '' then return end
  util.open_term_cmd('sf project retrieve start --manifest ' .. util.shellescape(file), 20)
end

return M
