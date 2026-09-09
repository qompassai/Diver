-- /qompassai/Diver/lua/utils/dev/sf/core.lua
-- Qompass AI Diver Salesforce Core Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local M = {}
local DEFAULT_TERM_HEIGHT = 20
local MAX_COMMAND_ARGUMENTS = 512
local MAX_TERM_HEIGHT = 60
local MIN_TERM_HEIGHT = 3

---@class SfCommandArgs
---@field args? string
---@field fargs? string[]

---@class SfTermOpts
---@field cwd? string
---@field env? table<string, string>
---@field on_exit? fun(code: integer)

---@class SfCommandSpec
---@field name string
---@field fn function
---@field opts? table

---@class SfEnsureOpts
---@field org? boolean
---@field project? boolean

---@class SfTargetOrgRow
---@field value? string

---@class SfTargetOrgResponse
---@field result? SfTargetOrgRow[]

---@param value any
---@return integer
local function to_integer(value)
  ---@type number?
  local number = tonumber(value)
  if number == nil or number ~= number or number == math.huge or number == -math.huge then
    return 0
  end
  return math.floor(number)
end

---@return string
local function working_directory()
  local directory = uv.cwd()
  if type(directory) == 'string' and directory ~= '' then
    return directory
  end
  local fallback = fn.getcwd()
  if type(fallback) == 'string' and fallback ~= '' then
    return fallback
  end
  return '.'
end

---@param path? string
---@param fallback string
---@return string
local function dirname_or(path, fallback)
  if type(path) ~= 'string' or path == '' then
    return fallback
  end
  local directory = fs.dirname(path)
  if type(directory) == 'string' and directory ~= '' then
    return directory
  end
  return fallback
end

---@param paths string[]
---@return string?
local function first_path(paths)
  local path = paths[1]
  if type(path) == 'string' and path ~= '' then
    return path
  end
  return nil
end

---@param stdout string
---@return SfTargetOrgResponse?
local function decode_target_org(stdout)
  local ok, decoded = pcall(vim.json.decode, stdout)
  if not ok or type(decoded) ~= 'table' then
    return nil
  end
  ---@cast decoded SfTargetOrgResponse
  return decoded
end

---@param stdout string
---@return boolean
local function has_target_org(stdout)
  local decoded = decode_target_org(stdout)
  if decoded == nil then
    return false
  end
  local rows = decoded.result
  if type(rows) ~= 'table' then
    return false
  end
  ---@type SfTargetOrgRow?
  local row = rows[1]
  if type(row) ~= 'table' then
    return false
  end
  local value = row.value
  return type(value) == 'string' and value ~= ''
end

---@param message any
---@param level? integer
function M.notify(message, level)
  vim.notify(tostring(message), level or vim.log.levels.INFO, {
    title = 'Salesforce',
  })
end

---@param value string
---@return string
function M.shellescape(value)
  return fn.shellescape(value)
end

---@param opts? SfCommandArgs
---@return string?
function M.get_arg(opts)
  if type(opts) ~= 'table' then
    return nil
  end
  if type(opts.args) == 'string' then
    local argument = vim.trim(opts.args)
    if argument ~= '' then
      return argument
    end
  end
  if type(opts.fargs) ~= 'table' then
    return nil
  end
  local argument = opts.fargs[1]
  if type(argument) == 'string' and argument ~= '' then
    return argument
  end
  return nil
end

---@param opts? SfCommandArgs
---@return string[]
function M.get_args(opts)
  if type(opts) ~= 'table' then
    return {}
  end
  ---@type string[]
  local arguments = {}
  if type(opts.fargs) == 'table' then
    for _, value in ipairs(opts.fargs) do
      if type(value) == 'string' and value ~= '' then
        arguments[#arguments + 1] = value
      end
    end
  elseif type(opts.args) == 'string' and opts.args ~= '' then
    arguments[1] = opts.args
  end
  return arguments
end

---@param prompt string
---@param completion? string
---@return string?
function M.input_required(prompt, completion)
  ---@type string
  local value = ''
  if type(completion) == 'string' and completion ~= '' then
    value = fn.input(prompt, '', completion)
  else
    value = fn.input(prompt)
  end
  if type(value) ~= 'string' or value == '' then
    return nil
  end
  return value
end

---@param opts? SfCommandArgs
---@param prompt string
---@param completion? string
---@return string?
function M.input_or_arg(opts, prompt, completion)
  return M.get_arg(opts) or M.input_required(prompt, completion)
end

---@param bufnr? integer
---@return string
function M.current_file(bufnr)
  return api.nvim_buf_get_name(bufnr or 0)
end

---@param bufnr? integer
---@return boolean
function M.has_file(bufnr)
  return M.current_file(bufnr) ~= ''
end

---@param bufnr? integer
---@return string
local function search_start(bufnr)
  local fallback = working_directory()
  local file = M.current_file(bufnr)
  if file == '' then
    return fallback
  end
  return dirname_or(file, fallback)
end

---@param bufnr? integer
---@return string
function M.root(bufnr)
  local start = search_start(bufnr)
  local project_file = first_path(fs.find('sfdx-project.json', {
    path = start,
    type = 'file',
    upward = true,
  }))
  if project_file ~= nil then
    return dirname_or(project_file, start)
  end
  local git_marker = first_path(fs.find('.git', {
    path = start,
    upward = true,
  }))
  if git_marker ~= nil then
    return dirname_or(git_marker, start)
  end
  return start
end

---@param bufnr? integer
---@return boolean
function M.in_sf_project(bufnr)
  local marker = first_path(fs.find('sfdx-project.json', {
    path = search_start(bufnr),
    type = 'file',
    upward = true,
  }))
  return marker ~= nil
end

---@return boolean
function M.ensure_sf()
  if fn.executable('sf') == 1 then
    return true
  end
  M.notify('Salesforce CLI executable `sf` was not found in PATH', vim.log.levels.ERROR)
  return false
end

---@param bufnr? integer
---@return boolean
function M.ensure_project(bufnr)
  if M.in_sf_project(bufnr) then
    return true
  end
  M.notify('Current buffer is not inside a Salesforce project', vim.log.levels.WARN)
  return false
end

---@return boolean
function M.ensure_org()
  if not M.ensure_sf() then
    return false
  end
  local result = vim
    .system({
      'sf',
      'config',
      'get',
      'target-org',
      '--json',
    }, {
      cwd = M.root(),
      text = true,
    })
    :wait()
  if result.code ~= 0 or type(result.stdout) ~= 'string' then
    M.notify('No default Salesforce target org is configured', vim.log.levels.WARN)
    return false
  end
  if not has_target_org(result.stdout) then
    M.notify('No default Salesforce target org is configured', vim.log.levels.WARN)
    return false
  end
  return true
end

---@param opts? SfEnsureOpts
---@return boolean
function M.ensure(opts)
  ---@type SfEnsureOpts
  local requirements = opts or {}
  if not M.ensure_sf() then
    return false
  end
  if requirements.project and not M.ensure_project() then
    return false
  end
  if requirements.org and not M.ensure_org() then
    return false
  end
  return true
end

---@param mark string
---@return integer, integer
local function mark_position(mark)
  local position = fn.getpos(mark)
  if type(position) ~= 'table' then
    return 0, 0
  end
  return to_integer(position[2]), to_integer(position[3])
end

---@return string
function M.get_visual_selection()
  ---@type integer
  local start_line = 0
  ---@type integer
  local start_column = 0
  ---@type integer
  local end_line = 0
  ---@type integer
  local end_column = 0
  start_line, start_column = mark_position("'<")
  end_line, end_column = mark_position("'>")
  if start_line < 1 or end_line < 1 then
    return ''
  end
  if start_line > end_line or (start_line == end_line and start_column > end_column) then
    ---@type integer
    local previous_start_line = start_line
    ---@type integer
    local previous_start_column = start_column
    start_line = end_line
    start_column = end_column
    end_line = previous_start_line
    end_column = previous_start_column
  end
  ---@type integer
  local buffer_start = to_integer(start_line - 1)
  ---@type integer
  local buffer_end = to_integer(end_line)
  ---@type string[]
  local lines = api.nvim_buf_get_lines(0, buffer_start, buffer_end, false)
  local line_count = #lines
  if line_count == 0 then
    return ''
  end
  if fn.visualmode() ~= 'V' then
    if start_column < 1 or end_column < 1 then
      return ''
    end
    local first_line = lines[1]
    local last_line = lines[line_count]
    if type(first_line) ~= 'string' or type(last_line) ~= 'string' then
      return ''
    end
    lines[line_count] = last_line:sub(1, end_column)
    lines[1] = first_line:sub(start_column)
  end
  return table.concat(lines, '\n')
end

---@param height? integer
---@return integer
local function terminal_height(height)
  local requested = to_integer(height or DEFAULT_TERM_HEIGHT)
  if requested < MIN_TERM_HEIGHT then
    return MIN_TERM_HEIGHT
  end
  if requested > MAX_TERM_HEIGHT then
    return MAX_TERM_HEIGHT
  end
  return requested
end

---@param command string|string[]
---@return string[]?
local function command_argv(command)
  if type(command) == 'string' then
    local shell = vim.o.shell
    local shell_flag = vim.o.shellcmdflag
    if type(shell) ~= 'string' or shell == '' or type(shell_flag) ~= 'string' or shell_flag == '' then
      return nil
    end
    return { shell, shell_flag, command }
  end
  if type(command) ~= 'table' then
    return nil
  end
  local argument_count = #command
  if argument_count == 0 or argument_count > MAX_COMMAND_ARGUMENTS then
    return nil
  end
  ---@type string[]
  local argv = {}
  for index = 1, argument_count do
    local value = command[index]
    if type(value) ~= 'string' then
      return nil
    end
    argv[index] = value
  end
  return argv
end

---@param command string|string[]
---@param height? integer
---@param opts? SfTermOpts
---@return integer?
function M.open_term_cmd(command, height, opts)
  if opts ~= nil and type(opts) ~= 'table' then
    M.notify('Invalid Salesforce terminal options', vim.log.levels.ERROR)
    return nil
  end
  ---@type SfTermOpts
  local options = opts or {}
  local argv = command_argv(command)
  if argv == nil then
    M.notify('Refusing to start an invalid Salesforce command', vim.log.levels.ERROR)
    return nil
  end
  vim.cmd(('botright %dnew'):format(terminal_height(height)))
  local bufnr = api.nvim_get_current_buf()
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  local job = fn.jobstart(argv, {
    cwd = options.cwd or M.root(),
    env = options.env,
    on_exit = function(_, code)
      local exit_code = to_integer(code)
      if type(options.on_exit) == 'function' then
        local ok, err = pcall(options.on_exit, exit_code)
        if not ok then
          vim.schedule(function()
            M.notify(err, vim.log.levels.ERROR)
          end)
        end
      end
      if exit_code ~= 0 then
        vim.schedule(function()
          M.notify(('Salesforce command exited with status %d'):format(exit_code), vim.log.levels.WARN)
        end)
      end
    end,
    term = true,
  })
  local job_id = to_integer(job)
  if job_id <= 0 then
    M.notify('Unable to start Salesforce terminal command', vim.log.levels.ERROR)
    return nil
  end
  vim.cmd('startinsert')
  return job_id
end

---@param specs SfCommandSpec[]
function M.register_commands(specs)
  for _, spec in ipairs(specs) do
    assert(type(spec.name) == 'string' and spec.name ~= '', 'Salesforce command is missing a name')
    assert(type(spec.fn) == 'function', ('Invalid Salesforce command handler: %s'):format(spec.name))
    assert(spec.opts == nil or type(spec.opts) == 'table', ('Invalid Salesforce command options: %s'):format(spec.name))
    pcall(api.nvim_del_user_command, spec.name)
    api.nvim_create_user_command(spec.name, spec.fn, spec.opts or {})
  end
end

return M