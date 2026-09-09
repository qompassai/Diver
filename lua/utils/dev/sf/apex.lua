-- /qompassai/Diver/lua/utils/dev/sf/apex.lua
-- Qompass AI Diver Salesforce Apex Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local core = require('utils.dev.sf.core')
local fn = vim.fn
local uv = vim.uv
local M = {}
---@param path string
---@return boolean
function M.is_apex_script(path)
  return path:lower():match('%.apex$') ~= nil
end

---@param path string
---@return boolean
function M.is_apex_metadata(path)
  local lower = path:lower()
  return lower:match('%.cls$') ~= nil or lower:match('%.trigger$') ~= nil
end

---@param path string
---@return boolean
function M.is_apex_any(path)
  return M.is_apex_script(path) or M.is_apex_metadata(path)
end

function M.run_current()
  if not core.ensure() then
    return
  end
  local path = core.current_file()
  if path == '' then
    core.notify('Current buffer is not backed by a file', vim.log.levels.WARN)
    return
  end
  if not M.is_apex_script(path) then
    core.notify('Current file is not a .apex script', vim.log.levels.WARN)
    return
  end
  core.open_term_cmd({ 'sf', 'apex', 'run', '--file', path }, 16)
end

M.run_current_file = M.run_current

---@param opts? SfCommandArgs
function M.run_file(opts)
  if not core.ensure() then
    return
  end
  local path = core.get_arg(opts) or fn.input('Apex script> ', fn.expand('%:p'), 'file')
  if type(path) ~= 'string' or path == '' then
    return
  end
  if not M.is_apex_script(path) then
    core.notify('Apex execution files must use the .apex extension', vim.log.levels.WARN)
    return
  end
  core.open_term_cmd({
    'sf',
    'apex',
    'run',
    '--file',
    path,
  }, 16)
end

function M.run_selection()
  if not core.ensure() then
    return
  end
  local code = core.get_visual_selection()
  if code == '' then
    core.notify('No text selected', vim.log.levels.WARN)
    return
  end
  local path = fn.tempname() .. '.apex'
  local file, open_error = io.open(path, 'wb')
  if not file then
    core.notify(open_error or 'Could not write temporary Apex file', vim.log.levels.ERROR)
    return
  end
  local ok, write_error = file:write(code)
  file:close()
  if not ok then
    pcall(uv.fs_unlink, path)
    core.notify(write_error or 'Could not write temporary Apex file', vim.log.levels.ERROR)
    return
  end
  local job = core.open_term_cmd(
    {
      'sf',
      'apex',
      'run',
      '--file',
      path,
    },
    16,
    {
      on_exit = function()
        pcall(uv.fs_unlink, path)
      end,
    }
  )
  if not job then
    pcall(uv.fs_unlink, path)
  end
end

function M.run_interactive()
  if core.ensure() then
    core.open_term_cmd({ 'sf', 'apex', 'run' }, 16)
  end
end

M.run_selection_interactive = M.run_interactive

function M.log_tail()
  if core.ensure() then
    core.open_term_cmd({
      'sf',
      'apex',
      'tail',
      'log',
      '--color',
    }, 16)
  end
end

M.tail_logs = M.log_tail

function M.log_list()
  if core.ensure() then
    core.open_term_cmd({
      'sf',
      'apex',
      'list',
      'log',
    }, 14)
  end
end

M.list_logs = M.log_list

---@param opts? SfCommandArgs
function M.log_get(opts)
  if not core.ensure() then
    return
  end
  local log_id = core.get_arg(opts) or fn.input('Log ID> ')
  if type(log_id) ~= 'string' or log_id == '' then
    return
  end
  core.open_term_cmd({
    'sf',
    'apex',
    'get',
    'log',
    '--log-id',
    log_id,
  }, 20)
end

M.get_log = M.log_get

---@param opts? SfCommandArgs
function M.test_class(opts)
  if not core.ensure({ org = true }) then
    return
  end
  local class_name = core.get_arg(opts)
  if not class_name then
    local path = core.current_file()
    if path:lower():match('%.cls$') then
      class_name = fn.fnamemodify(path, ':t:r')
    else
      class_name = fn.input('Apex test class> ')
    end
  end
  if type(class_name) ~= 'string' or class_name == '' then
    return
  end
  core.open_term_cmd({
    'sf',
    'apex',
    'run',
    'test',
    '--class-names',
    class_name,
    '--result-format',
    'human',
    '--wait',
    '10',
  }, 20)
end

function M.test_current()
  M.test_class()
end

M.commands = {
  {
    name = 'SfApexLogGet',
    fn = M.log_get,
    opts = {
      desc = 'Get an Apex debug log',
      nargs = '?',
    },
  },
  { name = 'SfApexLogList', fn = M.log_list, opts = {
    desc = 'List Apex debug logs',
    nargs = 0,
  } },
  { name = 'SfApexLogTail', fn = M.log_tail, opts = {
    desc = 'Tail Apex debug logs',
    nargs = 0,
  } },
  {
    name = 'SfApexRunCurrent',
    fn = M.run_current,
    opts = {
      desc = 'Run the current .apex script',
      nargs = 0,
    },
  },
  {
    name = 'SfApexRunFile',
    fn = M.run_file,
    opts = {
      complete = 'file',
      desc = 'Run an Apex script file',
      nargs = '?',
    },
  },
  {
    name = 'SfApexRunInteractive',
    fn = M.run_interactive,
    opts = {
      desc = 'Open an interactive Apex execution session',
      nargs = 0,
    },
  },
  {
    name = 'SfApexRunSelection',
    fn = M.run_selection,
    opts = {
      desc = 'Run the selected Apex code',
      range = true,
    },
  },
  { name = 'SfApexTestClass', fn = M.test_class, opts = {
    desc = 'Run an Apex test class',
    nargs = '?',
  } },
  {
    name = 'SfApexTestCurrent',
    fn = M.test_current,
    opts = {
      desc = 'Run tests for the current Apex class',
      nargs = 0,
    },
  },
}

return M