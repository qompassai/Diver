-- #################################################################
-- ~/.config/nvim/lua/linters/pmd.lua
-- Qompass AI Diver PMD Linter
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
---@source https://github.com/pmd/pmd
---@source https://docs.pmd-code.org/latest/pmd_userdocs_installation.html
---@source https://docs.pmd-code.org/latest/pmd_userdocs_cli_reference.html

local diagnostic = vim.diagnostic
local fn = vim.fn
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'pmd'

---@type string[]
local ROOT_MARKERS = {
  '.pmd',
  'pmd.xml',
  'pmd-ruleset.xml',
  'ruleset.xml',
  'pom.xml',
  'build.gradle',
  'build.gradle.kts',
  'settings.gradle',
  'settings.gradle.kts',
  'gradlew',
  'mvnw',
  'sfdx-project.json',
  '.git',
}

---@type string[]
local RULESET_CANDIDATES = {
  '.pmd/ruleset.xml',
  '.pmd/pmd.xml',
  'config/pmd/ruleset.xml',
  'config/pmd/pmd.xml',
  'config/pmd.xml',
  'pmd/ruleset.xml',
  'pmd/pmd.xml',
  'pmd-ruleset.xml',
  'ruleset.xml',
  'pmd.xml',
}

---@type table<string, boolean>
local JAVA_EXTENSIONS = {
  java = true,
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

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub('\27%[[%d;]*m', '')
end

---@param value any
---@return integer
local function number_value(value)
  local converted = tonumber(value)

  if converted == nil then
    return 0
  end

  return math.floor(converted)
end

---@param value any
---@return integer
local function zero_based_line(value)
  local line = number_value(value)

  if line <= 1 then
    return 0
  end

  return line - 1
end

---@param value any
---@return integer
local function zero_based_column(value)
  local column = number_value(value)

  if column <= 1 then
    return 0
  end

  return column - 1
end

---@param value any
---@param fallback integer
---@return integer
local function end_position(value, fallback)
  local position = number_value(value)

  if position <= 0 then
    return fallback
  end

  return math.max(
    fallback,
    position - 1
  )
end

---@param path string
---@return boolean
local function readable(path)
  return fn.filereadable(path) == 1
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
    local detected = fs.root(
      filename,
      ROOT_MARKERS
    )

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

  return fs.normalize(fn.getcwd())
end

---@param filename string?
---@return string?
local function extension(filename)
  if filename == nil then
    return nil
  end

  local ext = filename:match('%.([^./\\]+)$')

  if ext == nil or ext == '' then
    return nil
  end

  return ext:lower()
end

---@param filename string?
---@return boolean
local function is_java(filename)
  local ext = extension(filename)

  if ext == nil then
    return false
  end

  return JAVA_EXTENSIONS[ext] == true
end

---@param root string
---@return string?
local function project_ruleset(root)
  for _, relative in ipairs(RULESET_CANDIDATES) do
    local candidate = fs.joinpath(
      root,
      relative
    )

    if readable(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param context LintContext
---@return string
local function ruleset(context)
  local configured = string_value(
    vim.env.PMD_RULESET
  )

  if configured ~= nil then
    local expanded = fn.expand(configured)

    if readable(expanded) then
      return fs.normalize(expanded)
    end

    -- PMD also accepts classpath rulesets such as
    -- rulesets/java/quickstart.xml and category/... references.
    if not configured:match('^[/~.]') then
      return configured
    end
  end

  local root = project_root(context)
  local discovered = project_ruleset(root)

  if discovered ~= nil then
    return discovered
  end

  if is_java(
    string_value(context.filename)
  ) then
    return 'rulesets/java/quickstart.xml'
  end

  -- PMD requires a ruleset. Keep the fallback deliberately invalid and
  -- descriptive instead of silently applying a Java policy to another
  -- language. PMD's own error is converted to a Neovim diagnostic.
  return '__qompass_pmd_ruleset_required__.xml'
end

---@param context LintContext
---@return string[]
local function args(context)
  return {
    'check',

    '--format',
    'json',

    '--rulesets',
    ruleset(context),

    '--no-cache',

    '--no-progress',

    '--no-fail-on-violation',
  }
end

---@param priority any
---@return integer
local function severity(priority)
  local number = tonumber(priority)

  if number == nil then
    return diagnostic.severity.WARN
  end

  -- PMD priorities:
  --
  --   1 = High
  --   2 = Medium High
  --   3 = Medium
  --   4 = Medium Low
  --   5 = Low
  if number <= 1 then
    return diagnostic.severity.ERROR
  end

  if number <= 3 then
    return diagnostic.severity.WARN
  end

  if number == 4 then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.HINT
end

---@param filename any
---@param context LintContext
---@return boolean
local function belongs_to_buffer(filename, context)
  local reported = string_value(filename)

  if reported == nil then
    return true
  end

  local current = string_value(
    context.filename
  )

  if current == nil then
    return true
  end

  local normalized_reported = fs.normalize(reported)
  local normalized_current = fs.normalize(current)

  if normalized_reported == normalized_current then
    return true
  end

  -- PMD renderers may return a relative path depending on invocation.
  if fs.basename(normalized_reported) == fs.basename(normalized_current) then
    return true
  end

  local root = project_root(context)

  if not fs.is_absolute(normalized_reported) then
    local rooted = fs.normalize(
      fs.joinpath(
        root,
        normalized_reported
      )
    )

    if rooted == normalized_current then
      return true
    end
  end

  return false
end

---@param violation table
---@return string?
local function rule_code(violation)
  return string_value(violation.rule)
    or string_value(violation.ruleName)
    or string_value(violation.name)
end

---@param violation table
---@return string
local function violation_message(violation)
  local message = string_value(violation.description)
    or string_value(violation.message)
    or string_value(violation.msg)
    or 'PMD rule violation'

  return truncate(
    compact(message),
    MAX_MESSAGE_BYTES
  )
end

---@param violation table
---@param filename string?
---@param context LintContext
---@return vim.Diagnostic?
local function violation_diagnostic(
  violation,
  filename,
  context
)
  if not belongs_to_buffer(filename, context) then
    return nil
  end

  local lnum = zero_based_line(
    violation.beginline
      or violation.beginLine
      or violation.line
  )

  local col = zero_based_column(
    violation.begincolumn
      or violation.beginColumn
      or violation.column
  )

  local end_lnum = end_position(
    violation.endline
      or violation.endLine,
    lnum
  )

  local end_col = end_position(
    violation.endcolumn
      or violation.endColumn,
    col
  )

  local code = rule_code(violation)

  local ruleset_name = string_value(
    violation.ruleset
      or violation.ruleSet
  )

  local rule_url = string_value(
    violation.externalInfoUrl
      or violation.external_info_url
      or violation.url
  )

  return {
    bufnr = context.bufnr,

    code = code,

    col = col,

    end_col = end_col,

    end_lnum = end_lnum,

    lnum = lnum,

    message = violation_message(violation),

    severity = severity(
      violation.priority
    ),

    source = SOURCE,

    user_data = {
      external_info_url = rule_url,

      priority = violation.priority,

      ruleset = ruleset_name,
    },
  }
end

---@param value any
---@param filename string?
---@param context LintContext
---@param diagnostics vim.Diagnostic[]
---@param depth integer
local function collect_violations(
  value,
  filename,
  context,
  diagnostics,
  depth
)
  if
    depth > 8
    or type(value) ~= 'table'
    or #diagnostics >= MAX_DIAGNOSTICS
  then
    return
  end

  local current_filename = string_value(
    value.filename
      or value.fileName
      or value.file
  ) or filename

  if type(value.violations) == 'table' then
    for _, violation in ipairs(value.violations) do
      if #diagnostics >= MAX_DIAGNOSTICS then
        return
      end

      if type(violation) == 'table' then
        local item = violation_diagnostic(
          violation,
          current_filename,
          context
        )

        if item ~= nil then
          diagnostics[#diagnostics + 1] = item
        end
      end
    end
  end

  for key, child in pairs(value) do
    if
      key ~= 'violations'
      and type(child) == 'table'
    then
      collect_violations(
        child,
        current_filename,
        context,
        diagnostics,
        depth + 1
      )
    end
  end
end

---@param value any
---@return string?
local function processing_message(value)
  if type(value) == 'string' then
    return string_value(value)
  end

  if type(value) ~= 'table' then
    return nil
  end

  return string_value(value.message)
    or string_value(value.msg)
    or string_value(value.error)
    or string_value(value.detail)
end

---@param values any
---@param code string
---@param context LintContext
---@param diagnostics vim.Diagnostic[]
local function collect_processing_errors(
  values,
  code,
  context,
  diagnostics
)
  if type(values) ~= 'table' then
    return
  end

  for _, value in ipairs(values) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      return
    end

    local message = processing_message(value)

    if message ~= nil then
      local filename

      if type(value) == 'table' then
        filename = string_value(
          value.filename
            or value.fileName
            or value.file
      )
      end

      if belongs_to_buffer(filename, context) then
        diagnostics[#diagnostics + 1] = {
          bufnr = context.bufnr,

          code = code,

          col = 0,

          end_col = 0,

          end_lnum = 0,

          lnum = 0,

          message = truncate(
            compact(message),
            MAX_MESSAGE_BYTES
          ),

          severity = diagnostic.severity.ERROR,

          source = SOURCE,
        }
      end
    end
  end
end

---@param decoded table
---@param context LintContext
---@param diagnostics vim.Diagnostic[]
local function collect_report_errors(
  decoded,
  context,
  diagnostics
)
  collect_processing_errors(
    decoded.processingErrors
      or decoded.processingerrors
      or decoded.processing_errors,
    'processing-error',
    context,
    diagnostics
  )

  collect_processing_errors(
    decoded.configurationErrors
      or decoded.configurationerrors
      or decoded.configuration_errors,
    'configuration-error',
    context,
    diagnostics
  )

  collect_processing_errors(
    decoded.errors,
    'error',
    context,
    diagnostics
  )
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

  -- Protect against launchers/JVMs placing informational text before the
  -- JSON report. Search for the first object/array and decode the largest
  -- plausible suffix.
  local object_start = text:find(
    '{',
    1,
    true
  )

  local array_start = text:find(
    '[',
    1,
    true
  )

  local start_index

  if object_start ~= nil and array_start ~= nil then
    start_index = math.min(
      object_start,
      array_start
    )
  else
    start_index = object_start
      or array_start
  end

  if start_index == nil then
    return nil
  end

  local candidate = text:sub(start_index)

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
---@return string?
local function failure_message(output)
  local text = strip_ansi(
    vim.trim(output)
  )

  if text == '' then
    return nil
  end

  for line in text:gmatch('[^\r\n]+') do
    local message = compact(line)
    local lower = message:lower()

    if
      lower:find('error', 1, true) ~= nil
      or lower:find('exception', 1, true) ~= nil
      or lower:find('ruleset', 1, true) ~= nil
      or lower:find('invalid', 1, true) ~= nil
      or lower:find('failed', 1, true) ~= nil
    then
      return truncate(
        message,
        MAX_MESSAGE_BYTES
      )
    end
  end

  local first = text:match(
    '([^\r\n]+)'
  )

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
  local message = failure_message(output)

  if message == nil then
    return {}
  end

  if
    message:find(
      '__qompass_pmd_ruleset_required__.xml',
      1,
      true
    ) ~= nil
  then
    message =
      'PMD requires a ruleset for this language; '
      .. 'set PMD_RULESET or add a project PMD ruleset'
  end

  return {
    {
      bufnr = context.bufnr,

      code = 'pmd-error',

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

      message = string.format(
        'PMD output exceeded the %d-byte parser limit',
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
    'pmd parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'pmd parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local decoded = decode_json(output)

  if type(decoded) ~= 'table' then
    return parse_failure(
      output,
      context
    )
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  collect_violations(
    decoded,
    nil,
    context,
    diagnostics,
    0
  )

  collect_report_errors(
    decoded,
    context,
    diagnostics
  )

  return diagnostics
end

---@type Linter
return {
  args = args,

  -- PMD analyzes actual source paths rather than editor stdin.
  append_fname = true,

  automatic = false,

  cmd = 'pmd',

  cwd = project_root,

  -- Violations and recoverable analysis failures are represented through
  -- PMD's report instead of relying on process status alone.
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = 'both',

  timeout = 60000,
}