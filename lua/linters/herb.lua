-- #################################################################       -- ~/.config/nvim/lua/linters/herb.lua
-- Native Herb HTML+ERB Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://herb-tools.dev/projects/linter
---@source https://github.com/marcoroth/herb/tree/main/javascript/packages/linter
--
-- Matches the attached v8r.lua Native Linter / LintContext interface.
-- Install: npm install --save-dev --save-exact @herb-tools/linter@0.10.4
-- Expose node_modules/.bin/herb-lint to the runner's PATH. No npx or downloads.
-- Register 'herb' for eruby / html.erb; add html only for intended templates.
-- Saved files only: use BufWritePost. The CLI has no stdin mode in 0.10.4.
-- Project .herb.yml, version gating, exclusions, custom rules and inline
-- suppressions remain authoritative. Custom JavaScript rules require trust.
-- No --fix, --force, --all-rules, --init or config-writing operations.
-- One worker, JSON stdout, no colors/GitHub annotations/timing; 60s timeout.
-- The native runner must report spawn/timeout failures and discard stale jobs.
--
-- Herb positions use one-based lines and zero-based columns. Its parser and
-- JS-generated diagnostics do not consistently use one Unicode column unit.
-- ASCII lines get exact byte ranges; non-ASCII lines retain reported positions
-- in user_data with column zero, without guessed byte ranges.
-- EOF locations are clamped; malformed locations become file-level findings.
-- Some excluded files produce no JSON: a status diagnostic explains this.
-- See herb-setup.md for installation, registration and validation details.
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv
local json = vim.json
local SOURCE = 'herb'
local MAX_DIAGNOSTICS = 512
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_RESULTS = 10000
local MAX_LINE_BYTES = 1024 * 1024
local CONFIG_MARKERS = { '.herb.yml' }
-- Match @herb-tools/config's project indicators, including literal *.gemspec.
local ROOT_MARKERS = {
  '.herb.yml',
  '.git',
  '.herb',
  'Gemfile',
  'package.json',
  'Rakefile',
  'README.md',
  '*.gemspec',
  'config/application.rb',
}
local SEVERITIES = {
  error = diagnostic.severity.ERROR,
  warning = diagnostic.severity.WARN,
  info = diagnostic.severity.INFO,
  hint = diagnostic.severity.HINT,
}
---@param value any
---@return string?
local function string_value(value)
  if type(value) == 'string' and value ~= '' then
    return value
  end

  return nil
end

---@param path string
---@param cwd string
---@return string
local function absolute_path(path, cwd)
  if path:sub(1, 1) ~= '/' then
    path = fs.joinpath(cwd, path)
  end

  return fs.normalize(path)
end

---@param path string
---@param cwd string
---@return string
local function canonical_path(path, cwd)
  local absolute = absolute_path(path, cwd)

  return uv.fs_realpath(absolute) or absolute
end

---@param value string
---@return string
local function clean_message(value)
  local text = vim.trim(value:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '))

  if #text > MAX_MESSAGE_BYTES then
    local finish = MAX_MESSAGE_BYTES - 3

    -- Do not split a UTF-8 codepoint when truncating.
    while finish > 0 do
      local byte = text:byte(finish + 1)

      if byte == nil or byte < 128 or byte >= 192 then
        break
      end

      finish = finish - 1
    end

    text = text:sub(1, finish) .. '...'
  end

  return text
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status_diagnostic(context, code, message)
  return {
    bufnr = context.bufnr,
    code = code,
    col = 0,
    lnum = 0,
    message = message,
    severity = diagnostic.severity.WARN,
    source = SOURCE,
  }
end

---@param path string
---@param cwd string
---@return string
local function relative_path(path, cwd)
  local target_parts = vim.split(absolute_path(path, cwd), '/', { trimempty = true })
  local root_parts = vim.split(fs.normalize(cwd), '/', { trimempty = true })
  local common = 0

  for index = 1, math.min(#target_parts, #root_parts) do
    if target_parts[index] ~= root_parts[index] then
      break
    end
    common = index
  end

  ---@type string[]
  local parts = {}
  while #parts < #root_parts - common do
    parts[#parts + 1] = '..'
  end
  for index = common + 1, #target_parts do
    parts[#parts + 1] = target_parts[index]
  end
  return table.concat(parts, '/')
end

---@param context LintContext
---@return string
local function project_root(context)
  local cwd = fs.normalize(string_value(context.cwd) or vim.fn.getcwd())
  local filename = string_value(context.filename)
  if filename then
    filename = absolute_path(filename, cwd)
    -- Herb searches all ancestors for .herb.yml before using another marker.
    return fs.root(filename, CONFIG_MARKERS) or fs.root(filename, ROOT_MARKERS) or cwd
  end
  return cwd
end

local function integer(value)
  return type(value) == 'number'
    and value >= 0
    and value < 2147483647
    and value == math.floor(value)
end

local function position(value, context)
  if
    type(value) ~= 'table'
    or not integer(value.line)
    or value.line < 1
    or not integer(value.column)
  then
    return nil
  end
  local count = vim.api.nvim_buf_line_count(context.bufnr)
  if value.line > count then
    return count - 1, 0, false
  end
  local row = value.line - 1
  local line = vim.api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1] or ''
  if #line > MAX_LINE_BYTES or line:find('[\128-\255]') then
    return row, 0, false
  end
  if value.column > #line then
    return row, #line, false
  end
  return row, value.column, true
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table' and type(context.bufnr) == 'number', 'herb requires LintContext')
  if context.modified then
    return {
      status_diagnostic(context, 'save-required', 'Save this buffer before running herb-lint.'),
    }
  end
  if not string_value(context.filename) then
    return {
      status_diagnostic(context, 'filename-required', 'herb-lint requires a named, saved file.'),
    }
  end
  if #output > MAX_OUTPUT_BYTES then
    return {
      status_diagnostic(context, 'output-limit', 'Herb JSON exceeded the 16 MiB parser limit.'),
    }
  end
  local ok, report = pcall(json.decode, output)
  if
    not ok
    or type(report) ~= 'table'
    or type(report.offenses) ~= 'table'
    or not vim.islist(report.offenses)
  then
    return {
      status_diagnostic(
        context,
        'invalid-report',
        'Herb returned no valid JSON report. Check exclusions, configuration, custom rules and executable compatibility.'
      ),
    }
  end
  local result = {}
  if report.completed ~= true then
    result[#result + 1] = status_diagnostic(
      context,
      'check-incomplete',
      clean_message(string_value(report.message) or 'Herb did not complete this check.')
    )
    return result
  end
  local root = project_root(context)
  local target = canonical_path(context.filename, string_value(context.cwd) or root)
  local malformed, foreign = false, false
  local limited = #report.offenses > MAX_RESULTS
  for index = 1, math.min(#report.offenses, MAX_RESULTS) do
    if #result >= MAX_DIAGNOSTICS then
      limited = true
      break
    end
    local issue = report.offenses[index]
    if
      type(issue) ~= 'table'
      or not string_value(issue.filename)
      or not string_value(issue.message)
    then
      malformed = true
    elseif canonical_path(issue.filename, root) ~= target then
      foreign = true
    else
      local location = type(issue.location) == 'table' and issue.location or {}
      local row, col, exact = position(location.start, context)
      local end_row, end_col, end_exact = position(location['end'], context)
      local level = SEVERITIES[issue.severity]
      if not level then
        malformed = true
      end
      local item = {
        bufnr = context.bufnr,
        lnum = row or 0,
        col = col or 0,
        source = SOURCE,
        severity = level or diagnostic.severity.WARN,
        code = string_value(issue.code) and clean_message(issue.code) or nil,
        message = clean_message(issue.message),
        user_data = {
          filename = clean_message(issue.filename),
          position_exact = exact == true,
        },
      }
      if type(location.start) == 'table' then
        item.user_data.reported_line = integer(location.start.line) and location.start.line or nil
        item.user_data.reported_column = integer(location.start.column) and location.start.column
          or nil
      end
      if type(location['end']) == 'table' then
        item.user_data.reported_end_line = integer(location['end'].line) and location['end'].line
          or nil
        item.user_data.reported_end_column = integer(location['end'].column)
            and location['end'].column
          or nil
      end
      if
        exact
        and end_exact
        and end_row
        and row
        and (end_row > row or (end_row == row and end_col >= col))
      then
        item.end_lnum, item.end_col = end_row, end_col
      end
      result[#result + 1] = item
    end
  end
  if
    type(report.summary) ~= 'table'
    or not integer(report.summary.filesChecked)
    or report.summary.filesChecked ~= 1
    or foreign
  then
    result[#result + 1] = status_diagnostic(
      context,
      'file-selection',
      'Herb did not report exactly this one file. Check ignore rules, project roots and filename patterns.'
    )
  end
  if malformed then
    result[#result + 1] = status_diagnostic(
      context,
      'malformed-result',
      'Some Herb results could not be interpreted completely.'
    )
  end
  if limited then
    result[#result + 1] = status_diagnostic(
      context,
      'result-limit',
      'Herb reached the editor parser limit; run the CLI for all results.'
    )
  end
  return result
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'herb arguments require LintContext')
  local filename = string_value(context.filename)
  assert(filename, 'herb requires a saved filename')
  local cwd = project_root(context)
  local path = relative_path(absolute_path(filename, string_value(context.cwd) or cwd), cwd)
  local backslash = string.char(92)
  -- tinyglobby treats positionals as patterns, even with shell-free argv.
  local pattern = path:gsub('[*?%[%]{}()!+@' .. backslash .. ']', function(character)
    return backslash .. character
  end)
  return {
    '--format',
    'json',
    '--no-color',
    '--no-github',
    '--no-timing',
    '--jobs',
    '1',
    './' .. pattern,
  }
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'herb-lint',
  cwd = project_root,
  exit_codes = { 0, 1 },
  ignore_exitcode = false,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'stdout',
  timeout = 60000,
}