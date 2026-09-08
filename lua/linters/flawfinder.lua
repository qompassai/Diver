-- #################################################################
-- ~/.config/nvim/lua/linters/flawfinder.lua
-- Qompass AI Diver Native Flawfinder Linter
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
---@source https://github.com/david-a-wheeler/flawfinder
---@source https://dwheeler.com/flawfinder/
--
-- Arch Linux:
--
--   sudo pacman -S flawfinder
--
-- Verify:
--
--   flawfinder --version
--
-- Flawfinder performs lexical security analysis of C/C++ source code.
-- It is complementary to compiler diagnostics, clang-tidy, cppcheck,
-- clangd, and other semantic/static-analysis tooling.
--
-- Tiger policy:
--
--   * analyze only the current source file;
--   * use machine-readable CSV output;
--   * request column-accurate diagnostics;
--   * suppress Flawfinder's human-oriented header/footer noise;
--   * retain source-level reviewed suppressions;
--   * reject unbounded parser output;
--   * cap individual diagnostic messages;
--   * cap total diagnostics;
--   * map Flawfinder's 0-5 risk model onto vim.diagnostic severity;
--   * preserve CWE/category/rule/fingerprint metadata;
--   * avoid shell execution and interpolation;
--   * remain compatible with Neovim's Lua 5.1 runtime contract.
--
-- Flawfinder risk model:
--
--   5 -> ERROR
--   4 -> ERROR
--   3 -> WARN
--   2 -> WARN
--   1 -> INFO
--   0 -> HINT
--
-- Editor mode intentionally honors:
--
--   /* Flawfinder: ignore */
--
-- For independent security auditing, run:
--
--   flawfinder --neverignore --minlevel=0 <path>
--
-- separately so deliberately reviewed editor suppressions can also be
-- audited.

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_CSV_FIELDS = 32
local MAX_DIAGNOSTICS = 512
local MAX_FIELD_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local MIN_RISK_LEVEL = 1
local SOURCE = 'flawfinder'

---@type string[]
local ROOT_MARKERS = {
  'CMakeLists.txt',
  'Makefile',
  'configure.ac',
  'meson.build',
  'premake5.lua',
  'xmake.lua',
  'build.zig',
  'compile_commands.json',
  '.clangd',
  '.git',
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

---@param value any
---@return integer
local function integer_value(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  return math.floor(number)
end

---@param value any
---@return integer
local function zero_based(value)
  local number = integer_value(value)

  if number <= 1 then
    return 0
  end

  return number - 1
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

  return fs.normalize(
    vim.fn.getcwd()
  )
end

---@param level integer
---@return integer
local function severity(level)
  if level >= 4 then
    return diagnostic.severity.ERROR
  end

  if level >= 2 then
    return diagnostic.severity.WARN
  end

  if level == 1 then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.HINT
end

---@param value string
---@return string
local function strip_bom(value)
  if value:sub(1, 3) == '\239\187\191' then
    return value:sub(4)
  end

  return value
end

---@param line string
---@return string[]
local function parse_csv_line(line)
  ---@type string[]
  local fields = {}

  local field = {}
  local index = 1
  local quoted = false

  while index <= #line do
    if #fields >= MAX_CSV_FIELDS then
      break
    end

    local character = line:sub(
      index,
      index
    )

    if quoted then
      if character == '"' then
        local next_character = line:sub(
          index + 1,
          index + 1
        )

        if next_character == '"' then
          if #field < MAX_FIELD_BYTES then
            field[#field + 1] = '"'
          end

          index = index + 2
        else
          quoted = false
          index = index + 1
        end
      else
        if #field < MAX_FIELD_BYTES then
          field[#field + 1] = character
        end

        index = index + 1
      end
    elseif character == '"' then
      quoted = true
      index = index + 1
    elseif character == ',' then
      fields[#fields + 1] = table.concat(field)
      field = {}
      index = index + 1
    else
      if #field < MAX_FIELD_BYTES then
        field[#field + 1] = character
      end

      index = index + 1
    end
  end

  fields[#fields + 1] = table.concat(field)

  return fields
end

---@param value string
---@return string[]
local function split_cwes(value)
  ---@type string[]
  local result = {}

  for cwe in value:gmatch('CWE%-?%d+') do
    result[#result + 1] = cwe
  end

  return result
end

---@param warning string
---@param suggestion string
---@return string
local function diagnostic_message(
  warning,
  suggestion
)
  local message = compact(warning)
  local fix = compact(suggestion)

  if fix ~= '' then
    message = string.format(
      '%s Suggestion: %s',
      message,
      fix
    )
  end

  return truncate(
    message,
    MAX_MESSAGE_BYTES
  )
end

---@class FlawfinderFinding
---@field category string
---@field column integer
---@field context string
---@field cwes string[]
---@field file string
---@field fingerprint string
---@field level integer
---@field line integer
---@field name string
---@field note string
---@field suggestion string
---@field warning string

---@param fields string[]
---@return FlawfinderFinding?
local function finding(fields)
  --
  -- Current Flawfinder CSV columns:
  --
  --   File
  --   Line
  --   Column
  --   Level
  --   Category
  --   Name
  --   Warning
  --   Suggestion
  --   Note
  --   CWEs
  --   Context
  --   Fingerprint
  --
  if #fields < 10 then
    return nil
  end

  local file = string_value(fields[1])
  local line = tonumber(fields[2])
  local level = tonumber(fields[4])

  if
    file == nil
    or line == nil
    or level == nil
  then
    return nil
  end

  return {
    category = fields[5] or '',

    column = integer_value(fields[3]),

    context = fields[11] or '',

    cwes = split_cwes(
      fields[10] or ''
    ),

    file = file,

    fingerprint = fields[12] or '',

    level = math.floor(level),

    line = math.floor(line),

    name = fields[6] or '',

    note = fields[9] or '',

    suggestion = fields[8] or '',

    warning = fields[7] or '',
  }
end

---@param path string
---@param context LintContext
---@return boolean
local function same_file(path, context)
  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return false
  end

  local candidate = path

  if not fs.isabs(candidate) then
    candidate = fs.joinpath(
      project_root(context),
      candidate
    )
  end

  return fs.normalize(candidate)
    == fs.normalize(filename)
end

---@param item FlawfinderFinding
---@param context LintContext
---@return vim.Diagnostic
local function make_diagnostic(
  item,
  context
)
  local lnum = zero_based(
    item.line
  )

  local col = zero_based(
    item.column
  )

  local message = diagnostic_message(
    item.warning,
    item.suggestion
  )

  if not same_file(item.file, context) then
    message = string.format(
      '%s: %s',
      item.file,
      message
    )

    lnum = 0
    col = 0
  end

  local code = string_value(
    item.name
  )

  if
    code == nil
    and #item.cwes > 0
  then
    code = item.cwes[1]
  end

  return {
    bufnr = context.bufnr,

    code = code,

    col = col,

    end_col = col,

    end_lnum = lnum,

    lnum = lnum,

    message = message,

    severity = severity(
      item.level
    ),

    source = SOURCE,

    user_data = {
      category = string_value(
        item.category
      ),

      context = string_value(
        item.context
      ),

      cwes = item.cwes,

      fingerprint = string_value(
        item.fingerprint
      ),

      level = item.level,

      note = string_value(
        item.note
      ),

      path = item.file,

      rule = string_value(
        item.name
      ),

      suggestion = string_value(
        item.suggestion
      ),
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
        'Flawfinder output exceeded the %d-byte parser limit',
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
    'flawfinder parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'flawfinder parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  output = strip_bom(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  local first_line = true

  for line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local fields = parse_csv_line(line)

    --
    -- --csv always emits a header row. Do not rely solely on its position,
    -- however, because defensive parsing costs essentially nothing.
    --
    local header = fields[1] == 'File'
      and fields[2] == 'Line'
      and fields[3] == 'Column'

    if not header then
      local item = finding(fields)

      if
        item ~= nil
        and item.level >= MIN_RISK_LEVEL
      then
        diagnostics[#diagnostics + 1] =
          make_diagnostic(
            item,
            context
          )
      end
    end

    first_line = false
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == 'table',
    'flawfinder arguments require LintContext'
  )

  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return {}
  end

  return {
    --
    -- CSV is Flawfinder's recommended machine-processing format.
    --
    '--csv',

    --
    -- Explicitly request columns even though current CSV output contains
    -- them. This documents our requirement and keeps editor intent clear.
    --
    '--columns',

    --
    -- Suppress status/progress output.
    --
    '--quiet',

    --
    -- Tiger's editor baseline reports risk level 1 and above.
    --
    '--minlevel='
      .. tostring(MIN_RISK_LEVEL),

    --
    -- Analyze exactly the current source file rather than recursively
    -- scanning the project on every editor lint invocation.
    --
    filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  --
  -- Flawfinder is security analysis rather than a lightweight syntax
  -- checker. Prefer save/on-demand execution instead of every keystroke.
  --
  automatic = false,

  cmd = 'flawfinder',

  cwd = project_root,

  --
  -- Flawfinder normally exits successfully even when findings exist.
  -- Keeping this enabled also prevents unusual scanner exit behavior from
  -- discarding already emitted diagnostics.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  --
  -- Flawfinder operates on paths and recursively handles directories.
  -- Passing the actual current filename also gives us stable locations and
  -- source fingerprints.
  --
  stdin = false,

  stream = 'both',

  timeout = 30000,
}