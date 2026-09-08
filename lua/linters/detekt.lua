-- #################################################################
-- /qompassai/Diver/lua/linters/detekt.lua
-- Qompass AI Detekt
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/detekt/detekt

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class DetektViolation
---@field code? string
---@field column? integer
---@field file? string
---@field line? integer
---@field message? string
---@field severity? string

---@type table<string, integer>
local severities = {
  error = ERROR,
  info = INFO,
  warning = WARN,
}

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0)

  local parsed = tonumber(value)

  if parsed == nil then
    return fallback
  end

  return math.floor(parsed)
end

---@param level string|nil
---@return integer
local function severity(level)
  if level == nil then
    return WARN
  end

  return severities[level:lower()] or WARN
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
  assert(path ~= '')
  assert(filename ~= '')
  assert(root ~= '')

  local candidate

  if fs.is_absolute(path) then
    candidate = fs.normalize(path)
  else
    candidate = fs.normalize(
      fs.joinpath(root, path)
    )
  end

  return candidate == filename
end

---@param root string
---@param candidates string[]
---@return string?
local function find_file(root, candidates)
  assert(root ~= '')

  for index = 1, #candidates do
    local candidate = fs.joinpath(
      root,
      candidates[index]
    )

    if vim.uv.fs_stat(candidate) ~= nil then
      return candidate
    end
  end

  return nil
end

---@param root string
---@return string?
local function config_file(root)
  return find_file(root, {
    'detekt.yml',
    'detekt.yaml',
    'config/detekt/detekt.yml',
    'config/detekt/detekt.yaml',
    'config/detekt/config.yml',
    'config/detekt/config.yaml',
  })
end

---@param root string
---@return string?
local function baseline_file(root)
  return find_file(root, {
    'detekt-baseline.xml',
    'baseline.xml',
    'config/detekt/baseline.xml',
    'config/detekt/detekt-baseline.xml',
  })
end

---@param line string
---@return DetektViolation?
local function parse_line(line)
  if line == '' then
    return nil
  end

  --
  -- Typical Detekt console finding:
  --
  -- /path/Foo.kt:12:5: Some message [RuleName]
  --
  local file,
    line_number,
    column_number,
    message,
    code =
    line:match(
      '^(.+):(%d+):(%d+):%s*(.-)%s+%[([^%]]+)%]$'
    )

  if
    file == nil
    or line_number == nil
    or column_number == nil
    or message == nil
    or code == nil
  then
    return nil
  end

  return {
    code = code,
    column = integer(column_number, 1),
    file = file,
    line = integer(line_number, 1),
    message = message,
    severity = 'warning',
  }
end

---@param violation DetektViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(
  violation,
  filename,
  root
)
  local path = violation.file

  if type(path) ~= 'string' or path == '' then
    return nil
  end

  if not belongs_to_buffer(path, filename, root) then
    return nil
  end

  local start_line = math.max(
    integer(violation.line, 1) - 1,
    0
  )

  local start_column = math.max(
    integer(violation.column, 1) - 1,
    0
  )

  local message = violation.message

  if type(message) ~= 'string' or message == '' then
    message = 'Detekt violation'
  end

  local code = violation.code

  if type(code) ~= 'string' or code == '' then
    code = nil
  end

  return {
    lnum = start_line,
    end_lnum = start_line,
    col = start_column,
    end_col = start_column + 1,
    message = message,
    severity = severity(violation.severity),
    source = 'detekt',
    code = code,
    user_data = {
      analyzer = 'detekt',
    },
  }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
  if output == '' then
    return {}
  end

  assert(
    type(context) == 'table',
    'detekt parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'detekt output exceeded maximum size'
  )

  local filename = fs.normalize(context.filename)
  local root = fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}
  local diagnostics_count = 0

  for line in output:gmatch('[^\r\n]+') do
    if diagnostics_count >= DIAGNOSTICS_MAX then
      break
    end

    local violation = parse_line(line)

    if violation ~= nil then
      local entry = diagnostic_from_violation(
        violation,
        filename,
        root
      )

      if entry ~= nil then
        diagnostics_count = diagnostics_count + 1
        diagnostics[diagnostics_count] = entry
      end
    end
  end

  assert(diagnostics_count <= DIAGNOSTICS_MAX)
  assert(diagnostics_count == #diagnostics)

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(context.filename ~= '')
  assert(context.root ~= '')

  local root = fs.normalize(context.root)

  local argv = {
    '--build-upon-default-config',

    -- Analyze only the current buffer.
    '--input',
    context.filename,

    -- Any finding is relevant in-editor, but Detekt's exit status
    -- does not control whether Neovim receives diagnostics.
    '--fail-on-severity',
    'Info',

    -- Keep report paths deterministic relative to the project.
    '--base-path',
    root,
  }

  local config = config_file(root)

  if config ~= nil then
    argv[#argv + 1] = '--config'
    argv[#argv + 1] = config
  end

  local baseline = baseline_file(root)

  if baseline ~= nil then
    argv[#argv + 1] = '--baseline'
    argv[#argv + 1] = baseline
  end

  return argv
end

return ---@type Linter
{
  automatic = false,

  cmd = 'detekt',

  args = args,

  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')

    return context.root
  end,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    'detekt.yml',
    'detekt.yaml',

    'config/detekt/detekt.yml',
    'config/detekt/detekt.yaml',
    'config/detekt/config.yml',
    'config/detekt/config.yaml',

    'settings.gradle.kts',
    'settings.gradle',
    'build.gradle.kts',
    'build.gradle',
    'gradlew',

    '.git',
  },

  stdin = false,
  stream = 'stdout',
  timeout = 60000,
}