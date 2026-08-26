-- #################################################################
-- /qompassai/Diver/lua/linters/redocly.lua
-- Qompass AI Redocly CLI Linter
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
---@source https://github.com/Redocly/redocly-cli
---@source https://redocly.com/docs/cli/commands/lint

local diagnostic = vim.diagnostic
local fs = vim.fs
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
local tonumber = tonumber
local type = type

---@type table<string, integer>
local severities = {
  error = ERROR,
  fatal = ERROR,

  warn = WARN,
  warning = WARN,

  info = INFO,
  information = INFO,

  hint = HINT,
  note = HINT,
}

---@type string[]
local config_candidates = {
  'redocly.yaml',
  'redocly.yml',

  '.redocly.yaml',
  '.redocly.yml',

  'redocly.json',

  'config/redocly.yaml',
  'config/redocly.yml',

  '.config/redocly.yaml',
  '.config/redocly.yml',
}

---@class RedoclyCheckstyleEntry
---@field filename string
---@field line integer
---@field column integer
---@field severity string
---@field message string
---@field source? string

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

---@param root string
---@param candidates string[]
---@return string?
local function find_candidate(root, candidates)
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

---@param value string
---@return string
local function xml_decode(value)
  --
  -- Decode the five predefined XML entities first. Numeric entities are
  -- handled separately below.
  --
  value = value:gsub('&quot;', '"')
  value = value:gsub('&apos;', "'")
  value = value:gsub('&lt;', '<')
  value = value:gsub('&gt;', '>')
  value = value:gsub('&amp;', '&')

  --
  -- Decimal numeric character references.
  --
  value = value:gsub(
    '&#(%d+);',
    function(number)
      local codepoint = tonumber(number)

      if
        codepoint == nil
        or codepoint < 0
        or codepoint > 0x10FFFF
        or (
          codepoint >= 0xD800
          and codepoint <= 0xDFFF
        )
      then
        return ''
      end

      local ok, character = pcall(
        utf8.char,
        codepoint
      )

      if
        not ok
        or type(character) ~= 'string'
      then
        return ''
      end

      return character
    end
  )

  --
  -- Hexadecimal numeric character references.
  --
  value = value:gsub(
    '&#[xX]([%x]+);',
    function(number)
      local codepoint = tonumber(number, 16)

      if
        codepoint == nil
        or codepoint < 0
        or codepoint > 0x10FFFF
        or (
          codepoint >= 0xD800
          and codepoint <= 0xDFFF
        )
      then
        return ''
      end

      local ok, character = pcall(
        utf8.char,
        codepoint
      )

      if
        not ok
        or type(character) ~= 'string'
      then
        return ''
      end

      return character
    end
  )

  return value
end

---@param value string
---@return string
local function normalize_message(value)
  value = xml_decode(value)

  value = value:gsub('\r\n', '\n')
  value = value:gsub('\r', '\n')

  if #value > MESSAGE_LENGTH_MAX then
    value =
      value:sub(1, MESSAGE_LENGTH_MAX)
      .. '\n[message truncated]'
  end

  return value
end

---@param attributes string
---@param name string
---@return string?
local function attribute(attributes, name)
  assert(name ~= '')

  --
  -- Checkstyle output uses double-quoted XML attributes.
  --
  -- Do not attempt to parse arbitrary XML here; Redocly emits a deliberately
  -- tiny and stable Checkstyle document and each diagnostic is represented by
  -- a self-contained <error ... /> element.
  --
  local pattern =
    '%f[%w]'
    .. name
    .. '%s*=%s*"([^"]*)"'

  local value = attributes:match(pattern)

  if value == nil then
    return nil
  end

  return xml_decode(value)
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
    fs.joinpath(root, path)
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

---@param attributes string
---@param file string
---@return RedoclyCheckstyleEntry?
local function checkstyle_entry(
  attributes,
  file
)
  assert(file ~= '')

  local message =
    attribute(attributes, 'message')

  if
    message == nil
    or message == ''
  then
    return nil
  end

  local source =
    attribute(attributes, 'source')

  local level =
    attribute(attributes, 'severity')
    or 'warning'

  return {
    filename = file,

    line = max(
      integer(
        attribute(attributes, 'line'),
        1
      ),
      1
    ),

    column = max(
      integer(
        attribute(attributes, 'column'),
        1
      ),
      1
    ),

    severity = level,
    message = normalize_message(message),
    source = source,
  }
end

---@param entry RedoclyCheckstyleEntry
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
  -- Checkstyle coordinates are one-based.
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

  local code = entry.source

  if
    type(code) ~= 'string'
    or code == ''
  then
    code = nil
  end

  return {
    lnum = lnum,
    end_lnum = lnum,

    col = col,

    --
    -- Checkstyle doesn't expose an end position. Highlight one byte rather
    -- than inventing a source range Redocly did not report.
    --
    end_col = col + 1,

    message = entry.message,

    severity = severity(
      entry.severity
    ),

    source = 'redocly',
    code = code,

    user_data = {
      rule = code,
      severity = entry.severity,
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
    'redocly parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'redocly output exceeded maximum size'
  )

  local filename =
    fs.normalize(context.filename)

  local root =
    fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  --
  -- Redocly Checkstyle output has the form:
  --
  --   <file name="...">
  --     <error ... />
  --   </file>
  --
  -- Parse each file block independently. This prevents an <error> element
  -- belonging to a referenced document from being incorrectly attributed to
  -- the current buffer.
  --
  for file_attributes, body in output:gmatch(
    '<file%s+([^>]-)>(.-)</file>'
  ) do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local file =
      attribute(file_attributes, 'name')

    if
      file ~= nil
      and file ~= ''
    then
      for error_attributes in body:gmatch(
        '<error%s+([^>]-)/>'
      ) do
        if #diagnostics >= DIAGNOSTICS_MAX then
          break
        end

        local raw =
          checkstyle_entry(
            error_attributes,
            file
          )

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

  local argv = {
    'lint',

    context.filename,

    '--format=checkstyle',

    --
    -- Redocly defaults to only 100 displayed problems. An editor linter
    -- should not silently hide diagnostics merely because a document happens
    -- to exceed that CLI-oriented presentation limit.
    --
    '--max-problems=' .. DIAGNOSTICS_MAX,

    --
    -- Treat malformed Redocly project configuration as a real lint problem.
    --
    '--lint-config=error',
  }

  return argv
end

return ---@type Linter
{
  automatic = false,

  cmd = 'redocly',

  args = args,

  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')

    return context.root
  end,

  --
  -- Redocly returns a nonzero status when lint errors are present. Those
  -- errors are exactly what this adapter needs to turn into diagnostics.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    'redocly.yaml',
    'redocly.yml',

    '.redocly.yaml',
    '.redocly.yml',

    'redocly.json',

    'config/redocly.yaml',
    'config/redocly.yml',

    '.config/redocly.yaml',
    '.config/redocly.yml',

    '.redocly.lint-ignore.yaml',

    'openapi.yaml',
    'openapi.yml',
    'openapi.json',

    'asyncapi.yaml',
    'asyncapi.yml',
    'asyncapi.json',

    'arazzo.yaml',
    'arazzo.yml',
    'arazzo.json',

    'package.json',

    '.git',
  },

  stdin = false,
  stream = 'stdout',
  timeout = 60000,
}