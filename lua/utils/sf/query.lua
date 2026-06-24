-- lua/utils/sf/query.lua
local cmdutil = require('utils.sf.cmdutil')
local util = require('utils.sf.util')

local M = {}

function M.current_buffer()
  if not util.ensure_sf() or not util.ensure_org() then return end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local q = table.concat(lines, ' ')
  if q:gsub('%s+', '') == '' then return end
  util.open_term_cmd('sf data query --query ' .. util.shellescape(q), 20)
end

function M.current_file(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local file = cmdutil.get_arg(opts) or vim.fn.expand('%:p')
  if file == '' then return end
  util.open_term_cmd('sf data query --file ' .. util.shellescape(file), 20)
end

function M.explain(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local q = cmdutil.get_arg(opts) or vim.fn.input('SOQL to explain> ')
  if q == '' then return end
  util.open_term_cmd('sf data query --query ' .. util.shellescape(q) .. ' --plan', 20)
end

function M.soql(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local q = cmdutil.get_arg(opts) or vim.fn.input('SOQL> ')
  if q == '' then return end
  util.open_term_cmd('sf data query --query ' .. util.shellescape(q), 20)
end

return M
