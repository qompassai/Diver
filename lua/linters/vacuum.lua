-- #################################################################
-- ~/.config/nvim/lua/linters/vacuum.lua
-- Native vacuum OpenAPI / AsyncAPI Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/daveshanley/vacuum
---@source https://quobix.com/vacuum/commands/spectral-report/
---@source https://github.com/daveshanley/vacuum/blob/main/model/results.go
--
-- Requires vacuum on Neovim's PATH. Tested CLI: vacuum 0.30.3.
-- Register 'vacuum' for OpenAPI/AsyncAPI YAML and JSON buffers in your native
-- linter loader; do not apply it indiscriminately to unrelated YAML/JSON.
-- Uses the same Linter / LintContext interface as cfn-lint.lua.
--
-- Scans unsaved buffers via stdin. No temporary files, shell, or auto-fixing.
-- Uses spectral-report --stdout, not the human-readable lint table.
-- Remote/local references retain vacuum's default resolution behavior.
-- Base defaults to the current file's directory; referenced files are read
-- from disk, so unsaved changes in those other buffers are not included.
-- The runner must cancel obsolete jobs and reject results after buffer edits.
--
-- Vacuum's report coordinates come directly from YAML nodes: ONE-based lines
-- and Unicode columns, despite the Spectral report name. Zero means unknown.
-- Start columns are converted to Neovim UTF-8 byte offsets. End positions are
-- retained only in metadata: vacuum may report another node's start as the end,
-- so this adapter does not invent an inclusive/exclusive highlight range.
-- External-file findings with a distinct source are filtered out.
--
-- Reads vacuum.conf.yaml through vacuum's own configuration loader.
-- Optional overrides:
--   NVIM_VACUUM_RULESET=/path/to/spectral.yaml
--   NVIM_VACUUM_IGNORE_FILE=/path/to/ignore.yaml
--   NVIM_VACUUM_BASE=/path/to/specs       (or a base URL)
-- Configured base is overridden by this adapter; use NVIM_VACUUM_BASE when
-- reference resolution needs a different base. Ruleset paths are relative to
-- the selected working directory. Use trusted rulesets/custom functions.
-- Passive update checks are disabled. TLS verification stays at its default.
-- Parser bounds apply after process capture; the runner owns output buffering.
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv
local api = vim.api
local json = vim.json

local SOURCE = 'vacuum'
local MAX_DIAGNOSTICS = 512
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_LINE_BYTES = 64 * 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_PATH_PARTS = 128
local ROOT_MARKERS = { 'vacuum.conf.yaml', '.git' }
local SEVERITIES = {
  [0] = diagnostic.severity.ERROR,
  [1] = diagnostic.severity.WARN,
  [2] = diagnostic.severity.INFO,
  [3] = diagnostic.severity.HINT,
}

---@param value any
---@return string?
local function string_value(value)
  if type(value) == 'string' and value ~= '' then
    return value
  end

  return nil
end

---@param context LintContext
---@return string
local function project_root(context)
  local filename = string_value(context.filename)

  -- Prefer the nearest vacuum configuration, even inside a larger repository.
  if filename ~= nil then
    local configured = fs.root(filename, 'vacuum.conf.yaml')

    if configured ~= nil then
      return fs.normalize(configured)
    end
  end

  local root = string_value(context.root)

  if root ~= nil then
    return fs.normalize(root)
  end

  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)

    if detected ~= nil then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if parent ~= nil and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(string_value(context.cwd) or vim.fn.getcwd())
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

---@param bufnr integer
---@param lnum integer
---@param column integer
---@return integer
local function byte_column(bufnr, lnum, column)
  if column == 0 or not api.nvim_buf_is_loaded(bufnr) then
    return 0
  end

  if lnum >= api.nvim_buf_line_count(bufnr) then
    return 0
  end

  local line = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''

  if #line > MAX_LINE_BYTES then
    return 0
  end

  local offset = 1
  local characters = 0

  while offset <= #line and characters < column do
    offset = offset + 1

    -- Neovim represents decoded buffer text as UTF-8. Skip continuation bytes.
    while offset <= #line do
      local byte = line:byte(offset)

      if byte < 128 or byte >= 192 then
        break
      end

      offset = offset + 1
    end

    characters = characters + 1
  end

  return offset - 1
end

---@param value any
---@return integer
local function coordinate(value)
  if type(value) ~= 'number' or value ~= value or value < 1 or value > 2147483647 then
    return 0
  end
  return math.floor(value) - 1
end

---@param context LintContext
---@return string
local function reference_base(context)
  local override = string_value(vim.env.NVIM_VACUUM_BASE)
  if override ~= nil then
    return override
  end
  local filename = string_value(context.filename)
  if filename ~= nil then
    local full = absolute_path(filename, string_value(context.cwd) or project_root(context))
    local parent = fs.dirname(full)
    if parent ~= nil then
      return parent
    end
  end
  return project_root(context)
end

---@param value any
---@return string[]
local function report_path(value)
  ---@type string[]
  local parts = {}
  if type(value) ~= 'table' then
    return parts
  end
  for index = 1, math.min(#value, MAX_PATH_PARTS) do
    local part = value[index]
    if type(part) == 'string' or type(part) == 'number' then
      parts[#parts + 1] = clean_message(tostring(part))
    end
  end
  return parts
end

---@param source string?
---@param context LintContext
---@return boolean
local function current_source(source, context)
  if source == nil or source == 'stdin' or source == '<stdin>' then
    return true
  end
  local filename = string_value(context.filename)
  if filename == nil then
    return false
  end
  if source:sub(1, 7) == 'file://' then
    source = vim.uri_to_fname(source)
  elseif source:match('^%a[%w+.-]*://') ~= nil then
    return false
  end
  local cwd = project_root(context)
  return canonical_path(source, cwd) == canonical_path(filename, string_value(context.cwd) or cwd)
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'vacuum parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'vacuum parser requires context.bufnr')
  if #output > MAX_OUTPUT_BYTES then
    return { status_diagnostic(context, 'output-limit', 'vacuum exceeded the 16 MiB parser limit; results are incomplete.') }
  end
  local text = vim.trim(output)
  local ok, decoded = pcall(json.decode, text)
  if not ok or type(decoded) ~= 'table' or text:sub(1, 1) ~= '[' or not vim.islist(decoded) then
    return { status_diagnostic(context, 'invalid-report', 'vacuum returned no valid JSON report. Check document syntax, configuration, rulesets, reference resolution and the timeout.') }
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local malformed = false
  for index = 1, math.min(#decoded, MAX_DIAGNOSTICS) do
    local finding = decoded[index]
    if type(finding) ~= 'table' or string_value(finding.message) == nil then
      malformed = true
    elseif current_source(string_value(finding.source), context) then
      local range = type(finding.range) == 'table' and finding.range or {}
      local start = type(range.start) == 'table' and range.start or {}
      local finish = type(range['end']) == 'table' and range['end'] or {}
      local lnum = coordinate(start.line)
      local col = byte_column(context.bufnr, lnum, coordinate(start.character))
      local severity = SEVERITIES[finding.severity] or diagnostic.severity.WARN
      local code = string_value(finding.code)
      diagnostics[#diagnostics + 1] = {
        bufnr = context.bufnr,
        code = code and clean_message(code) or nil,
        col = col,
        lnum = lnum,
        message = clean_message(finding.message),
        severity = severity,
        source = SOURCE,
        user_data = {
          path = report_path(finding.path),
          report_source = string_value(finding.source),
          report_end_line = coordinate(finish.line),
          report_end_character = coordinate(finish.character),
        },
      }
    end
  end
  if malformed then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'malformed-result', 'Some vacuum findings could not be decoded; results are incomplete.')
  end
  if #decoded > MAX_DIAGNOSTICS then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'result-limit', 'Only the first 512 vacuum report entries were processed; run the CLI for the complete report.')
  end
  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'vacuum arguments require LintContext')
  ---@type string[]
  local args = {
    'spectral-report',
    '--stdin',
    '--stdout',
    '--no-pretty',
    '--no-style',
    '--no-update-check',
    '--base', reference_base(context),
  }
  local ruleset = string_value(vim.env.NVIM_VACUUM_RULESET)
  if ruleset ~= nil then
    args[#args + 1] = '--ruleset'
    args[#args + 1] = ruleset
  end
  local ignore = string_value(vim.env.NVIM_VACUUM_IGNORE_FILE)
  if ignore ~= nil then
    args[#args + 1] = '--ignore-file'
    args[#args + 1] = ignore
  end
  return args
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'vacuum',
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = true,
  stream = 'stdout',
  timeout = 60000,
}