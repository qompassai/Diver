-- #################################################################
-- /qompassai/Diver/lua/linters/dmypy.lua
-- Qompass AI Diver Native dmypy Linter
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
---@source https://github.com/python/mypy
---@source https://mypy.readthedocs.io/en/stable/mypy_daemon.html

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'dmypy'

---@type table<string, integer>
local SEVERITIES = {
  error = ERROR,
  warning = WARN,
  warn = WARN,
  note = INFO,
  info = INFO,
}

---@type string[]
local CONFIG_CANDIDATES = {
  'mypy.ini',
  '.mypy.ini',
  'pyproject.toml',
  'setup.cfg',
}

---@class DmypyParsedDiagnostic
---@field filename string
---@field line integer
---@field column integer
---@field end_line integer?
---@field end_column integer?
---@field severity string
---@field message string
---@field code? string

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0)

  local parsed = tonumber(value)

  if parsed == nil then
    return fallback
  end

  return floor(parsed)
end

---@param value string|nil
---@return integer
local function severity(value)
  if type(value) ~= 'string' then
    return ERROR
  end

  return SEVERITIES[value:lower()] or ERROR
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string')

  return (
    value:gsub(
      '^%s*(.-)%s*$',
      '%1'
    )
  )
end

---@param value string
---@return string
local function strip_ansi(value)
  assert(type(value) == 'string')

  return (
    value:gsub(
      '\27%[[%d;?]*[ -/]*[@-~]',
      ''
    )
  )
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string')

  value = strip_ansi(value)
  value = value:gsub('\r\n', '\n')
  value = value:gsub('\r', '\n')
  value = trim(value)

  if #value > MESSAGE_LENGTH_MAX then
    value =
      value:sub(
        1,
        MESSAGE_LENGTH_MAX
      )
      .. '\n[message truncated]'
  end

  return value
end

---@param root string
---@return string?
local function config_file(root)
  assert(root ~= '')

  for index = 1, #CONFIG_CANDIDATES do
    local candidate = fs.joinpath(
      root,
      CONFIG_CANDIDATES[index]
    )

    if exists(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
  assert(path ~= '')
  assert(root ~= '')

  if path:sub(1, 7) == 'file://' then
    local ok, filename = pcall(
      vim.uri_to_fname,
      path
    )

    if
      ok
      and type(filename) == 'string'
      and filename ~= ''
    then
      return fs.normalize(filename)
    end
  end

  if fs.is_absolute(path) then
    return fs.normalize(path)
  end

  return fs.normalize(
    fs.joinpath(
      root,
      path
    )
  )
end

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(
  candidate,
  filename,
  root
)
  assert(candidate ~= '')
  assert(filename ~= '')
  assert(root ~= '')

  return normalize_path(
    candidate,
    root
  ) == filename
end

---@param message string
---@return string?
local function diagnostic_code(message)
  local code = message:match(
    '%s+%[([%w_%-]+)%]%s*$'
  )

  if
    type(code) ~= 'string'
    or code == ''
  then
    return nil
  end

  return code
end

---@param message string
---@param code string|nil
---@return string
local function remove_code_suffix(
  message,
  code
)
  if code == nil then
    return message
  end

  return trim(
    message:gsub(
      '%s+%['
        .. vim.pesc(code)
        .. '%]%s*$',
      ''
    )
  )
end

---@param line string
---@return DmypyParsedDiagnostic?
local function parse_line(line)
  assert(type(line) == 'string')

  if
    line == ''
    or #line > LINE_LENGTH_MAX
  then
    return nil
  end

  line = strip_ansi(line)

  --
  -- With --show-error-end:
  --
  --   file.py:12:4:12:9: error: message [assignment]
  --
  local filename,
    start_line,
    start_column,
    end_line,
    end_column,
    level,
    message = line:match(
      '^(.+):(%d+):(%d+):(%d+):(%d+):%s*'
        .. '([%a]+):%s*(.+)$'
    )

  if
    filename ~= nil
    and start_line ~= nil
    and start_column ~= nil
    and end_line ~= nil
    and end_column ~= nil
    and level ~= nil
    and message ~= nil
  then
    local code =
      diagnostic_code(message)

    message =
      remove_code_suffix(
        normalize_message(message),
        code
      )

    return {
      filename = filename,

      line = max(
        integer(start_line, 1),
        1
      ),

      --
      -- Mypy columns are already zero-based.
      --
      column = max(
        integer(start_column, 0),
        0
      ),

      end_line = max(
        integer(end_line, 1),
        1
      ),

      end_column = max(
        integer(end_column, 0),
        0
      ),

      severity = level,
      message = message,
      code = code,
    }
  end

  --
  -- Fallback form without end coordinates:
  --
  --   file.py:12:4: error: message [assignment]
  --
  filename,
    start_line,
    start_column,
    level,
    message = line:match(
      '^(.+):(%d+):(%d+):%s*'
        .. '([%a]+):%s*(.+)$'
    )

  if
    filename == nil
    or start_line == nil
    or start_column == nil
    or level == nil
    or message == nil
  then
    return nil
  end

  local code =
    diagnostic_code(message)

  message =
    remove_code_suffix(
      normalize_message(message),
      code
    )

  if message == '' then
    return nil
  end

  return {
    filename = filename,

    line = max(
      integer(start_line, 1),
      1
    ),

    column = max(
      integer(start_column, 0),
      0
    ),

    severity = level,
    message = message,
    code = code,
  }
end

---@param entry DmypyParsedDiagnostic
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(
  entry,
  filename,
  root
)
  if
    not belongs_to_buffer(
      entry.filename,
      filename,
      root
    )
  then
    return nil
  end

  --
  -- Mypy line numbers are one-based.
  -- Mypy columns are zero-based.
  --
  local lnum = max(
    entry.line - 1,
    0
  )

  local col = max(
    entry.column,
    0
  )

  local end_lnum = lnum
  local end_col = col + 1

  if entry.end_line ~= nil then
    end_lnum = max(
      entry.end_line - 1,
      lnum
    )
  end

  if entry.end_column ~= nil then
    end_col = max(
      entry.end_column,
      end_lnum == lnum
          and col + 1
        or 0
    )
  end

  return {
    lnum = lnum,
    end_lnum = end_lnum,

    col = col,
    end_col = end_col,

    message = entry.message,

    severity =
      severity(entry.severity),

    source = SOURCE,
    code = entry.code,

    user_data = {
      error_code = entry.code,
      mypy_severity = entry.severity,
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
    'dmypy parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'dmypy output exceeded maximum size'
  )

  local filename =
    fs.normalize(
      context.filename
    )

  local root =
    fs.normalize(
      context.root
    )

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for line in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local raw =
      parse_line(line)

    if raw ~= nil then
      local entry =
        diagnostic_from_entry(
          raw,
          filename,
          root
        )

      if entry ~= nil then
        diagnostics[#diagnostics + 1] =
          entry
      end
    end
  end

  assert(
    #diagnostics <= DIAGNOSTICS_MAX
  )

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(context.filename ~= '')
  assert(context.root ~= '')

  local root =
    fs.normalize(
      context.root
    )

  local argv = {
    'run',

    --
    -- Keep idle daemon state bounded. The next lint invocation starts it
    -- again automatically.
    --
    '--timeout',
    '900',

    '--',

    --
    -- Deterministic editor diagnostics.
    --
    '--no-color-output',
    '--no-pretty',
    '--no-error-summary',
    '--hide-error-context',

    --
    -- Preserve stable rule IDs such as:
    --
    --   [assignment]
    --   [arg-type]
    --   [override]
    --   [type-arg]
    --
    '--show-error-codes',

    --
    -- Exact source spans are substantially better than a manufactured
    -- one-column diagnostic.
    --
    '--show-error-end',

    --
    -- Tiger profile: dmypy should complement BasedPyright and Ty rather than
    -- repeat every strict inference diagnostic they already produce.
    --
    '--follow-imports=normal',

    --
    -- Keep mypy's warnings that are especially useful for compatibility and
    -- explicit type-contract maintenance.
    --
    '--warn-unused-ignores',
    '--warn-redundant-casts',
    '--warn-unreachable',
    '--extra-checks',

    --
    -- Intentional overlap reduction:
    --
    -- BasedPyright and Ty already perform aggressive "unknown / Any" analysis.
    -- Do not force mypy's full --strict profile here.
    --

    context.filename,
  }

  local config =
    config_file(root)

  if config ~= nil then
    --
    -- Explicit configuration makes daemon identity deterministic when the
    -- repository contains several Python configuration files.
    --
    table.insert(
      argv,
      #argv,
      '--config-file=' .. config
    )
  end

  return argv
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(context.root ~= '')

  return fs.normalize(
    context.root
  )
end

return ---@type Linter
{
  automatic = false,

  cmd = 'dmypy',

  args = args,

  append_fname = false,

  cwd = cwd,

  --
  -- Mypy returns a nonzero status when type errors exist. Those errors are
  -- valid linter output.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    'mypy.ini',
    '.mypy.ini',

    'pyproject.toml',
    'setup.cfg',

    'setup.py',

    'uv.lock',
    'poetry.lock',
    'Pipfile',

    '.git',
  },

  stdin = false,

  --
  -- Normal mypy diagnostic reports are returned on stdout. Operational daemon
  -- failures use stderr.
  --
  stream = 'stdout',

  timeout = 60000,
}