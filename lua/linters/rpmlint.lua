-- #################################################################
-- /qompassai/Diver/lua/linters/rpmlint.lua
-- Qompass AI Diver Native rpmlint Tiger Linter
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
---@source https://github.com/rpm-software-management/rpmlint

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

local SOURCE = 'rpmlint'

---@type table<string, integer>
local SEVERITIES = {
  E = ERROR,
  W = WARN,
  I = INFO,

  error = ERROR,
  warning = WARN,
  info = INFO,
}

---@type string[]
local CONFIG_CANDIDATES = {
  'rpmlint.toml',
  '.rpmlint.toml',

  'config/rpmlint.toml',
  '.config/rpmlint.toml',
}

---@class RpmlintParsedDiagnostic
---@field filename string
---@field line? integer
---@field severity string
---@field code string
---@field message string

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(
    fallback >= 0,
    'fallback must be non-negative'
  )

  local parsed =
    tonumber(value)

  if parsed == nil then
    return fallback
  end

  return floor(parsed)
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param value string
---@return string
local function trim(value)
  assert(
    type(value) == 'string',
    'value must be a string'
  )

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
  assert(
    type(value) == 'string',
    'value must be a string'
  )

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
  assert(
    type(value) == 'string',
    'value must be a string'
  )

  value =
    strip_ansi(value)

  value =
    value:gsub(
      '\r\n',
      '\n'
    )

  value =
    value:gsub(
      '\r',
      '\n'
    )

  value =
    trim(value)

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
  assert(
    root ~= '',
    'root must not be empty'
  )

  for index = 1, #CONFIG_CANDIDATES do
    local candidate =
      fs.joinpath(
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
  assert(
    path ~= '',
    'path must not be empty'
  )

  assert(
    root ~= '',
    'root must not be empty'
  )

  if path:sub(1, 7) == 'file://' then
    local ok, filename =
      pcall(
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

  --
  -- Diver targets Arch/Linux. Avoid vim.fs.is_absolute(), which is not
  -- available in every Neovim 0.13 Lua type surface.
  --
  if path:sub(1, 1) == '/' then
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
  assert(
    candidate ~= '',
    'candidate must not be empty'
  )

  assert(
    filename ~= '',
    'filename must not be empty'
  )

  assert(
    root ~= '',
    'root must not be empty'
  )

  local normalized_candidate =
    normalize_path(
      candidate,
      root
    )

  local normalized_filename =
    normalize_path(
      filename,
      root
    )

  if normalized_candidate == normalized_filename then
    return true
  end

  --
  -- rpmlint commonly prints only the basename of a specfile even when the
  -- editor supplied an absolute path. Permit basename equality only after
  -- exact normalized-path comparison has failed.
  --
  return fs.basename(
    normalized_candidate
  ) == fs.basename(
    normalized_filename
  )
end

---@param value string
---@return integer
local function severity(value)
  if value == '' then
    return WARN
  end

  return SEVERITIES[value]
    or SEVERITIES[value:lower()]
    or WARN
end

---@param line string
---@return RpmlintParsedDiagnostic?
local function parse_line(line)
  assert(
    type(line) == 'string',
    'line must be a string'
  )

  if
    line == ''
    or #line > LINE_LENGTH_MAX
  then
    return nil
  end

  line =
    strip_ansi(line)

  --
  -- Located specfile diagnostic:
  --
  --   pello.spec:30: E: hardcoded-library-path in %{buildroot}/usr/lib
  --
  local filename,
    line_text,
    level,
    code,
    message =
      line:match(
        '^(.+):(%d+):%s*([EWI]):%s*([^%s:]+)%s*(.*)$'
      )

  if
    filename ~= nil
    and line_text ~= nil
    and level ~= nil
    and code ~= nil
  then
    local line_number =
      integer(
        line_text,
        0
      )

    if line_number < 1 then
      return nil
    end

    message =
      normalize_message(
        message or ''
      )

    code =
      trim(code)

    if code == '' then
      return nil
    end

    if message == '' then
      message = code
    end

    return {
      filename = filename,
      line = line_number,
      severity = level,
      code = code,
      message = message,
    }
  end

  --
  -- File-level diagnostic:
  --
  --   pello.spec: W: invalid-url Source0: https://...
  --
  filename,
    level,
    code,
    message =
      line:match(
        '^(.+):%s*([EWI]):%s*([^%s:]+)%s*(.*)$'
      )

  if
    filename == nil
    or level == nil
    or code == nil
  then
    return nil
  end

  code =
    trim(code)

  if code == '' then
    return nil
  end

  message =
    normalize_message(
      message or ''
    )

  if message == '' then
    message = code
  end

  return {
    filename = filename,
    severity = level,
    code = code,
    message = message,
  }
end

---@param entry RpmlintParsedDiagnostic
---@param bufnr integer
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(
  entry,
  bufnr,
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
  -- rpmlint line numbers are one-based. File-level findings without a line
  -- are anchored to the first line of the buffer.
  --
  local lnum =
    max(
      (entry.line or 1) - 1,
      0
    )

  return {
    bufnr = bufnr,

    lnum = lnum,
    end_lnum = lnum,

    --
    -- rpmlint exposes a line but no reliable source column.
    --
    col = 0,
    end_col = 1,

    message = entry.message,

    severity =
      severity(
        entry.severity
      ),

    source = SOURCE,
    code = entry.code,

    user_data = {
      rpmlint_severity =
        entry.severity,

      located =
        entry.line ~= nil,
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
    'rpmlint parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(
    type(context.bufnr) == 'number'
      and context.bufnr >= 0,
    'context.bufnr must be a valid buffer number'
  )

  assert(
    type(context.filename) == 'string'
      and context.filename ~= '',
    'context.filename must be a non-empty string'
  )

  assert(
    type(context.root) == 'string'
      and context.root ~= '',
    'context.root must be a non-empty string'
  )

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'rpmlint output exceeded maximum size'
  )

  local filename =
    normalize_path(
      context.filename,
      context.root
    )

  local root =
    fs.normalize(
      context.root
    )

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for raw_line in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local entry =
      parse_line(
        raw_line
      )

    if entry ~= nil then
      local result =
        diagnostic_from_entry(
          entry,
          context.bufnr,
          filename,
          root
        )

      if result ~= nil then
        diagnostics[#diagnostics + 1] =
          result
      end
    end
  end

  assert(
    #diagnostics <= DIAGNOSTICS_MAX,
    'diagnostic limit exceeded'
  )

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(
    type(context.filename) == 'string'
      and context.filename ~= '',
    'context.filename must be a non-empty string'
  )

  assert(
    type(context.root) == 'string'
      and context.root ~= '',
    'context.root must be a non-empty string'
  )

  ---@type string[]
  local argv = {}

  local config =
    config_file(
      context.root
    )

  if config ~= nil then
    argv[#argv + 1] =
      '--config'

    argv[#argv + 1] =
      config
  end

  --
  -- Analyze exactly the active specfile.
  --
  -- When only one RPM/spec argument is supplied, rpmlint also automatically
  -- discovers adjacent *.rpmlintrc and *-rpmlintrc files.
  --
  argv[#argv + 1] =
    context.filename

  return argv
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(
    type(context.root) == 'string'
      and context.root ~= '',
    'context.root must be a non-empty string'
  )

  return fs.normalize(
    context.root
  )
end

return ---@type Linter
{
  --
  -- rpmlint reads the saved specfile and can perform filesystem/network/
  -- packaging-oriented checks. It is better suited to save/manual linting
  -- than continuous TextChanged execution.
  --
  automatic = false,

  cmd = 'rpmlint',

  args = args,

  append_fname = false,

  cwd = cwd,

  --
  -- Lint findings can make rpmlint return nonzero. Preserve diagnostic output
  -- independently of process status.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    --
    -- rpmlint policy.
    --
    'rpmlint.toml',
    '.rpmlint.toml',

    'config/rpmlint.toml',
    '.config/rpmlint.toml',

    --
    -- RPM packaging trees.
    --
    'SPECS',
    'SOURCES',

    --
    -- Common project/package boundaries.
    --
    'Makefile',

    '.git',
  },

  stdin = false,

  --
  -- Normal rpmlint findings are written to stdout.
  --
  stream = 'stdout',

  timeout = 120000,
}