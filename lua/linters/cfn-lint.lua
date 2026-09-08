-- #################################################################
-- ~/.config/nvim/lua/linters/cfn-lint.lua
-- Qompass AI Diver Native AWS CloudFormation Linter
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
---@source https://github.com/aws-cloudformation/cfn-lint
---@source https://github.com/aws-cloudformation/cfn-lint/blob/main/docs/rules.md
---@source https://github.com/aws-cloudformation/cfn-lint/blob/main/src/cfnlint/formatters/json.py
---@source https://neovim.io/doc/user/diagnostic/
---@source https://neovim.io/doc/user/lua/
--
-- Installation:
--
--   python -m pip install --user cfn-lint
--
-- or with all optional formatter/runtime dependencies:
--
--   python -m pip install --user 'cfn-lint[full]'
--
-- Verify:
--
--   cfn-lint --version
--
-- Tiger policy:
--
--   * lint unsaved CloudFormation templates through stdin;
--   * request cfn-lint's native JSON formatter;
--   * retain rule IDs, descriptions, source URLs, paths, and parent IDs;
--   * retain exact start/end line and column ranges;
--   * explicitly include informational rules;
--   * leave experimental rules disabled unless explicitly requested;
--   * honor .cfnlintrc / template Metadata automatically;
--   * preserve SAM transform support;
--   * avoid overriding project policy from Lua;
--   * bound parser depth, diagnostics, messages, and total output;
--   * avoid shell interpolation;
--   * remain compatible with Neovim's Lua 5.1 language contract.
--
-- Optional environment overrides:
--
--   NVIM_CFN_LINT_REGIONS='us-east-1,us-west-2'
--   NVIM_CFN_LINT_EXPERIMENTAL=1
--
-- Region behavior:
--
--   If NVIM_CFN_LINT_REGIONS is unset, cfn-lint's own configuration and
--   defaults remain authoritative.
--
-- Experimental behavior:
--
--   Experimental rules are intentionally opt-in:
--
--     export NVIM_CFN_LINT_EXPERIMENTAL=1
--
local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 4096
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_PARSE_DEPTH = 6
local SOURCE = 'cfn-lint'

local ROOT_MARKERS = {
  {
    '.cfnlintrc',
    '.cfnlintrc.yaml',
    '.cfnlintrc.yml',
  },
  {
    'template.yaml',
    'template.yml',
    'template.json',
  },
  {
    'samconfig.toml',
    'serverless.yml',
    'serverless.yaml',
  },
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

---@param value string?
---@return boolean
local function truthy(value)
  if value == nil then
    return false
  end

  local normalized = value:lower()

  return normalized == '1' or normalized == 'true' or normalized == 'yes' or normalized == 'on'
end

---@param value string?
---@return string[]
local function split_csv(value)
  ---@type string[]
  local result = {}

  if value == nil or value == '' then
    return result
  end

  for item in value:gmatch('[^,]+') do
    local normalized = vim.trim(item)

    if normalized ~= '' then
      result[#result + 1] = normalized
    end
  end

  return result
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

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.WARN
  end

  local normalized = level:lower()

  if normalized == 'error' then
    return diagnostic.severity.ERROR
  end

  if normalized == 'warning' or normalized == 'warn' then
    return diagnostic.severity.WARN
  end

  if normalized == 'informational' or normalized == 'information' or normalized == 'info' then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.WARN
end

---@param rule_id string?
---@return integer
local function severity_from_rule(rule_id)
  if rule_id == nil then
    return diagnostic.severity.WARN
  end

  local prefix = rule_id:sub(1, 1):upper()

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

---@class CfnLintPosition
---@field ColumnNumber? integer
---@field LineNumber? integer

---@class CfnLintLocation
---@field End? CfnLintPosition
---@field Path? any[]
---@field Start? CfnLintPosition

---@class CfnLintRule
---@field Description? string
---@field Id? string
---@field ShortDescription? string
---@field Source? string

---@class CfnLintFinding
---@field Filename? string
---@field Id? string
---@field Level? string
---@field Location? CfnLintLocation
---@field Message? string
---@field ParentId? string
---@field Rule? CfnLintRule

---@param value any
---@return boolean
local function finding_record(value)
  if type(value) ~= 'table' then
    return false
  end

  return string_value(value.Message) ~= nil
    and (type(value.Rule) == 'table' or type(value.Location) == 'table' or string_value(value.Id) ~= nil)
end

---@param value any
---@param findings table[]
---@param depth integer
local function collect_findings(value, findings, depth)
  if depth > MAX_PARSE_DEPTH or type(value) ~= 'table' then
    return
  end

  if finding_record(value) then
    findings[#findings + 1] = value

    return
  end

  for _, child in pairs(value) do
    if type(child) == 'table' then
      collect_findings(child, findings, depth + 1)
    end
  end
end

---@param location CfnLintLocation?
---@return integer, integer, integer, integer
local function diagnostic_range(location)
  if type(location) ~= 'table' then
    return 0, 0, 0, 0
  end

  local start = location.Start
  local finish = location.End

  local lnum = 0
  local col = 0
  local end_lnum = 0
  local end_col = 0

  if type(start) == 'table' then
    lnum = zero_based(start.LineNumber)

    col = zero_based(start.ColumnNumber)
  end

  end_lnum = lnum
  end_col = col

  if type(finish) == 'table' then
    if finish.LineNumber ~= nil then
      end_lnum = zero_based(finish.LineNumber)
    end

    if finish.ColumnNumber ~= nil then
      end_col = zero_based(finish.ColumnNumber)
    end
  end

  if end_lnum < lnum or (end_lnum == lnum and end_col < col) then
    end_lnum = lnum
    end_col = col
  end

  return lnum, col, end_lnum, end_col
end

---@param path any
---@return string?
local function location_path(path)
  if type(path) ~= 'table' then
    return nil
  end

  ---@type string[]
  local parts = {}

  for index = 1, #path do
    local value = path[index]

    if type(value) == 'string' or type(value) == 'number' then
      parts[#parts + 1] = tostring(value)
    end
  end

  if #parts == 0 then
    return nil
  end

  return table.concat(parts, '.')
end

---@param finding CfnLintFinding
---@param context LintContext
---@return vim.Diagnostic?
local function finding_diagnostic(finding, context)
  local message = string_value(finding.Message)

  if message == nil then
    return nil
  end

  local rule = finding.Rule

  local rule_id

  if type(rule) == 'table' then
    rule_id = string_value(rule.Id)
  end

  if rule_id == nil then
    rule_id = string_value(finding.Id)
  end

  local lnum, col, end_lnum, end_col = diagnostic_range(finding.Location)

  local level = string_value(finding.Level)

  local diagnostic_severity

  if level ~= nil then
    diagnostic_severity = severity(level)
  else
    diagnostic_severity = severity_from_rule(rule_id)
  end

  local path

  if type(finding.Location) == 'table' then
    path = location_path(finding.Location.Path)
  end

  return {
    bufnr = context.bufnr,

    code = rule_id,

    col = col,

    end_col = end_col,

    end_lnum = end_lnum,

    lnum = lnum,

    message = truncate(compact(message), MAX_MESSAGE_BYTES),

    severity = diagnostic_severity,

    source = SOURCE,

    user_data = {
      filename = string_value(finding.Filename),

      id = string_value(finding.Id),

      parent_id = string_value(finding.ParentId),

      path = path,

      rule = rule_id,

      rule_description = type(rule) == 'table' and string_value(rule.Description) or nil,

      rule_short_description = type(rule) == 'table' and string_value(rule.ShortDescription) or nil,

      rule_source = type(rule) == 'table' and string_value(rule.Source) or nil,
    },
  }
end

---@param output string
---@return any?
local function decode_output(output)
  local text = vim.trim(output)

  if text == '' then
    return nil
  end

  local ok, decoded = pcall(json.decode, text)

  if not ok then
    return nil
  end

  return decoded
end

---@param output string
---@return string?
local function operational_message(output)
  local text = strip_ansi(vim.trim(output))

  if text == '' then
    return nil
  end

  for raw_line in text:gmatch('[^\r\n]+') do
    local line = compact(raw_line)

    local lower = line:lower()

    if
      lower:find('error', 1, true) ~= nil
      or lower:find('failed', 1, true) ~= nil
      or lower:find('cannot', 1, true) ~= nil
      or lower:find('invalid', 1, true) ~= nil
      or lower:find('configuration', 1, true) ~= nil
      or lower:find('traceback', 1, true) ~= nil
    then
      return truncate(line, MAX_MESSAGE_BYTES)
    end
  end

  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(output, context)
  local message = operational_message(output)

  if message == nil then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,

      code = 'cfn-lint-error',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

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

      message = string.format('cfn-lint output exceeded the %d-byte parser limit', MAX_OUTPUT_BYTES),

      severity = diagnostic.severity.WARN,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'cfn-lint parser requires LintContext')

  assert(type(context.bufnr) == 'number', 'cfn-lint parser requires context.bufnr')

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
  local findings = {}

  collect_findings(decoded, findings, 0)

  if #findings == 0 then
    return {}
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for index = 1, #findings do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local item = finding_diagnostic(findings[index], context)

    if item ~= nil then
      diagnostics[#diagnostics + 1] = item
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'cfn-lint arguments require LintContext')

  ---@type string[]
  local args = {
    '--format',
    'json',

    '--include-checks',
    'I',

    '--non-zero-exit-code',
    'none',
  }

  if truthy(vim.env.NVIM_CFN_LINT_EXPERIMENTAL) then
    args[#args + 1] = '--include-experimental'
  end

  local regions = split_csv(string_value(vim.env.NVIM_CFN_LINT_REGIONS))

  if #regions > 0 then
    args[#args + 1] = '--regions'

    for index = 1, #regions do
      args[#args + 1] = regions[index]
    end
  end
  args[#args + 1] = '-'

  return args
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = true,

  cmd = 'cfn-lint',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'both',

  timeout = 60000,
}
