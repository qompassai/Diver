-- lua/utils/sf/schema.lua
local cmdutil = require('utils.sf.cmdutil')
local util = require('utils.sf.util')

local M = {}

function M.describe(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local object = cmdutil.get_arg(opts) or vim.fn.input('Object name> ')
  if object == '' then return end
  util.open_term_cmd('sf schema describe --sobject ' .. util.shellescape(object), 20)
end

function M.describe_json(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local object = cmdutil.get_arg(opts) or vim.fn.input('Object name> ')
  if object == '' then return end
  util.open_term_cmd('sf schema describe --sobject ' .. util.shellescape(object) .. ' --json', 20)
end

function M.list_custom_objects()
  if not util.ensure_sf() or not util.ensure_org() then return end
  util.open_term_cmd('sf schema list objects --category custom', 20)
end

function M.list_objects()
  if not util.ensure_sf() or not util.ensure_org() then return end
  util.open_term_cmd('sf schema list objects', 20)
end

function M.sobject_describe(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local object = cmdutil.get_arg(opts) or vim.fn.input('sObject name> ')
  if object == '' then return end
  util.open_term_cmd('sf sobject describe --sobject ' .. util.shellescape(object), 20)
end

function M.sobject_list()
  if not util.ensure_sf() or not util.ensure_org() then return end
  util.open_term_cmd('sf sobject list', 20)
end

return M
