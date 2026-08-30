-- #################################################################
-- /qompassai/Diver/lua/linters/cue.lua
-- Qompass AI Diver Native CUE Linter
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
---@source https://cuelang.org/docs/
---@source https://cuelang.org/docs/reference/command/cue-help-vet/

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'cue'

---@class CueLocation
---@field filename string
---@field line integer
---@field column integer

---@class CuePendingDiagnostic
---@field message string
---@field locations CueLocation[]

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

---@param value string
---@return CueLocation?
local function parse_location(value)
  assert(type(value) == 'string')

  value = trim(
    strip_ansi(value)
  )

  --
  -- CUE diagnostic positions conventionally use:
  --
  --   ./file.cue:12:9
  --
  -- or:
  --
  --   file.cue:12:9
  --
  -- Match greedily from the left so paths containing ':' remain usable.
  --
  local filename,
    line,
    column = value:match(
      '^(.+):(%d+):(%d+)%s*$'
    )

  if
    filename == nil
    or line == nil
    or column == nil
  then
    return nil
  end

  local parsed_line =
    integer(line, 0)

  local parsed_column =
    integer(column, 0)

  if
    parsed_line < 1
    or parsed_column < 1
  then
    return nil
  end

  return {
    filename = filename,
    line = parsed_line,
    column = parsed_column,
  }
end

---@param line string
---@return boolean
local function is_location_line(line)
  assert(type(line) == 'string')

  return parse_location(line) ~= nil
end

---@param line string
---@return boolean
local function is_continuation(line)
  assert(type(line) == 'string')

  --
  -- CUE prints source positions and additional explanation with indentation.
  --
  return line:match('^%s+') ~= nil
end

---@param pending CuePendingDiagnostic
---@param location CueLocation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function make_diagnostic(
  pending,
  location,
  filename,
  root
)
  if
    not belongs_to_buffer(
      location.filename,
      filename,
      root
    )
  then
    return nil
  end

  local lnum = max(
    location.line - 1,
    0
  )

  local col = max(
    location.column - 1,
    0
  )

  return {
    lnum = lnum,
    end_lnum = lnum,

    col = col,
    end_col = col + 1,

    message = pending.message,

    severity = ERROR,

    source = SOURCE,
    code = 'validation',

    user_data = {
      cue_location = location.filename,
    },
  }
end

---@param pending CuePendingDiagnostic?
---@param diagnostics vim.Diagnostic.Set[]
---@param filename string
---@param root string
local function flush_pending(
  pending,
  diagnostics,
  filename,
  root
)
  if pending == nil then
    return
  end

  if pending.message == '' then
    return
  end

  --
  -- CUE may report several source positions for a single failed unification:
  --
  --   area: invalid value ...
  --       ./example.cue:2:9
  --       ./example.cue:1:9
  --
  -- Each position is semantically meaningful, so preserve every location
  -- belonging to the active Neovim buffer.
  --
  for index = 1, #pending.locations do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local entry =
      make_diagnostic(
        pending,
        pending.locations[index],
        filename,
        root
      )

    if entry ~= nil then
      diagnostics[#diagnostics + 1] =
        entry
    end
  end
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
    'cue parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'cue output exceeded maximum size'
  )

  local filename =
    fs.normalize(context.filename)

  local root =
    fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  ---@type CuePendingDiagnostic?
  local pending = nil

  for raw_line in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    if #raw_line <= LINE_LENGTH_MAX then
      local line =
        strip_ansi(raw_line)

      local location =
        parse_location(line)

      if location ~= nil then
        if pending ~= nil then
          pending.locations[
            #pending.locations + 1
          ] = location
        end
      elseif is_continuation(line) then
        --
        -- Some CUE diagnostics include indented explanation lines that are
        -- not positions. Preserve them as context without allowing arbitrary
        -- output growth.
        --
        if
          pending ~= nil
          and not is_location_line(line)
        then
          local continuation =
            normalize_message(line)

          if continuation ~= '' then
            local combined =
              pending.message
              .. '\n'
              .. continuation

            if #combined <= MESSAGE_LENGTH_MAX then
              pending.message = combined
            end
          end
        end
      else
        --
        -- A non-indented, non-location line begins a new top-level CUE
        -- diagnostic.
        --
        flush_pending(
          pending,
          diagnostics,
          filename,
          root
        )

        local message =
          normalize_message(line)

        if message ~= '' then
          pending = {
            message = message,
            locations = {},
          }
        else
          pending = nil
        end
      end
    end
  end

  flush_pending(
    pending,
    diagnostics,
    filename,
    root
  )

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

  return {
    'vet',

    --
    -- Emit all available failures instead of stopping after the first error.
    -- This gives Neovim a complete diagnostic pass.
    --
    '--all-errors',

    --
    -- CUE files frequently contain schemas and definitions that are
    -- intentionally incomplete. Requiring concreteness during every editor
    -- lint pass would flag valid CUE source merely because it is a schema.
    --
    '--concrete=false',

    context.filename,
  }
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
  automatic = true,

  cmd = 'cue',

  args = args,

  append_fname = false,

  cwd = cwd,

  --
  -- `cue vet` is silent on success and returns nonzero when validation
  -- failures exist. Those failures are exactly what this adapter consumes.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    --
    -- Native CUE module boundary.
    --
    'cue.mod/module.cue',
    'cue.mod',

    --
    -- Common repository fallbacks.
    --
    'go.mod',
    'go.work',

    '.git',
  },

  stdin = false,

  --
  -- cue vet writes validation diagnostics to stderr.
  --
  stream = 'stderr',

  timeout = 60000,
}