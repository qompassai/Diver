-- /qompassai/Diver/lua/utils/dev/sf/core.lua
local api = vim.api
local fn = vim.fn
local uv = vim.uv

local M = {}

---@param msg string
---@param level? integer
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, {
    title = 'Salesforce',
  })
end

---@param value string
---@return string
function M.shellescape(value)
  return fn.shellescape(value)
end

---@param opts? table
---@return string?
function M.get_arg(opts)
  if not opts then
    return nil
  end
  if type(opts.args) == 'string' and opts.args ~= '' then
    return opts.args
  end
  if type(opts.fargs) == 'table' and #opts.fargs > 0 then
    return opts.fargs[1]
  end
  return nil
end

M.get_args = M.get_arg

---@param prompt string
---@param completion? string
---@return string?
function M.input_required(prompt, completion)
  local value = fn.input(prompt, '', completion)
  if value == '' then
    return nil
  end
  return value
end

---@param opts? table
---@param prompt string
---@param completion? string
---@return string?
function M.input_or_arg(opts, prompt, completion)
  return M.get_arg(opts) or M.input_required(prompt, completion)
end

---@return string
function M.current_file()
  return api.nvim_buf_get_name(0)
end

---@return boolean
function M.has_file()
  return M.current_file() ~= ''
end

---@return string
function M.root()
  local file = M.current_file()
  local start = file ~= '' and vim.fs.dirname(file) or (uv.cwd() or fn.getcwd())
  local found = vim.fs.find({ 'sfdx-project.json', '.git' }, {
    upward = true,
    path = start,
  })[1]
  return found and vim.fs.dirname(found) or start
end

---@return boolean
function M.in_sf_project()
  local file = M.current_file()
  local start = file ~= '' and vim.fs.dirname(file) or (uv.cwd() or fn.getcwd())
  return vim.fs.find('sfdx-project.json', {
    upward = true,
    path = start,
  })[1] ~= nil
end

---@return boolean
function M.ensure_sf()
  if fn.executable('sf') == 1 then
    return true
  end
  M.notify('Salesforce CLI executable `sf` was not found in PATH', vim.log.levels.ERROR)
  return false
end

---@return boolean
function M.ensure_project()
  if M.in_sf_project() then
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
  local result = vim.system({ 'sf', 'config', 'get', 'target-org', '--json' }, {
    text = true,
    cwd = M.root(),
  }):wait()
  if result.code == 0 then
    local ok, decoded = pcall(vim.json.decode, result.stdout or '')
    if ok and type(decoded) == 'table' and type(decoded.result) == 'table' then
      local row = decoded.result[1]
      if row and type(row.value) == 'string' and row.value ~= '' then
        return true
      end
    end
  end
  M.notify('No default Salesforce target org is configured', vim.log.levels.WARN)
  return false
end

---@return string
function M.get_visual_selection()
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]
  if start_line == 0 or end_line == 0 then
    return ''
  end
  local lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return ''
  end
  lines[#lines] = lines[#lines]:sub(1, end_col)
  lines[1] = lines[1]:sub(start_col)
  return table.concat(lines, '\n')
end

---@param command string|string[]
---@param height? integer
---@param opts? table
---@return integer?
function M.open_term_cmd(command, height, opts)
  opts = opts or {}
  local term_height = math.max(3, math.floor(tonumber(height) or 20))
  vim.cmd(('botright %dnew'):format(term_height))
  local bufnr = api.nvim_get_current_buf()
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  local argv = command
  if type(command) == 'string' then
    argv = { vim.o.shell, vim.o.shellcmdflag, command }
  end
  local job = fn.jobstart(argv, {
    term = true,
    cwd = opts.cwd or M.root(),
    env = opts.env,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          M.notify(('Salesforce command exited with status %d'):format(code), vim.log.levels.WARN)
        end)
      end
    end,
  })
  if job <= 0 then
    M.notify('Unable to start Salesforce terminal command', vim.log.levels.ERROR)
    return nil
  end
  vim.cmd('startinsert')
  return job
end

---@class SfCommandSpec
---@field name string
---@field fn function
---@field opts? table

---@param specs SfCommandSpec[]
function M.register_commands(specs)
  for _, spec in ipairs(specs) do
    assert(type(spec.name) == 'string' and spec.name ~= '', 'Salesforce command is missing a name')
    assert(type(spec.fn) == 'function', ('Invalid Salesforce command handler: %s'):format(spec.name))
    pcall(api.nvim_del_user_command, spec.name)
    api.nvim_create_user_command(spec.name, spec.fn, spec.opts or {})
  end
end

return M