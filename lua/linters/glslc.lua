-- #################################################################
-- ~/.config/nvim/lua/linters/glslc.lua
-- Qompass AI Diver GLSLC Linter
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
---@source https://github.com/google/shaderc
---@source https://github.com/google/shaderc/tree/main/glslc

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 256
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 4 * 1024 * 1024
local SOURCE = 'glslc'

---@type string[]
local ROOT_MARKERS = {
  'shaderc.json',
  'CMakeLists.txt',
  'meson.build',
  'BUILD',
  'BUILD.bazel',
  'WORKSPACE',
  'WORKSPACE.bazel',
  '.git',
}

---@type table<string, string>
local SHADER_STAGES = {
  ['.vert'] = 'vertex',
  ['.tesc'] = 'tesscontrol',
  ['.tese'] = 'tesseval',
  ['.geom'] = 'geometry',
  ['.frag'] = 'fragment',
  ['.comp'] = 'compute',

  ['.rgen'] = 'raygen',
  ['.rint'] = 'intersection',
  ['.rahit'] = 'anyhit',
  ['.rchit'] = 'closesthit',
  ['.rmiss'] = 'miss',
  ['.rcall'] = 'callable',

  ['.task'] = 'task',
  ['.mesh'] = 'mesh',
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

  local result = math.floor(number)

  if result <= 1 then
    return 0
  end

  return result - 1
end

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.ERROR
  end

  local normalized = level:lower()

  if normalized == 'fatal error' or normalized == 'error' then
    return diagnostic.severity.ERROR
  end

  if normalized == 'warning' then
    return diagnostic.severity.WARN
  end

  if normalized == 'note' then
    return diagnostic.severity.INFO
  end

  if normalized == 'info' then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.ERROR
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

---@param filename string
---@return string?
local function shader_stage(filename)
  local normalized = filename:lower()

  for extension, stage in pairs(SHADER_STAGES) do
    if normalized:sub(-#extension) == extension then
      return stage
    end
  end

  return nil
end

---@param context LintContext
---@return string[]
local function args(context)
  ---@type string[]
  local result = {
    '-c',

    -- Do not create a .spv artifact while linting.
    '-o',
    '/dev/null',
  }

  local filename = string_value(context.filename)

  if filename ~= nil then
    local stage = shader_stage(filename)

    if stage ~= nil then
      result[#result + 1] = '-fshader-stage=' .. stage
    end
  end

  -- glslc reads the current Neovim buffer from stdin. For generic `.glsl`
  -- files where no stage can be derived from the filename, glslc may still
  -- infer it from `#pragma shader_stage(...)` in the source.
  result[#result + 1] = '-'

  return result
end

---@param filename string?
---@param context LintContext
---@return boolean
local function diagnostic_belongs_to_buffer(filename, context)
  if filename == nil or filename == '' then
    return true
  end

  local normalized = filename:gsub('\\', '/')

  if
    normalized == '-'
    or normalized == '<stdin>'
    or normalized == 'stdin'
  then
    return true
  end

  local context_filename = string_value(context.filename)

  if context_filename == nil then
    return true
  end

  local target = fs.normalize(context_filename)
  local candidate = fs.normalize(filename)

  if candidate == target then
    return true
  end

  return fs.basename(candidate) == fs.basename(target)
end

---@param message string
---@return string?
local function diagnostic_code(message)
  local code = message:match('%[([%w_.%-]+)%]%s*$')

  if code ~= nil and code ~= '' then
    return code
  end

  return nil
end

---@param message string
---@return string
local function clean_message(message)
  local normalized = compact(message)

  normalized = normalized:gsub(
    '%s*%[[%w_.%-]+%]%s*$',
    ''
  )

  return truncate(
    normalized,
    MAX_MESSAGE_BYTES
  )
end

---@param filename string?
---@param line string?
---@param column string?
---@param level string?
---@param message string
---@param context LintContext
---@return vim.Diagnostic?
local function make_diagnostic(
  filename,
  line,
  column,
  level,
  message,
  context
)
  if not diagnostic_belongs_to_buffer(filename, context) then
    return nil
  end

  local lnum = zero_based(line)
  local col = zero_based_column(column)
  local text = clean_message(message)

  if text == '' then
    return nil
  end

  return {
    bufnr = context.bufnr,

    code = diagnostic_code(message),

    col = col,

    end_col = col,

    end_lnum = lnum,

    lnum = lnum,

    message = text,

    severity = severity(level),

    source = SOURCE,
  }
end

---@param line string
---@param context LintContext
---@return vim.Diagnostic?
local function parse_diagnostic_line(line, context)
  local text = vim.trim(line)

  if text == '' then
    return nil
  end

  -- Typical glslc/glslang form:
  --
  --   file.vert:12:5: error: syntax error
  --   file.vert:12: warning: message
  --   -:12:5: error: message
  --
  -- Parse the most precise form first.
  local filename,
    line_number,
    column_number,
    level,
    message = text:match(
      '^(.+):(%d+):(%d+):%s*'
        .. '(fatal error|error|warning|note|info):%s*(.+)$'
    )

  if message ~= nil then
    return make_diagnostic(
      filename,
      line_number,
      column_number,
      level,
      message,
      context
    )
  end

  filename,
    line_number,
    level,
    message = text:match(
      '^(.+):(%d+):%s*'
        .. '(fatal error|error|warning|note|info):%s*(.+)$'
    )

  if message ~= nil then
    return make_diagnostic(
      filename,
      line_number,
      nil,
      level,
      message,
      context
    )
  end

  -- Some glslang-originated messages include a numeric source-string
  -- identifier rather than a normal filename:
  --
  --   ERROR: 0:12: 'foo' : undeclared identifier
  --   WARNING: 0:4: extension ...
  local upper_level,
    source_id,
    glslang_line,
    glslang_message = text:match(
      '^(ERROR|WARNING|INFO|NOTE):%s*'
        .. '([^:]+):(%d+):%s*(.+)$'
    )

  if glslang_message ~= nil then
    local normalized_level

    if upper_level == 'ERROR' then
      normalized_level = 'error'
    elseif upper_level == 'WARNING' then
      normalized_level = 'warning'
    elseif upper_level == 'NOTE' then
      normalized_level = 'note'
    else
      normalized_level = 'info'
    end

    local diagnostic_item = make_diagnostic(
      nil,
      glslang_line,
      nil,
      normalized_level,
      glslang_message,
      context
    )

    if diagnostic_item ~= nil then
      diagnostic_item.user_data = {
        source_id = source_id,
      }
    end

    return diagnostic_item
  end

  -- Driver-level diagnostics do not always contain a source position:
  --
  --   glslc: error: ...
  --   glslc: warning: ...
  local driver_level,
    driver_message = text:match(
      '^glslc:%s*'
        .. '(fatal error|error|warning|note|info):%s*(.+)$'
    )

  if driver_message ~= nil then
    return make_diagnostic(
      nil,
      nil,
      nil,
      driver_level,
      driver_message,
      context
    )
  end

  return nil
end

---@param output string
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
        'glslc output exceeded the %d-byte parser limit',
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
    'glslc parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'glslc parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local text = strip_ansi(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for line in text:gmatch('[^\r\n]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local item = parse_diagnostic_line(
      line,
      context
    )

    if item ~= nil then
      diagnostics[#diagnostics + 1] = item
    end
  end

  -- If glslc failed but emitted an unfamiliar diagnostic format, retain the
  -- first meaningful line rather than silently discarding the compiler error.
  if #diagnostics == 0 then
    for line in text:gmatch('[^\r\n]+') do
      local message = compact(line)

      if message ~= '' then
        diagnostics[1] = {
          bufnr = context.bufnr,

          code = 'compiler',

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
        }

        break
      end
    end
  end

  return diagnostics
end

---@type Linter
return {
  args = args,

  append_fname = false,

  automatic = false,

  cmd = 'glslc',

  cwd = project_root,

  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'both',

  timeout = 30000,
}