-- #################################################################
-- ~/.config/nvim/lua/linters/stylelint.lua
-- Qompass AI Diver Native Stylelint Linter
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
---@source https://stylelint.io/
---@source https://stylelint.io/user-guide/cli/
---@source https://stylelint.io/user-guide/configure/
---@source https://stylelint.io/user-guide/options/
--
-- Tiger-style responsibilities:
--
--   * run Stylelint natively from Neovim;
--   * prefer project-local configuration;
--   * feed the current buffer through stdin;
--   * preserve --stdin-filename so custom syntax/config overrides work;
--   * request machine-readable JSON;
--   * bound parser memory and diagnostic volume;
--   * never synthesize Stylelint rules inside Lua.
--
-- Repository policy belongs in:
--
--   stylelint.config.js
--   stylelint.config.mjs
--   stylelint.config.cjs
--   .stylelintrc
--   .stylelintrc.json
--   .stylelintrc.yaml
--   .stylelintrc.yml
--
-- Neovim compatibility:
--
--   * Neovim 0.13+
--   * Lua 5.1-compatible syntax
--   * no Lua 5.2+ language features
--   * no goto
--   * no LuaJIT-only ffi/jit dependency
--   * no deprecated vim.loop alias

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'stylelint'

---@type string[]
local ROOT_MARKERS = {
  'stylelint.config.js',
  'stylelint.config.mjs',
  'stylelint.config.cjs',
  '.stylelintrc',
  '.stylelintrc.json',
  '.stylelintrc.yaml',
  '.stylelintrc.yml',
  'package.json',
  'pnpm-workspace.yaml',
  'yarn.lock',
  'package-lock.json',
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

  if limit <= 3 then
    return value:sub(1, limit)
  end

  return value:sub(1, limit - 3) .. '...'
end

---@param value any
---@return integer
local function zero_based(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local integer = math.floor(number)

  if integer <= 1 then
    return 0
  end

  return integer - 1
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub('\27%[[%d;]*[mK]', '')
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

    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  local cwd = string_value(context.cwd)

  if cwd ~= nil then
    return fs.normalize(cwd)
  end

  return fs.normalize(vim.fn.getcwd())
end

---@param severity string?
---@return integer
local function severity(severity)
  if severity == nil then
    return diagnostic.severity.WARN
  end

  local lower = severity:lower()

  if lower == 'error' then
    return diagnostic.severity.ERROR
  end

  if lower == 'warning' or lower == 'warn' then
    return diagnostic.severity.WARN
  end

  if lower == 'info' or lower == 'information' then
    return diagnostic.severity.INFO
  end

  if lower == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
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

  decoded = decode_slice(text, '[', ']')

  if decoded ~= nil then
    return decoded
  end

  return decode_slice(text, '{', '}')
end

---@param value any
---@param results table[]
---@param depth integer
local function collect_results(value, results, depth)
  if depth > 6 or type(value) ~= 'table' then
    return
  end

  if type(value.warnings) == 'table' then
    results[#results + 1] = value

    return
  end

  for _, child in pairs(value) do
    if type(child) == 'table' then
      collect_results(
        child,
        results,
        depth + 1
      )
    end
  end
end

---@param warning table
---@return string?
local function warning_code(warning)
  return string_value(warning.rule)
    or string_value(warning.code)
end

---@param warning table
---@return string
local function warning_message(warning)
  local message = string_value(warning.text)
    or string_value(warning.message)
    or 'Stylelint diagnostic'

  return truncate(
    compact(message),
    MAX_MESSAGE_BYTES
  )
end

---@param warning table
---@param context LintContext
---@return vim.Diagnostic
local function warning_diagnostic(warning, context)
  local lnum = zero_based(warning.line)
  local col = zero_based(warning.column)

  local end_lnum = lnum
  local end_col = col

  if warning.endLine ~= nil then
    end_lnum = zero_based(
      warning.endLine
    )
  end

  if warning.endColumn ~= nil then
    end_col = zero_based(
      warning.endColumn
    )
  end

  if
    end_lnum < lnum
    or (
      end_lnum == lnum
      and end_col < col
    )
  then
    end_lnum = lnum
    end_col = col
  end

  return {
    bufnr = context.bufnr,

    code = warning_code(warning),

    col = col,

    end_col = end_col,

    end_lnum = end_lnum,

    lnum = lnum,

    message = warning_message(warning),

    severity = severity(
      string_value(warning.severity)
    ),

    source = SOURCE,

    user_data = {
      rule = warning_code(warning),

      severity =
        string_value(
          warning.severity
        ),
    },
  }
end

---@param result table
---@param context LintContext
---@param diagnostics vim.Diagnostic[]
local function parse_result(
  result,
  context,
  diagnostics
)
  if type(result.warnings) ~= 'table' then
    return
  end

  for _, warning in ipairs(result.warnings) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      return
    end

    if type(warning) == 'table' then
      diagnostics[#diagnostics + 1] =
        warning_diagnostic(
          warning,
          context
        )
    end
  end
end

---@param output string
---@return string?
local function error_message(output)
  local text = strip_ansi(
    vim.trim(output)
  )

  if text == '' then
    return nil
  end

  for line in text:gmatch('[^\r\n]+') do
    local normalized = compact(line)
    local lower = normalized:lower()

    if
      lower:find('error', 1, true) ~= nil
      or lower:find('configuration', 1, true) ~= nil
      or lower:find('invalid', 1, true) ~= nil
      or lower:find('failed', 1, true) ~= nil
      or lower:find('cannot', 1, true) ~= nil
      or lower:find('syntax', 1, true) ~= nil
      or lower:find('unknown rule', 1, true) ~= nil
      or lower:find('could not find', 1, true) ~= nil
    then
      return truncate(
        normalized,
        MAX_MESSAGE_BYTES
      )
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

  local line_number =
    output:match('[Ll][Ii][Nn][Ee]%s+(%d+)')
      or output:match(':(%d+):%d+')
      or output:match('line%s+(%d+)')

  local column =
    output:match(':%d+:(%d+)')

  local lnum = zero_based(line_number)
  local col = zero_based(column)

  return {
    {
      bufnr = context.bufnr,

      code = 'stylelint-error',

      col = col,

      end_col = col,

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
        'Stylelint output exceeded the %d-byte parser limit',
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
    'stylelint parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'stylelint parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local decoded = decode_output(output)

  if decoded == nil then
    return parse_failure(
      output,
      context
    )
  end

  ---@type table[]
  local results = {}

  collect_results(
    decoded,
    results,
    0
  )

  if #results == 0 then
    return {}
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for index = 1, #results do
    parse_result(
      results[index],
      context,
      diagnostics
    )

    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == 'table',
    'stylelint arguments require LintContext'
  )

  local filename =
    string_value(
      context.filename
    )

  if filename == nil then
    return {
      '--formatter',
      'json',

      '--stdin',
    }
  end

  return {
    '--formatter',
    'json',

    '--stdin',

    '--stdin-filename',
    filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = true,

  --
  -- Prefer your native linter framework's ordered executable resolution:
  --
  --   project-local package binary first
  --   PATH-installed Stylelint second
  --
  cmd = {
    './node_modules/.bin/stylelint',
    'stylelint',
  },

  cwd = project_root,

  --
  -- Stylelint exits non-zero when lint violations are present and may use a
  -- distinct failure status for configuration/runtime errors. Diagnostics
  -- must still be parsed in either case.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'both',

  timeout = 30000,
}