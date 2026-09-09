-- qompassai/lua/linters/commitlint.lua
-- Qompass AI Diver Native Commitlint Linter
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

local diagnostic = vim.diagnostic
local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN
local DIAGNOSTICS_MAX = 256
local LINE_BYTES_MAX = 8192
local MESSAGE_BYTES_MAX = 2048
local OUTPUT_BYTES_MAX = 8 * 1024 * 1024
local SOURCE = 'commitlint'

local ROOTMARKERS = {
  '.commitlintrc',
  '.commitlintrc.json',
  '.commitlintrc.yaml',
  '.commitlintrc.yml',
  '.commitlintrc.js',
  '.commitlintrc.cjs',
  '.commitlintrc.mjs',
  '.commitlintrc.ts',
  '.commitlintrc.cts',
  '.commitlintrc.mts',
  'commitlint.config.js',
  'commitlint.config.cjs',
  'commitlint.config.mjs',
  'commitlint.config.ts',
  'commitlint.config.cts',
  'commitlint.config.mts',
  'package.json',
  '.git',
}

---@type table<string, integer>
local SEVERITY_BY_NUMBER = {
  ['1'] = WARN,
  ['2'] = ERROR,
}

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

---@param context LintContext
---@return string
local function project_root(context)
  assert(type(context) == 'table', 'commitlint cwd requires LintContext')

  if type(context.root) == 'string' and context.root ~= '' then
    return vim.fs.normalize(context.root)
  end

  if type(context.cwd) == 'string' and context.cwd ~= '' then
    return vim.fs.normalize(context.cwd)
  end

  return vim.fn.getcwd()
end

---@class CommitlintFinding
---@field message string
---@field rule string
---@field severity integer

---@param line string
---@return CommitlintFinding?
local function parse_finding(line)
  if line == '' or #line > LINE_BYTES_MAX then
    return nil
  end

  local symbol
  local message
  local rule

  symbol, message, rule = line:match('^%s*([✖⚠])%s+(.+)%s+%[([^%]]+)%]%s*$')

  if symbol ~= nil and message ~= nil and rule ~= nil then
    ---@type CommitlintFinding
    local finding = {
      message = message,
      rule = rule,
      severity = symbol == '✖' and ERROR or WARN,
    }

    return finding
  end

  local numeric

  numeric, message, rule = line:match('^%s*([12])%s+(.+)%s+%[([^%]]+)%]%s*$')

  if numeric == nil or message == nil or rule == nil then
    return nil
  end

  local level = SEVERITY_BY_NUMBER[numeric]
  if level == nil then
    return nil
  end

  ---@type CommitlintFinding
  local finding = {
    message = message,
    rule = rule,
    severity = level,
  }

  return finding
end

---@param context LintContext
---@return vim.Diagnostic
local function oversized_output(context)
  ---@type vim.Diagnostic
  local item = {
    bufnr = context.bufnr,
    code = 'output-limit',
    col = 0,
    end_col = 0,
    end_lnum = 0,
    lnum = 0,
    message = string.format('commitlint output exceeded the %d-byte parser limit', OUTPUT_BYTES_MAX),
    severity = WARN,
    source = SOURCE,
  }

  return item
end

---@param finding CommitlintFinding
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(finding, context)
  local message = compact(finding.message)

  if message == '' then
    message = 'commitlint diagnostic'
  end

  ---@type vim.Diagnostic
  local item = {
    bufnr = context.bufnr,
    code = finding.rule,
    col = 0,
    end_col = 1,
    end_lnum = 0,
    lnum = 0,
    message = truncate(message, MESSAGE_BYTES_MAX),
    severity = finding.severity,
    source = SOURCE,
    user_data = {
      commitlint_rule = finding.rule,
    },
  }

  return item
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'commitlint parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'commitlint parser requires context.bufnr')

  if output == '' then
    return {}
  end

  if #output > OUTPUT_BYTES_MAX then
    return { oversized_output(context) }
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local text = strip_ansi(output)

  for raw_line in text:gmatch('[^\r\n]+') do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local finding = parse_finding(raw_line)
    if finding ~= nil then
      diagnostics[#diagnostics + 1] = finding_diagnostic(finding, context)
    end
  end

  return diagnostics
end

---@type Linter
return {
  args = {
    '--color=false',
  },
  append_fname = false,
  automatic = false,
  cmd = 'commitlint',
  cwd = project_root,
  ignoreexitcode = true,
  parser = parse,
  rootmarkers = ROOTMARKERS,
  stdin = true,
  stream = 'stdout',
  timeout = 30000,
}