-- /qompassai/Diver/lua/config/core/lint.lua
-- Qompass AI Diver Core Linter Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- -------------------------------------------------------------------------
local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn
local uv = vim.uv
local M = {}
---@class CoreLintOptions
---@field bufnr? integer
---@field name? string
---@field names? string[]
---@field notify? boolean

---@class CoreLinterRegistry
---@field definitions? table<string, Linter>
---@field linters_by_ft? table<string, string[]>

---@type CoreLinterRegistry
local linters_root = require('linters')

---@type table<string, string[]>
local linters_by_ft = linters_root.linters_by_ft or {}

---@type table<string, Linter|false>
local linter_specs = {}

---@type table<integer, table<string, vim.SystemObj>>
local running_procs_by_buf = {}

---@type table<string, integer>
local namespaces = setmetatable({}, {
  ---@param tbl table<string, integer>
  ---@param name string
  ---@return integer
  __index = function(tbl, name)
    local namespace = api.nvim_create_namespace('linter.' .. name)
    rawset(tbl, name, namespace)
    return namespace
  end,
})

---@type table<string, integer>
local generations = {}

---@type table<integer, uv.uv_timer_t>
local timers = {}

local default_exit_codes = {
  [0] = true,
  [1] = true,
}

local default_root_markers = {
  '.git',
  '.hg',
  '.svn',
}

local severity_by_letter = {
  E = diagnostic.severity.ERROR,
  I = diagnostic.severity.INFO,
  N = diagnostic.severity.HINT,
  S = diagnostic.severity.HINT,
  W = diagnostic.severity.WARN,
}

local abbreviations = {
  Imprve = 'Improve',
  Imrpve = 'Improve',
  Imrpvoe = 'Improve',
  Ipmrove = 'Improve',
  Onix = 'Onyx',
  Onyix = 'Onyx',
  Onxy = 'Onyx',
  Onxyx = 'Onyx',
  acitns = 'actions',
  aciton = 'action',
  acitons = 'actions',
  actin = 'action',
  actoin = 'action',
  actoins = 'actions',
  acton = 'action',
  ation = 'action',
  cosnt = 'const',
  funcition = 'function',
  funciton = 'function',
  fucntion = 'function',
  fucntoin = 'function',
  functoin = 'function',
  funtion = 'function',
  imoprt = 'import',
  imprt = 'import',
  imprve = 'improve',
  imrpve = 'improve',
  imrpvoe = 'improve',
  ipmrove = 'improve',
  onix = 'onyx',
  onyix = 'onyx',
  onxy = 'onyx',
  onxyx = 'onyx',
  reoprt = 'report',
  reoprtAction = 'reportAction',
  reoprtActionID = 'reportActionID',
  reoprtID = 'reportID',
  reort = 'report',
  reortID = 'reportID',
  reorts = 'reports',
  repot = 'report',
  repotAction = 'reportAction',
  repotActionID = 'reportActionID',
  repotID = 'reportID',
  repots = 'reports',
  reponse = 'response',
  reponses = 'responses',
  reprt = 'report',
  reprtAction = 'reportAction',
  reprtActionID = 'reportActionID',
  reprtID = 'reportID',
  reprotAction = 'reportAction',
  reprotActionID = 'reportActionID',
  resonse = 'response',
  resopnse = 'response',
  respnse = 'response',
  respnses = 'responses',
  respone = 'response',
  resposne = 'response',
  resposnes = 'responses',
  rport = 'report',
  rportID = 'reportID',
  rports = 'reports',
  transaciton = 'transaction',
  transacitonID = 'transactionID',
  transacitons = 'transactions',
  transactoin = 'transaction',
  transactoinID = 'transactionID',
  transactoins = 'transactions',
  transacton = 'transaction',
  transactonID = 'transactionID',
  transactons = 'transactions',
  transation = 'transaction',
  transationID = 'transactionID',
  transations = 'transactions',
  transction = 'transaction',
  transctionID = 'transactionID',
  transctions = 'transactions',
  trasaction = 'transaction',
  trasactionID = 'transactionID',
  trasnsaction = 'transaction',
  trasnsactionID = 'transactionID',
  udpate = 'update',
}

for lhs, rhs in pairs(abbreviations) do
  vim.cmd(('iabbrev %s %s'):format(lhs, rhs))
end

---@param bufnr? integer
---@return integer
local function resolve_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return api.nvim_get_current_buf()
  end
  return bufnr
end

---@param value unknown
---@return integer?
local function integer(value)
  local converted = tonumber(value)
  if converted == nil then
    return nil
  end
  return math.floor(converted)
end

---@param value string
---@return string
local function strip_ansi(value)
  return value:gsub('\27%[[%d;?]*[ -/]*[@-~]', '')
end

---@param name string
---@return integer
function M.get_namespace(name)
  return namespaces[name]
end

---@param bufnr? integer
---@return string[]
function M.get_running(bufnr)
  local names = {}

  if bufnr ~= nil then
    local resolved = resolve_bufnr(bufnr)
    for name in pairs(running_procs_by_buf[resolved] or {}) do
      names[#names + 1] = name
    end
  else
    local seen = {}
    for _, processes in pairs(running_procs_by_buf) do
      for name in pairs(processes) do
        if not seen[name] then
          seen[name] = true
          names[#names + 1] = name
        end
      end
    end
  end

  table.sort(names)
  return names
end

---@param name string
---@return Linter?
local function get_linter_spec(name)
  local cached = linter_specs[name]
  if cached == false then
    return nil
  end
  if type(cached) == 'table' then
    return cached
  end

  local registered = linters_root.definitions and linters_root.definitions[name]
  if type(registered) == 'table' then
    linter_specs[name] = registered
    return registered
  end

  local ok, loaded = pcall(require, 'linters.' .. name)
  if not ok then
    linter_specs[name] = false
    vim.notify(('lint: failed to load linter %q: %s'):format(name, tostring(loaded)), vim.log.levels.ERROR)
    return nil
  end

  if type(loaded) ~= 'table' then
    linter_specs[name] = false
    vim.notify(('lint: linter %q returned %s instead of a table'):format(name, type(loaded)), vim.log.levels.ERROR)
    return nil
  end

  ---@cast loaded Linter
  linter_specs[name] = loaded
  return loaded
end

---@param bufnr integer
---@param spec Linter
---@return LintContext
local function context_for(bufnr, spec)
  bufnr = resolve_bufnr(bufnr)

  local raw_filename = api.nvim_buf_get_name(bufnr)
  local normalized = vim.fs.normalize(raw_filename)
  ---@type string
  local filename = raw_filename
  if type(normalized) == 'string' then
    filename = normalized
  end

  local current_directory = uv.cwd()
  ---@type string
  local fallback_cwd = '.'
  if type(current_directory) == 'string' and current_directory ~= '' then
    fallback_cwd = current_directory
  end

  ---@type string[]
  local markers = spec.root_markers or default_root_markers
  local detected_root = vim.fs.root(bufnr, markers)
  local parent = vim.fs.dirname(filename)
  ---@type string
  local root = fallback_cwd
  if type(detected_root) == 'string' and detected_root ~= '' then
    root = detected_root
  elseif type(parent) == 'string' and parent ~= '' then
    root = parent
  end

  return {
    bufnr = bufnr,
    cwd = root,
    filename = filename,
    filetype = tostring(vim.bo[bufnr].filetype or ''),
    modified = vim.bo[bufnr].modified == true,
    root = root,
  }
end

---@param bufnr integer
---@return boolean
local function buffer_is_eligible(bufnr)
  return api.nvim_buf_is_valid(bufnr)
    and api.nvim_buf_is_loaded(bufnr)
    and vim.bo[bufnr].buftype == ''
    and vim.bo[bufnr].filetype ~= ''
    and api.nvim_buf_get_name(bufnr) ~= ''
    and not vim.b[bufnr].lint_disabled
end

---@param candidates string|string[]
---@return string?
local function executable(candidates)
  if type(candidates) == 'string' then
    return fn.executable(candidates) == 1 and candidates or nil
  end

  for _, candidate in ipairs(candidates) do
    if type(candidate) == 'string' and fn.executable(candidate) == 1 then
      return candidate
    end
  end

  return nil
end

---@param executable_name string
---@param spec Linter
---@param context LintContext
---@return boolean
---@return string[]|string
local function command_for(executable_name, spec, context)
  local command = { executable_name }
  local configured_args = spec.args

  if type(configured_args) == 'function' then
    local ok, resolved = pcall(function()
      return configured_args(context)
    end)
    if not ok then
      return false, tostring(resolved)
    end
    if type(resolved) ~= 'table' then
      return false, ('args callback returned %s instead of a table'):format(type(resolved))
    end
    for _, argument in ipairs(resolved) do
      command[#command + 1] = argument
    end
  elseif type(configured_args) == 'table' then
    for _, argument in ipairs(configured_args) do
      command[#command + 1] = argument
    end
  end

  if spec.append_fname ~= false then
    command[#command + 1] = context.filename
  end

  for index, argument in ipairs(command) do
    if type(argument) ~= 'string' then
      return false, ('argument %d has type %s instead of string'):format(index, type(argument))
    end
  end

  return true, command
end

---@param spec Linter
---@param context LintContext
---@return boolean
---@return string
local function cwd_for(spec, context)
  local configured_cwd = spec.cwd

  if type(configured_cwd) == 'function' then
    local ok, resolved = pcall(function()
      return configured_cwd(context)
    end)
    if not ok then
      return false, tostring(resolved)
    end
    if type(resolved) ~= 'string' or resolved == '' then
      return false, ('cwd callback returned %s instead of a non-empty string'):format(type(resolved))
    end
    return true, resolved
  end

  if type(configured_cwd) == 'string' and configured_cwd ~= '' then
    return true, configured_cwd
  end

  return true, context.cwd
end

---@param bufnr integer
---@return string
local function buffer_input(bufnr)
  local input = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  if vim.bo[bufnr].endofline then
    return input .. '\n'
  end
  return input
end

---@param result vim.SystemCompleted
---@param stream? LintStream
---@return string
local function result_output(result, stream)
  if stream == 'stderr' then
    return result.stderr or ''
  end

  if stream == 'both' then
    local stdout = result.stdout or ''
    local stderr = result.stderr or ''
    if stdout == '' then
      return stderr
    end
    if stderr == '' then
      return stdout
    end
    return stdout .. '\n' .. stderr
  end

  return result.stdout or ''
end

---@param errorformat string|string[]
---@return fun(output: string, context: LintContext|integer): vim.Diagnostic.Set[]
local function errorformat_parser(errorformat)
  local format = type(errorformat) == 'table' and table.concat(errorformat, ',') or errorformat

  return function(output, _)
    local parsed = fn.getqflist({
      efm = format,
      lines = vim.split(strip_ansi(output), '\n', {
        plain = true,
        trimempty = true,
      }),
    })
    local diagnostics = {}

    for _, item in ipairs(parsed.items or {}) do
      if item.valid == 1 then
        local item_type = type(item.type) == 'string' and item.type:upper() or 'E'
        local end_line = integer(item.end_lnum)
        local end_column = integer(item.end_col)
        local number = integer(item.nr)

        diagnostics[#diagnostics + 1] = {
          lnum = math.max((integer(item.lnum) or 1) - 1, 0),
          col = math.max((integer(item.col) or 1) - 1, 0),
          end_lnum = end_line and end_line > 0 and end_line - 1 or nil,
          end_col = end_column and end_column > 0 and end_column - 1 or nil,
          message = item.text ~= '' and item.text or 'Unknown linter diagnostic',
          severity = severity_by_letter[item_type:sub(1, 1)] or diagnostic.severity.ERROR,
          code = number and number > 0 and number or nil,
        }
      end
    end

    return diagnostics
  end
end

---@param parser function
---@param output string
---@param context LintContext
---@return boolean
---@return vim.Diagnostic.Set[]|string
local function invoke_parser(parser, output, context)
  local context_ok, context_result = pcall(parser, output, context)
  if context_ok and type(context_result) == 'table' then
    return true, context_result
  end

  local bufnr_ok, bufnr_result = pcall(parser, output, context.bufnr)
  if bufnr_ok and type(bufnr_result) == 'table' then
    return true, bufnr_result
  end

  local context_error = context_ok and ('returned ' .. type(context_result)) or tostring(context_result)
  local bufnr_error = bufnr_ok and ('returned ' .. type(bufnr_result)) or tostring(bufnr_result)
  return false, ('context parser: %s; buffer parser: %s'):format(context_error, bufnr_error)
end

---@param spec Linter
---@param code integer
---@return boolean
local function accepts_exit_code(spec, code)
  if spec.ignore_exitcode then
    return true
  end

  local accepted_codes = spec.exit_codes or default_exit_codes
  if accepted_codes[code] == true then
    return true
  end

  for _, accepted in ipairs(accepted_codes) do
    if accepted == code then
      return true
    end
  end

  return false
end

---@param name string
---@param bufnr integer
---@param diagnostics vim.Diagnostic.Set[]
local function publish(name, bufnr, diagnostics)
  local line_count = math.max(api.nvim_buf_line_count(bufnr), 1)

  for _, item in ipairs(diagnostics) do
    local start_line = math.min(math.max(integer(item.lnum) or 0, 0), line_count - 1)
    local start_column = math.max(integer(item.col) or 0, 0)
    item.lnum = start_line
    item.col = start_column

    if item.end_lnum ~= nil then
      local end_line = integer(item.end_lnum) or start_line
      item.end_lnum = math.min(math.max(end_line, start_line), line_count - 1)
    end

    if item.end_col ~= nil then
      local end_column = integer(item.end_col) or start_column
      item.end_col = math.max(end_column, start_column)
    end

    item.message = tostring(item.message or 'Unknown linter diagnostic')
    item.severity = item.severity or diagnostic.severity.ERROR
    item.source = name
  end

  diagnostic.set(M.get_namespace(name), bufnr, diagnostics)
end

---@param name string
---@param bufnr? integer
---@param opts? CoreLintOptions
---@return boolean
local function run_linter(name, bufnr, opts)
  opts = opts or {}
  bufnr = resolve_bufnr(bufnr)

  if not buffer_is_eligible(bufnr) then
    return false
  end

  local spec = get_linter_spec(name)
  if spec == nil then
    diagnostic.reset(M.get_namespace(name), bufnr)
    return false
  end

  local executable_name = executable(spec.cmd)
  if executable_name == nil then
    diagnostic.reset(M.get_namespace(name), bufnr)
    if opts.notify then
      ---@type string
      local requested
      if type(spec.cmd) == 'table' then
        requested = table.concat(spec.cmd, ', ')
      else
        requested = spec.cmd
      end
      vim.notify(('lint: executable not found for %s: %s'):format(name, requested), vim.log.levels.WARN)
    end
    return false
  end

  local context = context_for(bufnr, spec)
  if context.modified and not spec.stdin then
    diagnostic.reset(M.get_namespace(name), bufnr)
    return false
  end

  local command_ok, command_or_error = command_for(executable_name, spec, context)
  if not command_ok then
    diagnostic.reset(M.get_namespace(name), bufnr)
    vim.notify(('lint: %s args failed: %s'):format(name, command_or_error), vim.log.levels.ERROR)
    return false
  end
  ---@cast command_or_error string[]
  local command = command_or_error

  local cwd_ok, cwd_or_error = cwd_for(spec, context)
  if not cwd_ok then
    diagnostic.reset(M.get_namespace(name), bufnr)
    vim.notify(('lint: %s cwd failed: %s'):format(name, cwd_or_error), vim.log.levels.ERROR)
    return false
  end
  local cwd = cwd_or_error

  local key = ('%d:%s'):format(bufnr, name)
  local processes = running_procs_by_buf[bufnr]
  if processes == nil then
    processes = {}
    running_procs_by_buf[bufnr] = processes
  end

  local previous = processes[name]
  if previous ~= nil then
    pcall(function()
      previous:kill(15)
    end)
    processes[name] = nil
  end

  local generation = (generations[key] or 0) + 1
  generations[key] = generation
  local changedtick = api.nvim_buf_get_changedtick(bufnr)

  diagnostic.reset(M.get_namespace(name), bufnr)

  local process
  process = vim.system(command, {
    cwd = cwd,
    env = vim.tbl_extend('keep', spec.env or {}, {
      NO_COLOR = '1',
    }),
    stdin = spec.stdin and buffer_input(bufnr) or nil,
    text = true,
    timeout = spec.timeout or 30000,
  }, function(result)
    vim.schedule(function()
      if generations[key] ~= generation then
        return
      end

      local active = running_procs_by_buf[bufnr]
      if active and active[name] == process then
        active[name] = nil
        if next(active) == nil then
          running_procs_by_buf[bufnr] = nil
        end
      end

      if not api.nvim_buf_is_valid(bufnr) then
        return
      end
      if api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
        return
      end

      local output = result_output(result, spec.stream)
      local parser = spec.parser
      if parser == nil and spec.errorformat ~= nil then
        parser = errorformat_parser(spec.errorformat)
      end

      if parser == nil then
        publish(name, bufnr, {})
        vim.notify(('lint: %s has no parser or errorformat'):format(name), vim.log.levels.ERROR)
        return
      end

      local parse_ok, parsed_or_error = invoke_parser(parser, output, context)
      if not parse_ok then
        publish(name, bufnr, {})
        vim.notify(('lint: %s parser failed: %s'):format(name, parsed_or_error), vim.log.levels.ERROR)
        return
      end

      ---@cast parsed_or_error vim.Diagnostic.Set[]
      local parsed = parsed_or_error
      publish(name, bufnr, parsed)

      if not accepts_exit_code(spec, result.code) and #parsed == 0 then
        local detail = vim.trim(strip_ansi(output))
        if #detail > 300 then
          detail = detail:sub(1, 300) .. '…'
        end
        vim.notify(
          ('lint: %s failed with exit code %d%s'):format(name, result.code, detail ~= '' and (': ' .. detail) or ''),
          vim.log.levels.ERROR
        )
      end
    end)
  end)

  processes[name] = process
  return true
end

M.run_linter = run_linter

---@param opts? integer|CoreLintOptions
function M.lint(opts)
  local options
  if type(opts) == 'table' then
    options = opts
  else
    options = {
      bufnr = opts,
    }
  end
  ---@cast options CoreLintOptions

  local bufnr = resolve_bufnr(options.bufnr)
  if not buffer_is_eligible(bufnr) then
    return
  end

  if type(options.name) == 'string' and options.name ~= '' then
    run_linter(options.name, bufnr, options)
    return
  end

  local selected = options.names or linters_by_ft[vim.bo[bufnr].filetype]
  if type(selected) ~= 'table' then
    return
  end

  for _, name in ipairs(selected) do
    run_linter(name, bufnr, options)
  end
end

---@param bufnr? integer
function M.stop(bufnr)
  bufnr = resolve_bufnr(bufnr)

  local timer = timers[bufnr]
  if timer ~= nil then
    timers[bufnr] = nil
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end

  local processes = running_procs_by_buf[bufnr]
  if processes == nil then
    return
  end

  for name, process in pairs(processes) do
    local key = ('%d:%s'):format(bufnr, name)
    generations[key] = (generations[key] or 0) + 1
    pcall(function()
      process:kill(15)
    end)
  end

  running_procs_by_buf[bufnr] = nil
end

---@param bufnr? integer
function M.reset(bufnr)
  bufnr = resolve_bufnr(bufnr)
  M.stop(bufnr)
  for _, namespace in pairs(namespaces) do
    diagnostic.reset(namespace, bufnr)
  end
end

---@param bufnr integer
local function schedule(bufnr)
  local existing = timers[bufnr]
  if existing ~= nil then
    timers[bufnr] = nil
    if not existing:is_closing() then
      existing:stop()
      existing:close()
    end
  end

  timers[bufnr] = vim.defer_fn(function()
    timers[bufnr] = nil
    M.lint({
      bufnr = bufnr,
    })
  end, 200)
end

local group = api.nvim_create_augroup('QompassLint', {
  clear = true,
})

api.nvim_create_autocmd('BufWritePost', {
  group = group,
  desc = 'Run native linters after writing a buffer',
  callback = function(event)
    M.lint({
      bufnr = event.buf,
    })
  end,
})

api.nvim_create_autocmd('InsertLeave', {
  group = group,
  desc = 'Debounce native linters after leaving Insert mode',
  callback = function(event)
    schedule(event.buf)
  end,
})

api.nvim_create_autocmd('BufWipeout', {
  group = group,
  desc = 'Stop native linters for deleted buffers',
  callback = function(event)
    M.stop(event.buf)
  end,
})

return M
