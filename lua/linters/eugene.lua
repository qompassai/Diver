-- #################################################################
-- ~/.config/nvim/lua/linters/eugene.lua
-- Qompass AI Diver Eugene Linter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
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
---@source https://github.com/kaaveland/eugene
---@source https://kaveland.no/eugene/lint.html

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 256
local MAX_MESSAGE_BYTES = 1024
local MAX_OUTPUT_BYTES = 4 * 1024 * 1024
local SOURCE = 'eugene'

---@type string[]
local ROOT_MARKERS = {
  'flyway.conf',
  'liquibase.properties',
  'sqitch.conf',
  '.git',
}

---@param value any
---@return string?
local function string_value(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return value
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

  return value:sub(1, limit - 3) .. '...'
end

---@param value any
---@return integer
local function zero_based_line(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local line = math.floor(number)

  if line <= 1 then
    return 0
  end

  return line - 1
end

---@param code string?
---@return integer
local function severity(code)
  if code == nil then
    return diagnostic.severity.WARN
  end

  local prefix = code:sub(1, 1):upper()

  if prefix == 'E' then
    return diagnostic.severity.ERROR
  end

  if prefix == 'W' then
    return diagnostic.severity.WARN
  end

  if prefix == 'I' then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.WARN
end

---@param context LintContext
---@return string
local function project_root(context)
  local context_root = string_value(context.root)

  if context_root ~= nil then
    return fs.normalize(context_root)
  end

  local filename = string_value(context.filename)

  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end
  end

  local cwd = string_value(context.cwd)

  if cwd ~= nil then
    return fs.normalize(cwd)
  end

  return fs.normalize(vim.fn.getcwd())
end

---@param text string
---@param needle string
---@return integer?
local function last_index(text, needle)
  local result
  local offset = 1

  while offset <= #text do
    local index = text:find(needle, offset, true)

    if index == nil then
      break
    end

    result = index
    offset = index + #needle
  end

  return result
end

---@param text string
---@param first string
---@param last string
---@return any?
local function decode_slice(text, first, last)
  local start_index = text:find(first, 1, true)

  if start_index == nil then
    return nil
  end

  local end_index = last_index(text, last)

  if end_index == nil or end_index < start_index then
    return nil
  end

  local candidate = text:sub(start_index, end_index)
  local ok, decoded = pcall(json.decode, candidate)

  if not ok then
    return nil
  end

  return decoded
end

---@param output string
---@return any?
local function decode_output(output)
  local text = vim.trim(output)

  if text == '' then
    return nil
  end

  local ok, decoded = pcall(json.decode, text)

  if ok then
    return decoded
  end

  decoded = decode_slice(text, '{', '}')

  if decoded ~= nil then
    return decoded
  end

  return decode_slice(text, '[', ']')
end

---@param value any
---@param reports table[]
---@param depth integer
local function collect_reports(value, reports, depth)
  if depth > 6 or type(value) ~= 'table' then
    return
  end

  if type(value.statements) == 'table' then
    reports[#reports + 1] = value

    return
  end

  for _, child in pairs(value) do
    if type(child) == 'table' then
      collect_reports(child, reports, depth + 1)
    end
  end
end

---@param rule table
---@return string?
local function rule_code(rule)
  return string_value(rule.id)
    or string_value(rule.code)
    or string_value(rule.rule_id)
end

---@param rule table
---@return string
local function rule_message(rule)
  local name = string_value(rule.name)
    or string_value(rule.message)
    or string_value(rule.description)
    or 'Unsafe PostgreSQL migration pattern'

  local condition = string_value(rule.condition)

  if condition ~= nil and compact(condition) ~= compact(name) then
    name = string.format(
      '%s: %s',
      compact(name),
      compact(condition)
    )
  else
    name = compact(name)
  end

  return truncate(name, MAX_MESSAGE_BYTES)
end

---@param statement table
---@param rule table
---@param context LintContext
---@return vim.Diagnostic
local function rule_diagnostic(statement, rule, context)
  local code = rule_code(rule)
  local lnum = zero_based_line(statement.line_number)

  local hint_url

  if code ~= nil then
    hint_url = string.format(
      'https://kaveland.no/eugene/hints/%s/',
      code
    )
  end

  return {
    bufnr = context.bufnr,

    code = code,

    col = 0,

    end_col = 0,

    end_lnum = lnum,

    lnum = lnum,

    message = rule_message(rule),

    severity = severity(code),

    source = SOURCE,

    user_data = {
      hint_url = hint_url,

      statement_number = statement.statement_number,
    },
  }
end

---@param report table
---@param context LintContext
---@param diagnostics vim.Diagnostic[]
local function parse_report(report, context, diagnostics)
  if type(report.statements) ~= 'table' then
    return
  end

  for _, statement in ipairs(report.statements) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      return
    end

    if type(statement) == 'table' then
      local rules = statement.triggered_rules

      if type(rules) == 'table' then
        for _, rule in ipairs(rules) do
          if #diagnostics >= MAX_DIAGNOSTICS then
            return
          end

          if type(rule) == 'table' then
            diagnostics[#diagnostics + 1] = rule_diagnostic(
              statement,
              rule,
              context
            )
          end
        end
      end
    end
  end
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub('\27%[[%d;]*m', '')
end

---@param output string
---@return string?
local function error_message(output)
  local text = strip_ansi(vim.trim(output))

  if text == '' then
    return nil
  end

  for line in text:gmatch('[^\r\n]+') do
    local normalized = compact(line)
    local lower = normalized:lower()

    if
      lower:find('error', 1, true) ~= nil
      or lower:find('syntax', 1, true) ~= nil
    then
      return truncate(normalized, MAX_MESSAGE_BYTES)
    end
  end

  local first = text:match('([^\r\n]+)')

  if first == nil then
    return nil
  end

  return truncate(
    compact(first),
    MAX_MESSAGE_BYTES
  )
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(output, context)
  local message = error_message(output)

  if message == nil then
    return {}
  end

  local line_number = output:match('[Ll][Ii][Nn][Ee]%s+(%d+)')
    or output:match('line%s+(%d+)')

  local lnum = zero_based_line(line_number)

  return {
    {
      bufnr = context.bufnr,

      code = 'parse',

      col = 0,

      end_col = 0,

      end_lnum = lnum,

      lnum = lnum,

      message = message,

      severity = diagnostic.severity.ERROR,

      source = SOURCE,
    },
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
  return {
    {
      bufnr = context.bufnr,

      code = 'output-limit',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        'Eugene output exceeded the %d-byte parser limit',
        MAX_OUTPUT_BYTES
      ),

      severity = diagnostic.severity.WARN,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(
    type(context) == 'table',
    'eugene parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'eugene parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local decoded = decode_output(output)

  if decoded == nil then
    return parse_failure(output, context)
  end

  ---@type table[]
  local reports = {}

  collect_reports(
    decoded,
    reports,
    0
  )

  if #reports == 0 then
    return {}
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for index = 1, #reports do
    parse_report(
      reports[index],
      context,
      diagnostics
    )

    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end
  end

  return diagnostics
end

---@type Linter
return {
  args = {
    'lint',
    '--format',
    'json',
    '--accept-failures',
    '--sort-mode',
    'none',
    '-',
  },

  append_fname = false,

  automatic = false,

  cmd = 'eugene',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'both',

  timeout = 30000,
}