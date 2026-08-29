-- #################################################################
-- /qompassai/Diver/lua/linters/clazy.lua
-- Qompass AI Clazy Qt/C++ Linter
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
---@source https://github.com/KDE/clazy

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
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

---@type table<string, integer>
local severities = {
  error = ERROR,
  fatal = ERROR,

  warning = WARN,
  warn = WARN,

  note = INFO,
  remark = INFO,
  info = INFO,

  ignored = HINT,
  hint = HINT,
}

---@type string[]
local compilation_database_candidates = {
  'compile_commands.json',

  'build/compile_commands.json',
  'Build/compile_commands.json',

  'build-debug/compile_commands.json',
  'build-release/compile_commands.json',

  'cmake-build-debug/compile_commands.json',
  'cmake-build-release/compile_commands.json',

  'out/compile_commands.json',
  'out/build/compile_commands.json',

  '.build/compile_commands.json',
}

---@class ClazyParsedDiagnostic
---@field filename string
---@field line integer
---@field column integer
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
    return WARN
  end

  return severities[value:lower()] or WARN
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param value string
---@return string
local function trim(value)
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
  --
  -- Clang normally disables color when stderr is not a terminal, but do not
  -- depend on terminal detection or user compiler flags. Strip CSI escapes
  -- defensively before parsing diagnostics.
  --
  value = value:gsub(
    '\27%[[%d;?]*[ -/]*[@-~]',
    ''
  )

  return value
end

---@param value string
---@return string
local function normalize_message(value)
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
---@param candidates string[]
---@return string?
local function find_candidate(
  root,
  candidates
)
  assert(root ~= '')

  for index = 1, #candidates do
    local candidate = fs.joinpath(
      root,
      candidates[index]
    )

    if exists(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param root string
---@return string?
local function compilation_database(root)
  return find_candidate(
    root,
    compilation_database_candidates
  )
end

---@param path string
---@param root string
---@return string
local function normalize_path(
  path,
  root
)
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
  --
  -- Clazy warnings follow Clang's diagnostic convention:
  --
  --   ... [clazy-range-loop]
  --
  -- Keep only a trailing clazy identifier. Compiler warning groups such as
  -- [-Wunused-variable] are not falsely attributed to Clazy.
  --
  local code = message:match(
    '%[(clazy%-[%w_%-]+)%]%s*$'
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

  local suffix = '%s*%['
    .. vim.pesc(code)
    .. '%]%s*$'

  return trim(
    message:gsub(
      suffix,
      ''
    )
  )
end

---@param line string
---@return ClazyParsedDiagnostic?
local function parse_line(line)
  if
    line == ''
    or #line > LINE_LENGTH_MAX
  then
    return nil
  end

  line = strip_ansi(line)

  --
  -- Clang / Clazy primary diagnostics use:
  --
  --   file.cpp:12:8: warning: message [clazy-check]
  --
  -- Source snippets, caret lines, include stacks, and summary text do not
  -- match this grammar and are consequently ignored.
  --
  local filename,
    source_line,
    column,
    level,
    message = line:match(
      '^(.+):(%d+):(%d+):%s*'
        .. '([%a]+):%s*'
        .. '(.+)$'
    )

  if
    filename == nil
    or source_line == nil
    or column == nil
    or level == nil
    or message == nil
  then
    --
    -- Some Clang diagnostics have a source line but no column.
    --
    filename,
      source_line,
      level,
      message = line:match(
        '^(.+):(%d+):%s*'
          .. '([%a]+):%s*'
          .. '(.+)$'
      )

    column = '1'
  end

  if
    filename == nil
    or source_line == nil
    or level == nil
    or message == nil
  then
    return nil
  end

  message =
    normalize_message(message)

  if message == '' then
    return nil
  end

  local code =
    diagnostic_code(message)

  message =
    remove_code_suffix(
      message,
      code
    )

  return {
    filename = filename,

    line = max(
      integer(source_line, 1),
      1
    ),

    column = max(
      integer(column, 1),
      1
    ),

    severity = level,
    message = message,
    code = code,
  }
end

---@param entry ClazyParsedDiagnostic
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
  -- Clang source coordinates are one-based.
  -- Neovim diagnostic coordinates are zero-based.
  --
  local lnum = max(
    entry.line - 1,
    0
  )

  local col = max(
    entry.column - 1,
    0
  )

  return {
    lnum = lnum,
    end_lnum = lnum,

    col = col,

    --
    -- The textual Clang diagnostic stream does not expose a reliable source
    -- range. Highlight one byte rather than manufacturing an inaccurate
    -- semantic range.
    --
    end_col = col + 1,

    message = entry.message,

    severity =
      severity(entry.severity),

    source = 'clazy',
    code = entry.code,

    user_data = {
      check = entry.code,
      clang_severity = entry.severity,
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
    'clazy parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'clazy output exceeded maximum size'
  )

  local filename =
    fs.normalize(context.filename)

  local root =
    fs.normalize(context.root)

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
    fs.normalize(context.root)

  local argv = {
    --
    -- Tiger profile:
    --
    -- Level 2 is Clazy's strictest predefined level. Upstream describes its
    -- checks as still having very few false positives, although some are
    -- intentionally noisier or more opinionated than level 0 / level 1.
    --
    '-checks=level2',
  }

  local database =
    compilation_database(root)

  if database ~= nil then
    argv[#argv + 1] = '-p'
    argv[#argv + 1] = database
  end

  --
  -- Analyze only the current translation unit. Do not recursively invoke
  -- Clazy across every entry in compile_commands.json during editor linting.
  --
  argv[#argv + 1] =
    context.filename

  return argv
end

return ---@type Linter
{
  automatic = false,

  cmd = 'clazy-standalone',

  args = args,

  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')

    return fs.normalize(
      context.root
    )
  end,

  --
  -- Clazy / Clang can return nonzero when compiler or analysis diagnostics
  -- are produced. The diagnostic stream remains useful to Neovim.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    --
    -- Compilation databases.
    --
    'compile_commands.json',

    'build/compile_commands.json',
    'Build/compile_commands.json',

    'build-debug/compile_commands.json',
    'build-release/compile_commands.json',

    'cmake-build-debug/compile_commands.json',
    'cmake-build-release/compile_commands.json',

    'out/compile_commands.json',
    '.build/compile_commands.json',

    --
    -- CMake / Qt projects.
    --
    'CMakeLists.txt',
    'CMakePresets.json',
    'CMakeUserPresets.json',

    'meson.build',

    --
    -- qmake.
    --
    '*.pro',
    '*.pri',

    --
    -- Qbs.
    --
    'qbs.qbs',

    '.git',
  },

  stdin = false,

  --
  -- Clang-family diagnostics are emitted through stderr.
  --
  stream = 'stderr',

  timeout = 120000,
}