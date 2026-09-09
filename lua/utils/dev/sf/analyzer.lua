-- /qompassai/Diver/lua/utils/dev/sf/analyzer.lua
-- Qompass AI Diver Salesforce Code Analyzer Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn
local uv = vim.uv
local core = require('utils.dev.sf.core')
local M = {}
local namespace = api.nvim_create_namespace('sf_code_analyzer')

---@param value any
---@return integer
local function severity_from(value)
  local numeric = tonumber(value)
  if numeric == 1 or numeric == 2 then
    return diagnostic.severity.ERROR
  elseif numeric == 3 then
    return diagnostic.severity.WARN
  elseif numeric == 4 then
    return diagnostic.severity.INFO
  elseif numeric == 5 then
    return diagnostic.severity.HINT
  end
  local label = tostring(value or ''):lower()
  if label == 'critical' or label == 'high' or label == 'error' then
    return diagnostic.severity.ERROR
  elseif label == 'moderate' or label == 'warning' or label == 'warn' then
    return diagnostic.severity.WARN
  elseif label == 'low' or label == 'info' then
    return diagnostic.severity.INFO
  end
  return diagnostic.severity.HINT
end

---@param path string
---@return boolean
local function is_absolute(path)
  return path:sub(1, 1) == '/' or path:match('^%a:[/\\]') ~= nil or path:sub(1, 2) == '\\\\'
end

---@param path any
---@param base? string
---@return string?
local function normalize_path(path, base)
  if type(path) ~= 'string' or path == '' then
    return nil
  end
  if base and not is_absolute(path) then
    path = vim.fs.joinpath(base, path)
  end
  return vim.fs.normalize(path)
end

---@param bufnr integer
---@return string?
local function current_buffer_path(bufnr)
  return normalize_path(api.nvim_buf_get_name(bufnr))
end

---@param path string
---@return string?
---@return string?
local function read_file(path)
  local file, open_error = io.open(path, 'rb')
  if not file then
    return nil, open_error
  end
  local content, read_error = file:read('*a')
  file:close()
  if type(content) ~= 'string' then
    return nil, read_error
  end
  return content
end

---@param violation table
---@return table
local function primary_location(violation)
  if type(violation.locations) == 'table' and #violation.locations > 0 then
    local primary = math.floor(tonumber(violation.primaryLocationIndex) or 0)
    return violation.locations[primary + 1] or violation.locations[primary] or violation.locations[1]
  end
  return violation
end

---@param value any
---@param fallback integer
---@return integer
local function position(value, fallback)
  local numeric = tonumber(value)
  if not numeric then
    return fallback
  end
  return math.max(math.floor(numeric), 1)
end

---@param violation table
---@param location table
---@return vim.Diagnostic.Set
local function violation_to_diagnostic(violation, location)
  local start_line = position(location.startLine, 1) - 1
  local start_column = position(location.startColumn, 1) - 1
  local end_line = math.max(position(location.endLine, start_line + 1) - 1, start_line)
  local end_column = math.max(position(location.endColumn, start_column + 1), start_column + 1)
  local rule = violation.rule or violation.ruleName or violation.engine or 'code-analyzer'
  local message = violation.message or violation.primaryMessage or 'Salesforce Code Analyzer violation'
  if type(location.comment) == 'string' and location.comment ~= '' then
    message = tostring(message) .. ' — ' .. location.comment
  end
  local resources = violation.resources
  if type(resources) == 'table' and type(resources[1]) == 'string' then
    message = tostring(message) .. ' [' .. resources[1] .. ']'
  elseif type(violation.help) == 'string' and violation.help ~= '' then
    message = tostring(message) .. ' [' .. violation.help .. ']'
  end
  return {
    lnum = start_line,
    col = start_column,
    end_lnum = end_line,
    end_col = end_column,
    severity = severity_from(violation.severity),
    source = 'sf-code-analyzer',
    code = tostring(rule),
    message = tostring(message),
    user_data = {
      engine = violation.engine,
      resources = violation.resources,
      tags = violation.tags,
    },
  }
end

---@param decoded table
---@param target string
---@return vim.Diagnostic.Set[]
local function collect_file_diagnostics(decoded, target)
  local diagnostics = {}
  local violations = type(decoded.violations) == 'table' and decoded.violations or {}
  local run_dir = normalize_path(decoded.runDir) or core.root()
  for _, violation in ipairs(violations) do
    if type(violation) == 'table' then
      local location = primary_location(violation)
      local location_path = location.file or location.fileName or location.filePath or location.path
      local path = normalize_path(location_path, run_dir)
      if path == nil or path == target then
        diagnostics[#diagnostics + 1] = violation_to_diagnostic(violation, location)
      end
    end
  end
  table.sort(diagnostics, function(left, right)
    if left.lnum == right.lnum then
      return left.col < right.col
    end
    return left.lnum < right.lnum
  end)
  return diagnostics
end

---@param result vim.SystemCompleted
---@return string
local function result_error(result)
  local message = result.stderr
  if type(message) ~= 'string' or message == '' then
    message = result.stdout
  end
  if type(message) ~= 'string' or message == '' then
    message = ('Salesforce Code Analyzer exited with status %d'):format(result.code)
  end
  return vim.trim(message)
end

---@param target string
---@param callback fun(decoded: table)
local function run_json_command(target, callback)
  local output_path = fn.tempname() .. '.json'
  local argv = {
    'sf',
    'code-analyzer',
    'run',
    '--workspace',
    target,
    '--output-file',
    output_path,
    '--view',
    'table',
  }
  vim.system(argv, {
    cwd = core.root(),
    text = true,
  }, function(result)
    local content, read_error = read_file(output_path)
    pcall(uv.fs_unlink, output_path)
    vim.schedule(function()
      if result.code ~= 0 then
        core.notify(result_error(result), vim.log.levels.ERROR)
        return
      end
      if not content then
        core.notify(read_error or 'Unable to read Code Analyzer output', vim.log.levels.ERROR)
        return
      end
      local ok, decoded = pcall(vim.json.decode, content)
      if not ok or type(decoded) ~= 'table' then
        core.notify('Failed to parse Code Analyzer JSON output', vim.log.levels.ERROR)
        return
      end
      callback(decoded)
    end)
  end)
end

---@param bufnr? integer|table
function M.clear_diagnostics(bufnr)
  if type(bufnr) ~= 'number' then
    bufnr = 0
  end
  diagnostic.reset(namespace, bufnr)
end

function M.config()
  if core.ensure() then
    core.open_term_cmd({ 'sf', 'code-analyzer', 'config' }, 20)
  end
end

---@param opts? SfCommandArgs
function M.config_generate(opts)
  if not core.ensure() then
    return
  end
  local output_path = core.get_arg(opts) or fn.input('Configuration output file> ', 'code-analyzer.yml', 'file')
  if type(output_path) ~= 'string' or output_path == '' then
    return
  end
  core.open_term_cmd({ 'sf', 'code-analyzer', 'config', '--output-file', output_path }, 20)
end

function M.rules()
  if core.ensure() then
    core.open_term_cmd({ 'sf', 'code-analyzer', 'rules' }, 20)
  end
end

---@param opts? SfCommandArgs
function M.run_file(opts)
  if not core.ensure() then
    return
  end
  local target = core.get_arg(opts) or current_buffer_path(api.nvim_get_current_buf())
  if type(target) ~= 'string' or target == '' then
    core.notify('No file target for Salesforce Code Analyzer', vim.log.levels.WARN)
    return
  end
  core.open_term_cmd({
    'sf',
    'code-analyzer',
    'run',
    '--workspace',
    target,
    '--view',
    'table',
  }, 20)
end

---@param opts? SfCommandArgs
function M.run_file_diagnostics(opts)
  if not core.ensure() then
    return
  end
  local bufnr = api.nvim_get_current_buf()
  local target = normalize_path(core.get_arg(opts)) or current_buffer_path(bufnr)
  if not target then
    core.notify('No file target for analyzer diagnostics', vim.log.levels.WARN)
    return
  end
  run_json_command(target, function(decoded)
    if not api.nvim_buf_is_valid(bufnr) then
      return
    end
    local diagnostics = collect_file_diagnostics(decoded, target)
    diagnostic.set(namespace, bufnr, diagnostics, {
      severity_sort = true,
      signs = true,
      underline = true,
      virtual_text = true,
    })
    core.notify(('Code Analyzer: %d diagnostic(s) loaded'):format(#diagnostics))
  end)
end

---@param opts? SfCommandArgs
function M.run_project(opts)
  if not core.ensure({ project = true }) then
    return
  end
  local target = core.get_arg(opts) or 'force-app'
  core.open_term_cmd({
    'sf',
    'code-analyzer',
    'run',
    '--workspace',
    target,
    '--view',
    'table',
  }, 20)
end

M.run_project_json = M.run_project

---@param opts? SfCommandArgs
function M.run_project_json_to_file(opts)
  if not core.ensure({ project = true }) then
    return
  end
  local target = core.get_arg(opts) or 'force-app'
  local output_path = fn.input('Output JSON file> ', 'sfca_results.json', 'file')
  if type(output_path) ~= 'string' or output_path == '' then
    return
  end
  core.open_term_cmd({
    'sf',
    'code-analyzer',
    'run',
    '--workspace',
    target,
    '--output-file',
    output_path,
    '--view',
    'table',
  }, 20)
end

---@param value string
---@return string?
local function severity_threshold(value)
  local normalized = value:lower()
  local thresholds = {
    critical = '1',
    high = '2',
    moderate = '3',
    low = '4',
    info = '5',
  }
  if thresholds[normalized] then
    return thresholds[normalized]
  end
  local numeric = tonumber(value)
  if numeric and numeric >= 1 and numeric <= 5 then
    return tostring(math.floor(numeric))
  end
  return nil
end

---@param opts? SfCommandArgs
function M.run_severity(opts)
  if not core.ensure({ project = true }) then
    return
  end
  local value = core.get_arg(opts) or fn.input('Severity threshold [1-5 or Critical-Info]> ')
  if type(value) ~= 'string' or value == '' then
    return
  end
  local threshold = severity_threshold(value)
  if not threshold then
    core.notify('Severity must be 1-5 or Critical, High, Moderate, Low, or Info', vim.log.levels.WARN)
    return
  end
  core.open_term_cmd({
    'sf',
    'code-analyzer',
    'run',
    '--workspace',
    'force-app',
    '--severity-threshold',
    threshold,
    '--view',
    'table',
  }, 20)
end

M.commands = {
  {
    name = 'SfAnalyzeConfig',
    fn = M.config,
    opts = {
      desc = 'Show Salesforce Code Analyzer configuration',
      nargs = 0,
    },
  },
  {
    name = 'SfAnalyzeConfigGenerate',
    fn = M.config_generate,
    opts = {
      complete = 'file',
      desc = 'Write Salesforce Code Analyzer configuration',
      nargs = '?',
    },
  },
  {
    name = 'SfAnalyzeDiagnostics',
    fn = M.run_file_diagnostics,
    opts = {
      complete = 'file',
      desc = 'Load Code Analyzer diagnostics for the current file',
      nargs = '?',
    },
  },
  {
    name = 'SfAnalyzeDiagnosticsClear',
    fn = M.clear_diagnostics,
    opts = { desc = 'Clear Salesforce Code Analyzer diagnostics', nargs = 0 },
  },
  {
    name = 'SfAnalyzeFile',
    fn = M.run_file,
    opts = {
      complete = 'file',
      desc = 'Analyze the current file',
      nargs = '?',
    },
  },
  {
    name = 'SfAnalyzeProject',
    fn = M.run_project,
    opts = {
      complete = 'dir',
      desc = 'Analyze the current Salesforce project',
      nargs = '?',
    },
  },
  {
    name = 'SfAnalyzeProjectJsonFile',
    fn = M.run_project_json_to_file,
    opts = {
      complete = 'dir',
      desc = 'Write Code Analyzer project output to JSON',
      nargs = '?',
    },
  },
  {
    name = 'SfAnalyzeRules',
    fn = M.rules,
    opts = {
      desc = 'List Salesforce Code Analyzer rules',
      nargs = 0,
    },
  },
  {
    name = 'SfAnalyzeSeverity',
    fn = M.run_severity,
    opts = {
      desc = 'Analyze a project using a severity threshold',
      nargs = '?',
    },
  },
}

return M