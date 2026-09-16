-- #################################################################
-- /qompassai/lua/linters/textlint.lua
-- Qompass AI Textlint
-- SPDX-License-Identifier: Apache-2.0
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://textlint.org/docs/cli/
---@source https://textlint.org/docs/formatter/
---@source https://textlint.org/docs/configuring/
--

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json
local uv = vim.uv

local SOURCE = 'textlint'
local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 4096
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local MAX_RESULTS = 1024
local MAX_MESSAGES = 8192

---@type string[]
local ROOT_MARKERS = {
  '.textlintrc',
  '.textlintrc.json',
  '.textlintrc.yaml',
  '.textlintrc.yml',
  '.textlintrc.js',
  '.textlintrc.cjs',
  'textlint.config.js',
  'textlint.config.cjs',
  'package.json',
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

---@param value string
---@return string
local function compact(value)
  return vim.trim(value:gsub('%s+', ' '))
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  if #value <= limit then
    return value
  end

  local finish = limit - 3

  while finish > 0 do
    local byte = value:byte(finish + 1)

    if byte == nil or byte < 128 or byte >= 192 then
      break
    end

    finish = finish - 1
  end

  return value:sub(1, finish) .. '...'
end

---@param value any
---@return integer
local function zero_based(value)
  local number = tonumber(value)

  if number == nil or number <= 1 then
    return 0
  end

  return math.floor(number) - 1
end

---@param path string
---@return boolean
local function is_absolute_path(path)
  if path:sub(1, 1) == '/' then
    return true
  end

  local separator = string.char(92)

  if path:sub(1, 2) == separator .. separator then
    return true
  end

  return path:match('^%a:[/\\]') ~= nil
end

---@param context LintContext
---@return string
local function project_root(context)
  local filename = string_value(context.filename)

  if filename ~= nil then
    local configured = fs.root(filename, ROOT_MARKERS)

    if type(configured) == 'string' and configured ~= '' then
      return fs.normalize(configured)
    end

    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  local root = string_value(context.root)

  if root ~= nil then
    return fs.normalize(root)
  end

  return fs.normalize(string_value(context.cwd) or vim.fn.getcwd())
end

---@param path string
---@param cwd string
---@return string
local function canonical_path(path, cwd)
  local absolute = path

  if not is_absolute_path(absolute) then
    absolute = fs.joinpath(cwd, absolute)
  end

  absolute = fs.normalize(absolute)

  return uv.fs_realpath(absolute) or absolute
end

---@param value any
---@return integer
local function severity(value)
  if value == 2 or value == 'error' then
    return diagnostic.severity.ERROR
  end

  if value == 3 or value == 'info' or value == 'information' then
    return diagnostic.severity.INFO
  end

  if value == 4 or value == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@param context LintContext
---@param code string
---@param message string
---@param level integer
---@return vim.Diagnostic
local function status_diagnostic(context, code, message, level)
  return {
    bufnr = context.bufnr,
    code = code,
    col = 0,
    end_col = 0,
    end_lnum = 0,
    lnum = 0,
    message = truncate(compact(message), MAX_MESSAGE_BYTES),
    severity = level,
    source = SOURCE,
  }
end

---@param message table
---@param context LintContext
---@return vim.Diagnostic
local function message_diagnostic(message, context)
  local lnum = zero_based(message.line)
  local col = zero_based(message.column)
  local end_lnum = message.endLine ~= nil and zero_based(message.endLine) or lnum
  local end_col = message.endColumn ~= nil and zero_based(message.endColumn) or col

  if end_lnum < lnum or (end_lnum == lnum and end_col < col) then
    end_lnum = lnum
    end_col = col
  end

  local text = string_value(message.message) or string_value(message.ruleId) or 'Textlint diagnostic'
  local code = string_value(message.ruleId) or string_value(message.ruleName)

  return {
    bufnr = context.bufnr,
    code = code,
    col = col,
    end_col = end_col,
    end_lnum = end_lnum,
    lnum = lnum,
    message = truncate(compact(text), MAX_MESSAGE_BYTES),
    severity = severity(message.severity),
    source = SOURCE,
    user_data = {
      rule = code,
      textlint_severity = message.severity,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'textlint parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'textlint parser requires context.bufnr')

  if context.modified then
    return {
      status_diagnostic(
        context,
        'save-required',
        'Save this buffer before running textlint; it reads files from disk.',
        diagnostic.severity.WARN
      ),
    }
  end

  local filename = string_value(context.filename)

  if filename == nil then
    return {
      status_diagnostic(
        context,
        'filename-required',
        'Save this buffer before running textlint.',
        diagnostic.severity.WARN
      ),
    }
  end

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return {
      status_diagnostic(
        context,
        'output-limit',
        'textlint output exceeded the 8 MiB parser limit; results are incomplete.',
        diagnostic.severity.WARN
      ),
    }
  end

  local ok, results = pcall(json.decode, output)

  if not ok or type(results) ~= 'table' or not vim.islist(results) then
    return {
      status_diagnostic(
        context,
        'invalid-report',
        'textlint returned invalid JSON. Check its configuration, rules and executable.',
        diagnostic.severity.ERROR
      ),
    }
  end

  local cwd = project_root(context)
  local target = canonical_path(filename, string_value(context.cwd) or cwd)
  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local matched = false
  local malformed = false
  local limited = #results > MAX_RESULTS
  local message_count = 0

  for result_index = 1, math.min(#results, MAX_RESULTS) do
    local result = results[result_index]

    if type(result) ~= 'table' then
      malformed = true
    else
      local file_path = string_value(result.filePath)

      if file_path == nil then
        malformed = true
      elseif canonical_path(file_path, cwd) == target then
        matched = true

        if type(result.messages) ~= 'table' or not vim.islist(result.messages) then
          malformed = true
        else
          for _, message in ipairs(result.messages) do
            message_count = message_count + 1

            if message_count > MAX_MESSAGES or #diagnostics >= MAX_DIAGNOSTICS then
              limited = true
              break
            end

            if type(message) == 'table' then
              diagnostics[#diagnostics + 1] = message_diagnostic(message, context)
            else
              malformed = true
            end
          end
        end
      end
    end

    if limited and (#diagnostics >= MAX_DIAGNOSTICS or message_count > MAX_MESSAGES) then
      break
    end
  end

  if not matched and #results > 0 then
    diagnostics[#diagnostics + 1] = status_diagnostic(
      context,
      'no-result',
      'textlint returned no result for this file. Check ignore rules and filename matching.',
      diagnostic.severity.WARN
    )
  end

  if malformed and #diagnostics < MAX_DIAGNOSTICS then
    diagnostics[#diagnostics + 1] = status_diagnostic(
      context,
      'malformed-result',
      'Some textlint report entries could not be decoded; results are incomplete.',
      diagnostic.severity.WARN
    )
  end

  if limited and #diagnostics < MAX_DIAGNOSTICS then
    diagnostics[#diagnostics + 1] = status_diagnostic(
      context,
      'result-limit',
      'textlint reached the editor result limit; run textlint directly for the complete report.',
      diagnostic.severity.WARN
    )
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'textlint arguments require LintContext')

  local filename = string_value(context.filename)
  assert(filename ~= nil, 'textlint requires a saved filename')

  return {
    '--format',
    'json',
    canonical_path(filename, string_value(context.cwd) or project_root(context)),
  }
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'textlint',
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'stdout',
  timeout = 30000,
}
