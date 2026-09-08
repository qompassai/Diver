-- #################################################################
-- ~/.config/nvim/lua/linters/sqlfluff.lua
-- Qompass AI Diver SQLFluff Linter
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
---@source https://docs.sqlfluff.com/en/stable/
---@source https://docs.sqlfluff.com/en/stable/reference/cli.html
---@source https://docs.sqlfluff.com/en/stable/configuration/setting_configuration.html

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'sqlfluff'

---@type string[]
local ROOT_MARKERS = {
  '.sqlfluff',
  'pyproject.toml',
  'setup.cfg',
  'tox.ini',
  'pep8.ini',
  'dbt_project.yml',
  '.git',
}

---@type table<string, integer>
local ERROR_CODES = {
  LXR = diagnostic.severity.ERROR,
  PRS = diagnostic.severity.ERROR,
  TMP = diagnostic.severity.ERROR,
}

---@param value any
---@return string?
local function nonempty_string(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return value
end

---@param value string
---@return string
local function compact(value)
  return vim.trim(
    value:gsub('%s+', ' ')
  )
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  if #value <= limit then
    return value
  end

  return value:sub(
    1,
    math.max(1, limit - 3)
  ) .. '...'
end

---@param value any
---@return integer
local function zero_based_line(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  return math.max(
    0,
    math.floor(number) - 1
  )
end

---@param value any
---@return integer
local function zero_based_column(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  return math.max(
    0,
    math.floor(number) - 1
  )
end

---@param value any
---@return boolean
local function boolean(value)
  return value == true
end

---@param context LintContext
---@return string
local function project_root(context)
  local context_root = nonempty_string(
    context.root
  )

  if context_root ~= nil then
    return fs.normalize(context_root)
  end

  local filename = nonempty_string(
    context.filename
  )

  if filename ~= nil then
    local detected = fs.root(
      filename,
      ROOT_MARKERS
    )

    if
      type(detected) == 'string'
      and detected ~= ''
    then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if
      type(parent) == 'string'
      and parent ~= ''
    then
      return fs.normalize(parent)
    end
  end

  local cwd = nonempty_string(
    context.cwd
  )

  if cwd ~= nil then
    return fs.normalize(cwd)
  end

  return fs.normalize(
    vim.fn.getcwd()
  )
end

---@param code string?
---@param warning boolean
---@return integer
local function severity(code, warning)
  if code ~= nil then
    local explicit = ERROR_CODES[code]

    if explicit ~= nil then
      return explicit
    end
  end

  if warning then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.WARN
end

---@param violation table
---@return string
local function violation_message(violation)
  local description = nonempty_string(
    violation.description
  ) or 'SQLFluff violation'

  return truncate(
    compact(description),
    MAX_MESSAGE_BYTES
  )
end

---@param violation table
---@param context LintContext
---@return vim.Diagnostic
local function violation_diagnostic(
  violation,
  context
)
  local code = nonempty_string(
    violation.code
  )

  local name = nonempty_string(
    violation.name
  )

  local lnum = zero_based_line(
    violation.start_line_no
  )

  local col = zero_based_column(
    violation.start_line_pos
  )

  local end_lnum = zero_based_line(
    violation.end_line_no
      or violation.start_line_no
  )

  local end_col = zero_based_column(
    violation.end_line_pos
      or violation.start_line_pos
  )

  if end_lnum < lnum then
    end_lnum = lnum
  end

  if
    end_lnum == lnum
    and end_col < col
  then
    end_col = col
  end

  return {
    bufnr = context.bufnr,

    code = code,

    col = col,

    end_col = end_col,

    end_lnum = end_lnum,

    lnum = lnum,

    message = violation_message(
      violation
    ),

    severity = severity(
      code,
      boolean(violation.warning)
    ),

    source = SOURCE,

    user_data = {
      fixes = type(violation.fixes) == 'table'
          and violation.fixes
        or nil,

      rule_name = name,

      start_file_pos = violation.start_file_pos,

      end_file_pos = violation.end_file_pos,
    },
  }
end

---@param diagnostic_item vim.Diagnostic
---@return string
local function diagnostic_key(
  diagnostic_item
)
  return table.concat({
    diagnostic_item.code or '',
    tostring(diagnostic_item.lnum),
    tostring(diagnostic_item.col),
    tostring(diagnostic_item.end_lnum),
    tostring(diagnostic_item.end_col),
    diagnostic_item.message,
  }, '\31')
end

---@param decoded any
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_reports(
  decoded,
  context
)
  if type(decoded) ~= 'table' then
    return {}
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  ---@type table<string, boolean>
  local seen = {}

  for _, report in ipairs(decoded) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    if type(report) == 'table' then
      local violations = report.violations

      if type(violations) == 'table' then
        for _, violation in ipairs(violations) do
          if #diagnostics >= MAX_DIAGNOSTICS then
            break
          end

          if type(violation) == 'table' then
            local item = violation_diagnostic(
              violation,
              context
            )

            local key = diagnostic_key(
              item
            )

            if seen[key] ~= true then
              seen[key] = true
              diagnostics[#diagnostics + 1] = item
            end
          end
        end
      end
    end
  end

  return diagnostics
end

---@param output string
---@return any?
local function decode_json(output)
  local text = vim.trim(output)

  if text == '' then
    return nil
  end

  local ok, decoded = pcall(
    json.decode,
    text
  )

  if ok then
    return decoded
  end

  local first = text:find(
    '[',
    1,
    true
  )

  local last

  local offset = 1

  while true do
    local index = text:find(
      ']',
      offset,
      true
    )

    if index == nil then
      break
    end

    last = index
    offset = index + 1
  end

  if
    first == nil
    or last == nil
    or last < first
  then
    return nil
  end

  local candidate = text:sub(
    first,
    last
  )

  ok, decoded = pcall(
    json.decode,
    candidate
  )

  if not ok then
    return nil
  end

  return decoded
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function malformed_output(
  output,
  context
)
  local message = compact(output)

  if message == '' then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,

      code = 'output',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = truncate(
        message,
        MAX_MESSAGE_BYTES
      ),

      severity = diagnostic.severity.ERROR,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(
  output,
  context
)
  return {
    {
      bufnr = context.bufnr,

      code = 'output-limit',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        'SQLFluff output exceeded the %d-byte parser limit (%d bytes received)',
        MAX_OUTPUT_BYTES,
        #output
      ),

      severity = diagnostic.severity.WARN,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(
  output,
  context
)
  assert(
    type(context) == 'table',
    'sqlfluff parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'sqlfluff parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(
      output,
      context
    )
  end

  local decoded = decode_json(
    output
  )

  if decoded == nil then
    return malformed_output(
      output,
      context
    )
  end

  return parse_reports(
    decoded,
    context
  )
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(
    type(context) == 'table',
    'sqlfluff args requires LintContext'
  )

  ---@type string[]
  local result = {
    'lint',

    '--format',
    'json',

    '--nocolor',

    '--quiet',

    '--disable-progress-bar',

    '--processes',
    '1',

    '--nofail',
  }

  local filename = nonempty_string(
    context.filename
  )

  if filename ~= nil then
    result[#result + 1] = '--stdin-filename'
    result[#result + 1] = filename
  end

  result[#result + 1] = '-'

  return result
end

---@type Linter
return {
  args = args,

  append_fname = false,

  automatic = false,

  cmd = 'sqlfluff',

  cwd = project_root,

  ignore_exitcode = false,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'stdout',

  timeout = 30000,
}