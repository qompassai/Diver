-- #################################################################
-- ~/.config/nvim/lua/linters/betterleaks.lua
-- Native BetterLeaks Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/betterleaks/betterleaks
---@source https://github.com/betterleaks/betterleaks/blob/main/cmd/stdin.go
---@source https://github.com/betterleaks/betterleaks/blob/main/report/finding.go
--
-- Requires BetterLeaks with stdin --set-attr support on Neovim's PATH.
-- Uses the same Linter / LintContext interface as cfn-lint.lua.
-- Register 'betterleaks' with your native linter loader for desired filetypes.
--
-- Policy:
--   * scan current buffer contents through stdin, including unsaved edits;
--   * preserve the filename as a project-relative path attribute;
--   * use native JSON, full redaction, and no live credential validation;
--   * never copy Secret, Match, context, or arbitrary attributes into diagnostics;
--   * use bounded parsing, deterministic traversal, and no shell interpolation;
--   * retain BetterLeaks configuration/environment precedence;
--   * disable archive/encoding expansion to keep editor locations meaningful.
--
-- Stdin has no Git history. Path-dependent filters use --set-attr path=... .
-- Unnamed buffers have no path attribute. Git-specific filters/baselines are
-- not equivalent to a repository scan. This module does not scan other files.
-- Output limits apply at parsing time; the runner owns process-output buffering,
-- cancellation, and rejecting stale results after the buffer changes.
-- Raw operational output is deliberately not echoed: it may contain source text.
local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local SOURCE = 'betterleaks'
local MAX_DIAGNOSTICS = 512
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_RULE_BYTES = 256
local MAX_POSITION = 2147483647

local ROOT_MARKERS = {
  { '.betterleaks.toml', '.gitleaks.toml' },
  '.git',
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
  local root = string_value(context.root)

  if root ~= nil then
    return fs.normalize(root)
  end

  local filename = string_value(context.filename)

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

---@param context LintContext
---@return string?
local function source_path(context)
  local filename = string_value(context.filename)

  if filename == nil then
    return nil
  end

  local path = fs.normalize(filename)
  local root = project_root(context)
  local prefix = root == '/' and '/' or root .. '/'

  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end

  return path
end

---@param value any
---@return integer?
local function positive_integer(value)
  if type(value) ~= 'number' or value ~= value or value < 1 or value > MAX_POSITION then
    return nil
  end

  if value ~= math.floor(value) then
    return nil
  end

  return math.floor(value)
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

---@class BetterleaksFinding
---@field RuleID? string
---@field StartLine? integer
---@field EndLine? integer
---@field StartColumn? integer
---@field EndColumn? integer

---@param finding BetterleaksFinding
---@param context LintContext
---@return vim.Diagnostic?
local function finding_diagnostic(finding, context)
  local rule = string_value(finding.RuleID)
  local start_line = positive_integer(finding.StartLine)

  if rule == nil or start_line == nil then
    return nil
  end

  -- Accept rule identifiers only; do not display free-form report descriptions.
  if #rule > MAX_RULE_BYTES or rule:find('[^%w_.%-]') ~= nil then
    rule = 'secret-detected'
  end

  local end_line = positive_integer(finding.EndLine) or start_line
  local col = (positive_integer(finding.StartColumn) or 1) - 1
  local end_col = positive_integer(finding.EndColumn) or col

  -- BetterLeaks uses one-based inclusive ends; Neovim uses exclusive byte ends.
  if end_line < start_line or (end_line == start_line and end_col < col) then
    end_line = start_line
    end_col = col
  end

  return {
    bufnr = context.bufnr,
    code = rule,
    col = col,
    end_col = end_col,
    end_lnum = end_line - 1,
    lnum = start_line - 1,
    message = 'Potential secret detected (' .. rule .. '). Remove it from source; rotate it if exposed.',
    severity = diagnostic.severity.WARN,
    source = SOURCE,
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'betterleaks parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'betterleaks parser requires context.bufnr')

  if #output > MAX_OUTPUT_BYTES then
    return { status_diagnostic(context, 'output-limit', 'BetterLeaks output exceeded the 16 MiB parser limit; scan results are incomplete.') }
  end

  local text = vim.trim(output)

  if text == '' then
    return { status_diagnostic(context, 'missing-report', 'BetterLeaks returned no JSON report. Check the executable, configuration, and timeout.') }
  end

  -- Go encodes a nil findings slice as null; an empty slice becomes [].
  if text == 'null' then
    return {}
  end

  local ok, decoded = pcall(json.decode, text)

  if not ok or type(decoded) ~= 'table' or text:sub(1, 1) ~= '[' then
    return { status_diagnostic(context, 'invalid-report', 'BetterLeaks did not return a clean JSON findings array. Check configuration and CLI compatibility; raw output is withheld.') }
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local malformed = false
  local count = math.min(#decoded, MAX_DIAGNOSTICS)

  for index = 1, count do
    local finding = decoded[index]
    local item

    if type(finding) == 'table' then
      item = finding_diagnostic(finding, context)
    end

    if item ~= nil then
      diagnostics[#diagnostics + 1] = item
    else
      malformed = true
    end
  end

  if malformed then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'invalid-finding', 'BetterLeaks returned findings with invalid rule IDs or locations; some results could not be displayed.')
  end

  if #decoded > MAX_DIAGNOSTICS then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'diagnostic-limit', 'Only the first 512 BetterLeaks findings were processed; run a separate scan for the complete report.')
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'betterleaks arguments require LintContext')

  ---@type string[]
  local args = {
    'stdin',
    '--report-format', 'json',
    '--report-path', '-',
    '--redact=100',
    '--validation=false',
    '--no-banner',
    '--no-color',
    '--log-level', 'error',
    '--exit-code', '0',
    '--max-archive-depth', '0',
    '--max-decode-depth', '0',
    '--timeout', '30',
  }

  local path = source_path(context)

  if path ~= nil then
    args[#args + 1] = '--set-attr'
    args[#args + 1] = 'path=' .. path
  end

  return args
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'betterleaks',
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = true,
  stream = 'both',
  timeout = 35000,
}