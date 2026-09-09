-- qompassai/lua/linters/chktex.lua
-- Qompass AI Diver Native ChkTeX Linter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- ChkTeX machine format:
--   %f:%l:%c:%d:%k:%n:%m
--

local diagnostic = vim.diagnostic

local MAX_DIAGNOSTICS = 512
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'chktex'

local ARGS = {
  '-q',
  '-I0',
  '-f',
  '%f:%l:%c:%d:%k:%n:%m',
  '-',
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

---@param value string
---@return string
local function strip_ansi(value)
  return value:gsub('\27%[[%d;?]*[ -/]*[@-~]', '')
end

---@param value any
---@return integer
local function integer(value)
  local number = tonumber(value)
  if number == nil then
    return 0
  end

  return math.floor(number)
end

---@param value any
---@return integer
local function zero_based(value)
  return math.max(integer(value) - 1, 0)
end

---@param value any
---@return integer
local function nonnegative(value)
  return math.max(integer(value), 0)
end

---@param kind string?
---@return integer
local function severity(kind)
  local normalized = kind and kind:lower() or ''

  if normalized == 'e' or normalized == 'error' then
    return diagnostic.severity.ERROR
  end

  if normalized == 'w' or normalized == 'warning' then
    return diagnostic.severity.WARN
  end

  if normalized == 'i' or normalized == 'info' then
    return diagnostic.severity.INFO
  end

  if normalized == 'n' or normalized == 's' or normalized == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@param path string?
---@param context LintContext
---@return boolean
local function is_stdin_path(path, context)
  if path == nil then
    return true
  end

  if path == '-' or path == 'stdin' or path == '<stdin>' then
    return true
  end

  local filename = string_value(context.filename)
  if filename == nil then
    return true
  end

  return vim.fs.normalize(path) == vim.fs.normalize(filename)
end

---@class ChktexFinding
---@field column integer
---@field filename string
---@field kind string
---@field length integer
---@field line integer
---@field message string
---@field rule string

---@param line string
---@return ChktexFinding?
local function parse_finding(line)
  if line == '' or #line > MAX_LINE_BYTES then
    return nil
  end

  local filename, raw_line, raw_column, raw_length, kind, rule, message =
    line:match('^(.-):(%d+):(%d+):(%d+):([^:]*):([^:]*):(.*)$')

  if
    filename == nil
    or raw_line == nil
    or raw_column == nil
    or raw_length == nil
    or kind == nil
    or rule == nil
    or message == nil
  then
    return nil
  end

  ---@type ChktexFinding
  local finding = {
    column = integer(raw_column),
    filename = filename,
    kind = kind,
    length = integer(raw_length),
    line = integer(raw_line),
    message = message,
    rule = rule,
  }

  return finding
end

---@param finding ChktexFinding
---@param context LintContext
---@return vim.Diagnostic?
local function finding_diagnostic(finding, context)
  if not is_stdin_path(finding.filename, context) then
    return nil
  end

  local lnum = zero_based(finding.line)
  local col = zero_based(finding.column)
  local length = nonnegative(finding.length)
  local message = compact(finding.message)

  if message == '' then
    message = 'ChkTeX diagnostic'
  end

  return {
    bufnr = context.bufnr,
    code = finding.rule ~= '' and finding.rule or nil,
    col = col,
    end_col = length > 0 and col + length or col,
    end_lnum = lnum,
    lnum = lnum,
    message = truncate(message, MAX_MESSAGE_BYTES),
    severity = severity(finding.kind),
    source = SOURCE,
    user_data = {
      chktex_kind = finding.kind,
      chktex_rule = finding.rule,
      path = finding.filename,
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
      message = string.format('ChkTeX output exceeded the %d-byte parser limit', MAX_OUTPUT_BYTES),
      severity = diagnostic.severity.WARN,
      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'chktex parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'chktex parser requires context.bufnr')

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local text = strip_ansi(output)

  for raw_line in text:gmatch('[^\r\n]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local finding = parse_finding(raw_line)
    if finding ~= nil then
      local item = finding_diagnostic(finding, context)
      if item ~= nil then
        diagnostics[#diagnostics + 1] = item
      end
    end
  end

  return diagnostics
end

---@type Linter
return {
  args = ARGS,
  append_fname = false,
  cmd = 'chktex',
  ignoreexitcode = true,
  parser = parse,
  stdin = true,
  stream = 'stdout',
  timeout = 30000,
}
