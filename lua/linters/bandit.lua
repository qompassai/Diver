-- #################################################################
-- /qompassai/Diver/lua/linters/bandit.lua
-- Native Bandit Python security linter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/PyCQA/bandit/tree/92ae8b82fb422a639f0ed8d99e96cea769594e08
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local TOOLING = {
  executable = 'bandit',
  timeout_ms = 30000,
}
local ROOT_MARKERS = {
  '.bandit',
  'bandit.yaml',
  'bandit.yml',
  'pyproject.toml',
  'setup.cfg',
  'tox.ini',
  'setup.py',
  'requirements.txt',
  '.git',
}
local LIMITS = {
  diagnostics = 4096,
  errors = 64,
  issues = 4029,
  message_bytes = 4096,
  output_bytes = 16 * 1024 * 1024,
  range_lines = 65536,
}
local SEVERITIES = {
  HIGH = diagnostic.severity.ERROR,
  LOW = diagnostic.severity.INFO,
  MEDIUM = diagnostic.severity.WARN,
  UNDEFINED = diagnostic.severity.HINT,
}
local CONFIDENCES = {
  HIGH = true,
  LOW = true,
  MEDIUM = true,
  UNDEFINED = true,
}
local DEFAULT_EXCLUDED_PATHS = {
  '.svn',
  'CVS',
  '.bzr',
  '.hg',
  '.git',
  '__pycache__',
  '.tox',
  '.eggs',
  '*.egg',
}

local ARGUMENTS = {
  '--format=json',
  '--aggregate=file',
  '--number=0',
  '--severity-level=all',
  '--confidence-level=all',
  '--quiet',
  '-',
}

local CLI_CHOICES = {
  aggregate = 'file',
  baseline = false,
  config_file = false,
  confidence_level = 'all',
  context_lines = 0,
  debug = false,
  excluded_paths = DEFAULT_EXCLUDED_PATHS,
  exit_zero = false,
  format = 'json',
  formatters = {
    csv = false,
    custom = false,
    html = false,
    json = true,
    sarif = false,
    screen = false,
    txt = false,
    xml = false,
    yaml = false,
  },
  help = false,
  ignore_nosec = false,
  ini_file = false,
  message_template = false,
  output = 'stdout',
  profile = false,
  quiet = true,
  recursive = false,
  severity_level = 'all',
  skips = {},
  targets = {
    '<stdin>',
  },
  tests = 'all',
  verbose = false,
  version = false,
}

---@class BanditCwe
---@field id integer
---@field link string

---@class BanditIssue
---@field code string
---@field col_offset integer
---@field end_col_offset integer
---@field filename string
---@field issue_confidence 'HIGH'|'LOW'|'MEDIUM'|'UNDEFINED'
---@field issue_cwe? BanditCwe
---@field issue_severity 'HIGH'|'LOW'|'MEDIUM'|'UNDEFINED'
---@field issue_text string
---@field line_number integer
---@field line_range integer[]
---@field more_info? string
---@field test_id string
---@field test_name string

---@class BanditError
---@field filename string
---@field reason string

---@class BanditReport
---@field errors BanditError[]
---@field results BanditIssue[]

---@class BanditDefinition:Linter
---@field cli_choices table<string, any>

---@type BanditDefinition
local M = {
  cli_choices = vim.deepcopy(CLI_CHOICES),
  cmd = TOOLING.executable,
}

local function validate_configuration()
  assert(TOOLING.executable == 'bandit')
  assert(TOOLING.timeout_ms >= 1000)
  assert(TOOLING.timeout_ms <= 300000)
  assert(LIMITS.errors + LIMITS.issues + 3 == LIMITS.diagnostics)
  assert(ARGUMENTS[#ARGUMENTS] == '-')

  local joined = table.concat(ARGUMENTS, '\0')

  assert(joined:find('%-%-format=json') ~= nil)
  assert(joined:find('%-%-severity%-level=all') ~= nil)
  assert(joined:find('%-%-confidence%-level=all') ~= nil)
  assert(joined:find('%-%-recursive') == nil)
  assert(joined:find('%-%-configfile') == nil)
  assert(joined:find('%-%-baseline') == nil)
  assert(joined:find('%-%-exit%-zero') == nil)
  assert(joined:find('%-%-ignore%-nosec') == nil)
end

validate_configuration()

---@param filename string
---@return string
local function root_for_path(filename)
  if filename == '' then
    return uv.cwd() or '.'
  end

  return fs.root(filename, ROOT_MARKERS) or fs.dirname(filename) or uv.cwd() or '.'
end

---@param context LintContext
---@return string
local function root(context)
  return root_for_path(context.filename)
end

---@param value string
---@return string
local function clean(value)
  local message = vim.trim(value:gsub('[%z\1-\31\127]', ' '))

  if #message <= LIMITS.message_bytes then
    return message
  end

  local last = LIMITS.message_bytes - 3

  while last > 0 do
    local byte = message:byte(last + 1)

    if byte == nil or byte < 128 or byte >= 192 then
      break
    end

    last = last - 1
  end

  return message:sub(1, last) .. '...'
end

---@param value any
---@param minimum integer
---@param maximum integer
---@return integer?
local function integer(value, minimum, maximum)
  if type(value) ~= 'number' or value ~= math.floor(value) then
    return nil
  end

  if value < minimum or value > maximum then
    return nil
  end

  ---@cast value integer
  return value
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status(context, code, message)
  return {
    bufnr = context.bufnr,
    lnum = 0,
    end_lnum = 0,
    col = 0,
    end_col = 0,
    severity = diagnostic.severity.ERROR,
    source = 'bandit',
    code = code,
    message = clean(message),
  }
end

---@param bufnr integer
---@param row integer
---@param column integer
---@return integer bounded_row
---@return integer bounded_column
---@return boolean malformed
local function position(bufnr, row, column)
  local line_count = api.nvim_buf_line_count(bufnr)
  local malformed = false

  if line_count < 1 then
    line_count = 1
  end

  if row >= line_count then
    row = line_count - 1
    malformed = true
  end

  local text = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

  if column > #text then
    column = #text
    malformed = true
  end

  while column > 0 do
    local byte = text:byte(column + 1)

    if byte == nil or byte < 128 or byte >= 192 then
      break
    end

    column = column - 1
    malformed = true
  end

  return row, column, malformed
end

---@param context LintContext
---@param path any
---@return boolean
local function is_target(context, path)
  assert(type(context.bufnr) == 'number')

  return path == '<stdin>' or path == '-'
end

---@param issue BanditIssue
---@return string
local function issue_message(issue)
  local confidence = issue.issue_confidence:lower()

  return clean(('%s (%s confidence)'):format(issue.issue_text, confidence))
end

---@param issue BanditIssue
---@return integer? end_line
---@return boolean malformed
local function issue_end_line(issue)
  if not vim.islist(issue.line_range) or #issue.line_range == 0 then
    return nil, true
  end

  if #issue.line_range > LIMITS.range_lines then
    return nil, true
  end

  local last_line = 0

  for index = 1, #issue.line_range do
    local line = integer(issue.line_range[index], 1, 2147483646)

    if line == nil or line < last_line then
      return nil, true
    end

    last_line = line
  end

  return last_line, false
end

---@param issue any
---@return boolean
local function has_issue_fields(issue)
  return type(issue) == 'table'
    and type(issue.filename) == 'string'
    and type(issue.issue_confidence) == 'string'
    and type(issue.issue_severity) == 'string'
    and type(issue.issue_text) == 'string'
    and issue.issue_text ~= ''
    and type(issue.test_id) == 'string'
    and issue.test_id ~= ''
    and type(issue.test_name) == 'string'
    and issue.test_name ~= ''
end

---@param context LintContext
---@param line integer
---@param end_line integer
---@param column integer
---@param end_column integer
---@return integer row
---@return integer bounded_column
---@return integer end_row
---@return integer bounded_end_column
---@return boolean malformed
local function issue_position(context, line, end_line, column, end_column)
  local row, bounded_column, start_malformed = position(context.bufnr, line - 1, column)
  local end_row, bounded_end_column, end_malformed = position(context.bufnr, end_line - 1, end_column)
  local malformed = start_malformed or end_malformed

  if end_row < row then
    end_row = row
    bounded_end_column = bounded_column
    malformed = true
  end

  if end_row == row and bounded_end_column <= bounded_column then
    local text = api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1] or ''

    bounded_end_column = bounded_column + 1

    if bounded_end_column > #text then
      bounded_end_column = #text
    end
  end

  return row, bounded_column, end_row, bounded_end_column, malformed
end

---@param context LintContext
---@param issue any
---@return vim.Diagnostic? item
---@return boolean malformed
---@return boolean foreign
local function parse_issue(context, issue)
  if not has_issue_fields(issue) then
    return nil, true, false
  end

  ---@cast issue BanditIssue
  if not is_target(context, issue.filename) then
    return nil, false, true
  end

  local severity = SEVERITIES[issue.issue_severity]
  local confidence = CONFIDENCES[issue.issue_confidence]
  local line = integer(issue.line_number, 1, 2147483646)
  local column = integer(issue.col_offset, -1, 2147483646)
  local final_column = integer(issue.end_col_offset, 0, 2147483646)
  local end_line, range_malformed = issue_end_line(issue)

  if severity == nil or confidence == nil or line == nil or end_line == nil then
    return nil, true, false
  end

  local malformed = range_malformed or column == nil or final_column == nil

  column = column or 0
  final_column = final_column or column

  if column < 0 then
    column = 0
    malformed = true
  end

  local row, start_column, end_row, bounded_end_column, position_malformed =
    issue_position(context, line, end_line, column, final_column)

  local item = status(context, clean(issue.test_id), issue_message(issue))

  malformed = malformed or position_malformed

  item.lnum = row
  item.end_lnum = end_row
  item.col = start_column
  item.end_col = bounded_end_column
  item.severity = severity
  item.user_data = {
    confidence = issue.issue_confidence,
    cwe = issue.issue_cwe,
    more_info = issue.more_info,
    test_name = clean(issue.test_name),
  }

  return item, malformed, false
end

---@param context LintContext
---@param record any
---@return vim.Diagnostic? item
---@return boolean malformed
---@return boolean foreign
local function parse_error(context, record)
  if
    type(record) ~= 'table'
    or type(record.filename) ~= 'string'
    or type(record.reason) ~= 'string'
    or record.reason == ''
  then
    return nil, true, false
  end

  if not is_target(context, record.filename) then
    return nil, false, true
  end

  return status(context, 'bandit-input', record.reason), false, false
end

---@param output string
---@param context LintContext
---@return BanditReport? report
---@return vim.Diagnostic? problem
local function decode_report(output, context)
  if #output > LIMITS.output_bytes then
    return nil, status(context, 'output-limit', 'Bandit output exceeded 16 MiB.')
  end

  if output == '' then
    return nil, status(context, 'empty-report', 'Bandit returned an empty report.')
  end

  local decoded, report = pcall(vim.json.decode, output)

  if not decoded or type(report) ~= 'table' or not vim.islist(report.errors) or not vim.islist(report.results) then
    return nil,
      status(context, 'invalid-report', 'Bandit returned no valid JSON report; run the CLI to inspect the failure.')
  end

  ---@cast report BanditReport
  return report, nil
end

---@param diagnostics vim.Diagnostic[]
---@param item vim.Diagnostic?
local function append(diagnostics, item)
  if item ~= nil and #diagnostics < LIMITS.diagnostics then
    diagnostics[#diagnostics + 1] = item
  end
end

---@param diagnostics vim.Diagnostic[]
---@param context LintContext
---@param malformed boolean
---@param foreign boolean
---@param limited boolean
local function append_statuses(diagnostics, context, malformed, foreign, limited)
  if foreign then
    append(diagnostics, status(context, 'other-file', 'Bandit returned another file.'))
  end

  if malformed then
    append(diagnostics, status(context, 'malformed-result', 'Some Bandit results were malformed.'))
  end

  if limited then
    append(diagnostics, status(context, 'result-limit', 'The result limit was reached; run Bandit directly.'))
  end
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  local report, problem = decode_report(output, context)

  if report == nil then
    assert(problem ~= nil)

    return {
      problem,
    }
  end

  local diagnostics = {}
  local malformed = false
  local foreign = false
  local error_count = #report.errors
  local issue_count = #report.results

  if error_count > LIMITS.errors then
    error_count = LIMITS.errors
  end

  if issue_count > LIMITS.issues then
    issue_count = LIMITS.issues
  end

  for index = 1, error_count do
    local item, bad, other = parse_error(context, report.errors[index])

    append(diagnostics, item)
    malformed = malformed or bad
    foreign = foreign or other
  end

  for index = 1, issue_count do
    local item, bad, other = parse_issue(context, report.results[index])

    append(diagnostics, item)
    malformed = malformed or bad
    foreign = foreign or other
  end

  local limited = #report.errors > LIMITS.errors or #report.results > LIMITS.issues

  append_statuses(diagnostics, context, malformed, foreign, limited)

  return diagnostics
end

M.args = vim.deepcopy(ARGUMENTS)
M.append_fname = false
M.automatic = true
M.cwd = root
M.env = {
  NO_COLOR = '1',
  PYTHONDONTWRITEBYTECODE = '1',
  PYTHONIOENCODING = 'utf-8',
  PYTHONUTF8 = '1',
}
M.exit_codes = {
  0,
  1,
}
M.ignore_exitcode = false
M.parser = parse
M.root_markers = ROOT_MARKERS
M.stdin = true
M.stream = 'stdout'
M.timeout = TOOLING.timeout_ms

return M
