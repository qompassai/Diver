-- #################################################################
-- ~/.config/nvim/lua/linters/ghdl.lua
-- Qompass AI Diver GHDL Linter
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
---@source https://github.com/ghdl/ghdl
---@source https://ghdl.github.io/ghdl/using/InvokingGHDL.html

local diagnostic = vim.diagnostic
local env = vim.env
local fs = vim.fs

local MAX_DIAGNOSTICS = 256
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 4 * 1024 * 1024
local SOURCE = 'ghdl'

---@type string[]
local ROOT_MARKERS = {
  'vhdl_ls.toml',
  'hdl-prj.json',
  'CMakeLists.txt',
  'Makefile',
  'meson.build',
  '.git',
}

---@type table<string, integer>
local SEVERITY = {
  error = diagnostic.severity.ERROR,
  failure = diagnostic.severity.ERROR,
  fatal = diagnostic.severity.ERROR,
  note = diagnostic.severity.INFO,
  warning = diagnostic.severity.WARN,
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

---@param value string
---@return string
local function strip_ansi(value)
  return value:gsub(
    '\27%[[%d;]*[A-Za-z]',
    ''
  )
end

---@param value any
---@return integer
local function zero_based(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local result = math.floor(number)

  if result <= 1 then
    return 0
  end

  return result - 1
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

---@param value string?
---@return integer
local function severity(value)
  if value == nil then
    return diagnostic.severity.ERROR
  end

  return SEVERITY[value:lower()]
    or diagnostic.severity.ERROR
end

---@param message string
---@return string?, string
local function warning_code(message)
  local code = message:match(
    '%[%-(W[%w%-]+)%]%s*$'
  )

  if code == nil then
    return nil, message
  end

  local cleaned = message:gsub(
    '%s*%[%-(W[%w%-]+)%]%s*$',
    ''
  )

  return code, cleaned
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

---@param path string
---@param context LintContext
---@return boolean
local function belongs_to_buffer(path, context)
  if path == '' then
    return true
  end

  local filename = nonempty_string(
    context.filename
  )

  if filename == nil then
    return true
  end

  local normalized_path = fs.normalize(path)
  local normalized_filename = fs.normalize(filename)

  if normalized_path == normalized_filename then
    return true
  end

  return fs.basename(normalized_path)
    == fs.basename(normalized_filename)
end

---@param message string
---@param level string?
---@param line any
---@param column any
---@param code string?
---@param context LintContext
---@return vim.Diagnostic
local function make_diagnostic(
  message,
  level,
  line,
  column,
  code,
  context
)
  local lnum = zero_based(line)
  local col = zero_based_column(column)

  return {
    bufnr = context.bufnr,

    code = code,

    col = col,

    end_col = col,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      compact(message),
      MAX_MESSAGE_BYTES
    ),

    severity = severity(level),

    source = SOURCE,
  }
end

---@param line string
---@param context LintContext
---@return vim.Diagnostic?
local function parse_located(line, context)
  local path
  local line_number
  local column
  local level
  local message

  path,
    line_number,
    column,
    level,
    message = line:match(
      '^(.+):(%d+):(%d+):%s*([%a]+):%s*(.+)$'
    )

  if path ~= nil then
    if not belongs_to_buffer(path, context) then
      return nil
    end

    local code
    code, message = warning_code(message)

    return make_diagnostic(
      message,
      level,
      line_number,
      column,
      code,
      context
    )
  end

  path,
    line_number,
    column,
    message = line:match(
      '^(.+):(%d+):(%d+):%s*(.+)$'
    )

  if path ~= nil then
    if not belongs_to_buffer(path, context) then
      return nil
    end

    local code
    code, message = warning_code(message)

    return make_diagnostic(
      message,
      nil,
      line_number,
      column,
      code,
      context
    )
  end

  path,
    line_number,
    level,
    message = line:match(
      '^(.+):(%d+):%s*([%a]+):%s*(.+)$'
    )

  if path ~= nil then
    if not belongs_to_buffer(path, context) then
      return nil
    end

    local code
    code, message = warning_code(message)

    return make_diagnostic(
      message,
      level,
      line_number,
      1,
      code,
      context
    )
  end

  path,
    line_number,
    message = line:match(
      '^(.+):(%d+):%s*(.+)$'
    )

  if path == nil then
    return nil
  end

  if not belongs_to_buffer(path, context) then
    return nil
  end

  local code
  code, message = warning_code(message)

  return make_diagnostic(
    message,
    nil,
    line_number,
    1,
    code,
    context
  )
end

---@param line string
---@param context LintContext
---@return vim.Diagnostic?
local function parse_global(line, context)
  local level
  local message

  level, message = line:match(
    '^ghdl:%s*([%a]+):%s*(.+)$'
  )

  if level ~= nil then
    return make_diagnostic(
      message,
      level,
      1,
      1,
      nil,
      context
    )
  end

  level, message = line:match(
    '^([%a]+):%s*(.+)$'
  )

  if
    level ~= nil
    and SEVERITY[level:lower()] ~= nil
  then
    return make_diagnostic(
      message,
      level,
      1,
      1,
      nil,
      context
    )
  end

  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(output, context)
  return {
    {
      bufnr = context.bufnr,

      code = 'output-limit',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        'GHDL output exceeded the %d-byte parser limit (%d bytes received)',
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
local function parse(output, context)
  assert(
    type(context) == 'table',
    'ghdl parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'ghdl parser requires context.bufnr'
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

  output = strip_ansi(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  ---@type vim.Diagnostic?
  local previous

  for raw_line in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local line = vim.trim(raw_line)

    if line ~= '' then
      local item = parse_located(
        line,
        context
      )

      if item == nil then
        item = parse_global(
          line,
          context
        )
      end

      if item ~= nil then
        diagnostics[#diagnostics + 1] = item
        previous = item
      elseif
        previous ~= nil
        and not line:match('^%^')
        and not line:match('^%s*|')
      then
        local continuation = compact(line)

        if continuation ~= '' then
          previous.message = truncate(
            previous.message
              .. ' '
              .. continuation,
            MAX_MESSAGE_BYTES
          )
        end
      end
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(
    type(context) == 'table',
    'ghdl args requires LintContext'
  )

  local standard = nonempty_string(
    env.GHDL_STD
  ) or '08'

  return {
    '-s',

    '--std=' .. standard,

    '-fno-color-diagnostics',

    '-fdiagnostics-show-option',

    '-fno-caret-diagnostics',

    '--no-notes',

    '--warn-library',

    '--warn-default-binding',

    '--warn-port',

    '--warn-reserved',

    '--warn-pragma',

    '--warn-nested-comment',

    '--warn-parenthesis',

    '--warn-delayed-checks',

    '--warn-body',

    '--warn-specs',

    '--warn-universal',

    '--warn-port-bounds',

    '--warn-runtime-error',

    '--warn-delta-cycle',

    '--warn-missing-wait',

    '--warn-shared',

    '--warn-hide',

    '--warn-unused',

    '--warn-others',

    '--warn-pure',

    '--warn-analyze-assert',

    '--warn-attribute',

    '--warn-useless',

    '--warn-missing-assoc',

    '--warn-static',
  }
end

---@type Linter
return {
  args = args,

  append_fname = true,

  automatic = false,

  cmd = 'ghdl',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = 'both',

  timeout = 30000,
}