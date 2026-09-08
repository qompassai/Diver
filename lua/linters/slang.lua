-- #################################################################
-- /qompassai/Diver/lua/linters/slang.lua
-- Qompass AI Slang SystemVerilog Linter
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
---@source https://github.com/MikePopoloski/slang
---@source https://sv-lang.com/command-line-ref.html

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local type = type

---@class SlangJsonLocation
---@field file? string
---@field fileName? string
---@field filename? string
---@field line? integer
---@field column? integer

---@class SlangJsonRange
---@field start? SlangJsonLocation
---@field end? SlangJsonLocation

---@class SlangJsonDiagnostic
---@field severity? string|integer
---@field message? string
---@field formattedMessage? string
---@field option? string
---@field optionName? string
---@field code? string|integer
---@field location? SlangJsonLocation
---@field range? SlangJsonRange
---@field ranges? SlangJsonRange[]
---@field file? string
---@field fileName? string
---@field filename? string
---@field line? integer
---@field column? integer

---@type table<string, integer>
local severity_names = {
  fatal = ERROR,
  error = ERROR,

  warning = WARN,
  warn = WARN,

  note = INFO,
  info = INFO,
  information = INFO,

  ignored = HINT,
  hint = HINT,
}

---@type table<integer, integer>
local severity_numbers = {
  [0] = HINT,
  [1] = INFO,
  [2] = WARN,
  [3] = ERROR,
  [4] = ERROR,
}

---@type string[]
local filelist_candidates = {
  'slang.f',
  'files.f',
  'filelist.f',
  'rtl.f',
  'sources.f',
}

---@type string[]
local waiver_candidates = {
  'slang-waivers.toml',
  '.slang-waivers.toml',
  'config/slang-waivers.toml',
  '.config/slang-waivers.toml',
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

  return floor(parsed)
end

---@param value unknown
---@param fallback string
---@return string
local function string_or(value, fallback)
  if
    type(value) ~= 'string'
    or value == ''
  then
    return fallback
  end

  return value
end

---@param value string
---@return string
local function normalize_message(value)
  value = value:gsub('\r\n', '\n')
  value = value:gsub('\r', '\n')

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

---@param value string|integer|nil
---@return integer
local function severity(value)
  if type(value) == 'number' then
    return severity_numbers[
      floor(value)
    ] or WARN
  end

  if type(value) == 'string' then
    local numeric = tonumber(value)

    if numeric ~= nil then
      return severity_numbers[
        floor(numeric)
      ] or WARN
    end

    return severity_names[
      value:lower()
    ] or WARN
  end

  return WARN
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
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
      return candidate
    end
  end

  return nil
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

---@param entry SlangJsonDiagnostic
---@return string?
local function diagnostic_filename(entry)
  local location = entry.location

  if type(location) == 'table' then
    local value =
      location.file
      or location.fileName
      or location.filename

    if
      type(value) == 'string'
      and value ~= ''
    then
      return value
    end
  end

  local range = entry.range

  if
    type(range) == 'table'
    and type(range.start) == 'table'
  then
    local start = range.start

    local value =
      start.file
      or start.fileName
      or start.filename

    if
      type(value) == 'string'
      and value ~= ''
    then
      return value
    end
  end

  local ranges = entry.ranges

  if
    type(ranges) == 'table'
    and type(ranges[1]) == 'table'
    and type(ranges[1].start) == 'table'
  then
    local start = ranges[1].start

    local value =
      start.file
      or start.fileName
      or start.filename

    if
      type(value) == 'string'
      and value ~= ''
    then
      return value
    end
  end

  local value =
    entry.file
    or entry.fileName
    or entry.filename

  if
    type(value) == 'string'
    and value ~= ''
  then
    return value
  end

  return nil
end

---@param entry SlangJsonDiagnostic
---@return integer
---@return integer
---@return integer?
---@return integer?
local function diagnostic_position(entry)
  local location = entry.location

  if type(location) == 'table' then
    local line = max(
      integer(location.line, 1),
      1
    )

    local column = max(
      integer(location.column, 1),
      1
    )

    return line, column, nil, nil
  end

  local range = entry.range

  if
    type(range) == 'table'
    and type(range.start) == 'table'
  then
    local start = range.start
    local finish = range['end']

    local line = max(
      integer(start.line, 1),
      1
    )

    local column = max(
      integer(start.column, 1),
      1
    )

    local end_line
    local end_column

    if type(finish) == 'table' then
      end_line = max(
        integer(
          finish.line,
          line
        ),
        line
      )

      end_column = max(
        integer(
          finish.column,
          column + 1
        ),
        1
      )
    end

    return
      line,
      column,
      end_line,
      end_column
  end

  local ranges = entry.ranges

  if
    type(ranges) == 'table'
    and type(ranges[1]) == 'table'
    and type(ranges[1].start) == 'table'
  then
    local first = ranges[1]
    local start = first.start
    local finish = first['end']

    local line = max(
      integer(start.line, 1),
      1
    )

    local column = max(
      integer(start.column, 1),
      1
    )

    local end_line
    local end_column

    if type(finish) == 'table' then
      end_line = max(
        integer(
          finish.line,
          line
        ),
        line
      )

      end_column = max(
        integer(
          finish.column,
          column + 1
        ),
        1
      )
    end

    return
      line,
      column,
      end_line,
      end_column
  end

  return
    max(integer(entry.line, 1), 1),
    max(integer(entry.column, 1), 1),
    nil,
    nil
end

---@param entry SlangJsonDiagnostic
---@return string?
local function diagnostic_code(entry)
  local option =
    entry.optionName
    or entry.option

  if
    type(option) == 'string'
    and option ~= ''
  then
    if option:sub(1, 2) == '-W' then
      return option
    end

    return '-W' .. option
  end

  if type(entry.code) == 'string' then
    if entry.code ~= '' then
      return entry.code
    end

    return nil
  end

  if type(entry.code) == 'number' then
    return tostring(
      floor(entry.code)
    )
  end

  return nil
end

---@param entry SlangJsonDiagnostic
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(
  entry,
  filename,
  root
)
  local source_file =
    diagnostic_filename(entry)

  --
  -- Some global elaboration diagnostics may not have a source file.
  -- Since this adapter invokes slang against one editor buffer, preserve
  -- such diagnostics rather than silently discarding them.
  --
  if
    source_file ~= nil
    and not belongs_to_buffer(
      source_file,
      filename,
      root
    )
  then
    return nil
  end

  local line,
    column,
    end_line,
    end_column =
      diagnostic_position(entry)

  --
  -- Slang reports one-based source coordinates.
  -- Neovim diagnostics are zero-based.
  --
  local lnum = max(
    line - 1,
    0
  )

  local col = max(
    column - 1,
    0
  )

  local end_lnum = lnum

  if end_line ~= nil then
    end_lnum = max(
      end_line - 1,
      lnum
    )
  end

  local end_col

  if end_column ~= nil then
    end_col = max(
      end_column - 1,
      end_lnum == lnum
          and col + 1
        or 0
    )
  else
    end_col = col + 1
  end

  local message = string_or(
    entry.formattedMessage,
    string_or(
      entry.message,
      'slang diagnostic'
    )
  )

  message =
    normalize_message(message)

  local code =
    diagnostic_code(entry)

  return {
    lnum = lnum,
    end_lnum = end_lnum,

    col = col,
    end_col = end_col,

    message = message,

    severity =
      severity(entry.severity),

    source = 'slang',
    code = code,

    user_data = {
      option = entry.option,
      option_name = entry.optionName,
      diagnostic_code = entry.code,
      source_file = source_file,
    },
  }
end

---@param decoded table
---@return table
local function diagnostic_array(decoded)
  --
  -- Keep the decoder tolerant of small upstream schema changes.
  --
  -- Current and historical structured-diagnostic implementations commonly
  -- use either a root array or an object containing a diagnostics array.
  --
  if #decoded > 0 then
    return decoded
  end

  local diagnostics =
    decoded.diagnostics

  if type(diagnostics) == 'table' then
    return diagnostics
  end

  return {}
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
    'slang parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'slang output exceeded maximum size'
  )

  local ok, decoded = pcall(
    json.decode,
    output
  )

  if
    not ok
    or type(decoded) ~= 'table'
  then
    return {}
  end

  local raw_diagnostics =
    diagnostic_array(decoded)

  local filename =
    fs.normalize(context.filename)

  local root =
    fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  local count = min(
    #raw_diagnostics,
    DIAGNOSTICS_MAX
  )

  for index = 1, count do
    local raw =
      raw_diagnostics[index]

    if type(raw) == 'table' then
      ---@cast raw SlangJsonDiagnostic

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
    -- Emit only structured diagnostics to stdout.
    --
    '--diag-json',
    '-',

    --
    -- Neovim uses byte-oriented columns internally. Slang defaults to
    -- display-width columns, which can disagree in the presence of tabs or
    -- multibyte UTF-8 text.
    --
    '--diag-column-unit',
    'byte',

    --
    -- Absolute paths make diagnostics from includes and generated files
    -- unambiguous and allow exact buffer ownership checks.
    --
    '--diag-abs-paths',

    --
    -- Tiger baseline:
    --
    -- Upstream recommends -Wextra as a good warning set. Avoid -Weverything
    -- here because that is better suited to deliberate audits than continuous
    -- editor linting and can produce excessive noise.
    --
    '-Wextra',

    --
    -- Do not let slang's default 64-error limit truncate editor diagnostics.
    -- The Lua parser still applies its own hard DIAGNOSTICS_MAX bound.
    --
    '--error-limit',
    tostring(DIAGNOSTICS_MAX),
  }

  local waiver =
    find_candidate(
      root,
      waiver_candidates
    )

  if waiver ~= nil then
    argv[#argv + 1] =
      '--waiver-file'

    argv[#argv + 1] =
      waiver
  end

  local filelist =
    find_candidate(
      root,
      filelist_candidates
    )

  --
  -- A project file list can carry include paths, package files, defines, and
  -- compilation ordering that a standalone SystemVerilog source file cannot.
  --
  -- Keep the current file as an explicit input as well; slang handles
  -- duplicate source discovery safely and this ensures editor-local syntax
  -- checking still happens when the file list is incomplete.
  --
  if filelist ~= nil then
    argv[#argv + 1] =
      '-f'

    argv[#argv + 1] =
      filelist
  end

  argv[#argv + 1] =
    context.filename

  return argv
end

return ---@type Linter
{
  automatic = false,

  cmd = 'slang',

  args = args,

  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')

    return context.root
  end,

  --
  -- Compilation errors necessarily produce a nonzero process result.
  -- Those are valid lint results, not adapter failures.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    --
    -- Slang / simulator-style file lists.
    --
    'slang.f',
    'files.f',
    'filelist.f',
    'rtl.f',
    'sources.f',

    --
    -- Diagnostic waiver configuration.
    --
    'slang-waivers.toml',
    '.slang-waivers.toml',

    'config/slang-waivers.toml',
    '.config/slang-waivers.toml',

    --
    -- Common HDL project manifests.
    --
    'Bender.yml',
    'bender.yml',

    'fusesoc.conf',

    '*.core',

    'Makefile',
    'CMakeLists.txt',

    '.git',
  },

  stdin = false,
  stream = 'stdout',
  timeout = 60000,
}