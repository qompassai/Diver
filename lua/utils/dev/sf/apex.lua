.lua
-- /qompassai/Diver/lua/utils/dev/sf/apex.lua
local core = require('utils.dev.sf.core')

local M = {}

---@param file string
---@return boolean
function M.is_apex_script(file)
  return file:match('%.apex$') ~= nil
end

---@param file string
---@return boolean
function M.is_apex_metadata(file)
  return file:match('%.cls$') ~= nil or file:match('%.trigger$') ~= nil
end

---@param file string
---@return boolean
function M.is_apex_any(file)
  return M.is_apex_script(file) or M.is_apex_metadata(file)
end

function M.run_current()
  if not core.ensure_sf() or not core.has_file() then
    return
  end
  local file = core.current_file()
  if not M.is_apex_script(file) then
    core.notify('Current file is not a .apex script', vim.log.levels.WARN)
    return
  end
  core.open_term_cmd('sf apex run --file ' .. core.shellescape(file), 16)
end

M.run_current_file = M.run_current

---@param opts? table
function M.run_file(opts)
  if not core.ensure_sf() then
    return
  end
  local file = core.get_arg(opts) or vim.fn.input('Apex script> ', vim.fn.expand('%:p'), 'file')
  if file == '' then
    return
  end
  if not M.is_apex_script(file) then
    core.notify('Apex execution files must use the .apex extension', vim.log.levels.WARN)
    return
  end
  core.open_term_cmd('sf apex run --file ' .. core.shellescape(file), 16)
end

function M.run_selection()
  if not core.ensure_sf() then
    return
  end
  local code = core.get_visual_selection()
  if code == '' then
    core.notify('No text selected', vim.log.levels.WARN)
    return
  end
  local tmp = vim.fn.tempname() .. '.apex'
  local fd = io.open(tmp, 'w')
  if not fd then
    core.notify('Could not write temporary Apex file', vim.log.levels.ERROR)
    return
  end
  fd:write(code)
  fd:close()
  core.open_term_cmd('sf apex run --file ' .. core.shellescape(tmp), 16)
end

function M.run_selection_interactive()
  if core.ensure_sf() then
    core.open_term_cmd('sf apex run', 16)
  end
end

function M.log_tail()
  if core.ensure_sf() then
    core.open_term_cmd('sf apex tail log --color', 16)
  end
end

M.tail_logs = M.log_tail

function M.log_list()
  if core.ensure_sf() then
    core.open_term_cmd('sf apex list log', 14)
  end
end

M.list_logs = M.log_list

---@param opts? table
function M.log_get(opts)
  if not core.ensure_sf() then
    return
  end
  local id = core.get_arg(opts) or vim.fn.input('Log ID: ')
  if id == '' then
    return
  end
  core.open_term_cmd('sf apex get log --log-id ' .. core.shellescape(id), 20)
end

M.get_log = M.log_get

---@param opts? table
function M.test_class(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local class = core.get_arg(opts)
  if not class or class == '' then
    local file = core.current_file()
    if file:match('%.cls$') then
      class = vim.fn.fnamemodify(file, ':t:r')
    else
      class = vim.fn.input('Apex test class> ')
    end
  end
  if class == '' then
    return
  end
  core.open_term_cmd(
    'sf apex run test --class-names ' .. core.shellescape(class) .. ' --result-format human --wait 10',
    20
  )
end

function M.test_current()
  return M.test_class({ args = '' })
end

M.commands = {
  { name = 'SfApexLogGet', fn = M.log_get, opts = { desc = 'Get an Apex debug log', nargs = '?' } },
  { name = 'SfApexLogList', fn = M.log_list, opts = { desc = 'List Apex debug logs', nargs = 0 } },
  { name = 'SfApexLogTail', fn = M.log_tail, opts = { desc = 'Tail Apex debug logs', nargs = 0 } },
  { name = 'SfApexRunCurrent', fn = M.run_current, opts = { desc = 'Run the current .apex script', nargs = 0 } },
  { name = 'SfApexRunFile', fn = M.run_file, opts = { desc = 'Run an Apex script file', nargs = '?' } },
  { name = 'SfApexTestClass', fn = M.test_class, opts = { desc = 'Run an Apex test class', nargs = '?' } },
  { name = 'SfApexTestCurrent', fn = M.test_current, opts = { desc = 'Run tests for the current Apex class', nargs = 0 } },
}

return M