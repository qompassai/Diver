-- #################################################################
-- ~/.config/nvim/lua/linters/protolint.lua
-- Qompass AI Diver Native Protolint Linter
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
---@source https://github.com/yoheimuta/protolint
---@source https://github.com/yoheimuta/protolint#usage
---@source https://github.com/yoheimuta/protolint#reporters
---@source https://github.com/yoheimuta/protolint#configuring
--
-- Arch Linux installation:
--
--   paru -S protolint
--
-- or build the current upstream release/binary yourself and ensure:
--
--   command -v protolint
--
-- returns an executable available to Neovim.
--
-- Upstream configuration:
--
--   .protolint.yaml
--
-- is discovered automatically from the current working directory and then
-- through successive parent directories. This module deliberately does not
-- force -config_path so normal protolint project discovery remains intact.
--
-- Current protolint exit codes:
--
--   0 = lint completed with no violations
--   1 = lint completed with violations
--   2 = parse/internal/runtime/configuration error
--
-- Therefore ignore_exitcode must be true so exit code 1 output is still
-- parsed into diagnostics.
--
-- Neovim compatibility:
--
-- This file targets Neovim 0.13+ while remaining compatible with Neovim's
-- Lua 5.1 language contract:
--
--   * no Lua 5.2+ language syntax
--   * no goto
--   * no table.unpack dependency
--   * no utf8 library dependency
--   * no LuaJIT FFI/jit dependency
--   * no deprecated vim.loop usage
--
-- It uses current:
--
--   vim.diagnostic
--   vim.fs
--   vim.json
--
-- APIs only.

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 4 * 1024 * 1024
local SOURCE = "protolint"

---@type string[]
local ROOT_MARKERS = {
  ".protolint.yaml",
  ".protolint.yml",
  "buf.yaml",
  "buf.work.yaml",
  "proto",
  ".git",
}

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == "string"
    and value ~= ""
end

---@param value string
---@return string
local function compact(value)
  return vim.trim(
    value:gsub(
      "%s+",
      " "
    )
  )
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  if #value <= limit then
    return value
  end

  if limit <= 3 then
    return value:sub(
      1,
      limit
    )
  end

  return value:sub(
    1,
    limit - 3
  ) .. "..."
end

---@param value unknown
---@return integer
local function zero_based_line(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local line = math.floor(number)

  if line <= 1 then
    return 0
  end

  return line - 1
end

---@param value unknown
---@return integer
local function zero_based_col(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local col = math.floor(number)

  if col <= 1 then
    return 0
  end

  return col - 1
end

---@param value unknown
---@return string?
local function string_value(value)
  if type(value) ~= "string" then
    return nil
  end

  local result = vim.trim(value)

  if result == "" then
    return nil
  end

  return result
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub(
    "\27%[[%d;]*[mK]",
    ""
  )
end

---@param context LintContext
---@return string
local function project_root(context)
  if nonempty_string(context.root) then
    return fs.normalize(
      context.root
    )
  end

  if nonempty_string(context.filename) then
    --
    -- Prefer protolint's own project configuration when present so its
    -- documented upward .protolint.yaml discovery starts from the intended
    -- project.
    --
    local detected = fs.root(
      context.filename,
      {
        ".protolint.yaml",
        ".protolint.yml",
      }
    )

    if
      type(detected) == "string"
      and detected ~= ""
    then
      return fs.normalize(detected)
    end

    detected = fs.root(
      context.filename,
      {
        "buf.work.yaml",
        "buf.yaml",
        ".git",
      }
    )

    if
      type(detected) == "string"
      and detected ~= ""
    then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(
      context.filename
    )

    if
      type(parent) == "string"
      and parent ~= ""
    then
      return fs.normalize(parent)
    end
  end

  if nonempty_string(context.cwd) then
    return fs.normalize(
      context.cwd
    )
  end

  return fs.normalize(
    vim.fn.getcwd()
  )
end

---@param value unknown
---@return integer
local function severity(value)
  local name = string_value(value)

  if name == nil then
    return diagnostic.severity.WARN
  end

  name = name:lower()

  if
    name == "error"
    or name == "fatal"
  then
    return diagnostic.severity.ERROR
  end

  if
    name == "warning"
    or name == "warn"
  then
    return diagnostic.severity.WARN
  end

  if
    name == "note"
    or name == "info"
    or name == "information"
  then
    return diagnostic.severity.INFO
  end

  if name == "hint" then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@param path string
---@param context LintContext
---@return string
local function absolute_path(path, context)
  if path == "" then
    return ""
  end

  if fs.isabs(path) then
    return fs.normalize(path)
  end

  return fs.normalize(
    fs.joinpath(
      project_root(context),
      path
    )
  )
end

---@param left string
---@param right string
---@return boolean
local function same_path(left, right)
  if
    left == ""
    or right == ""
  then
    return false
  end

  return fs.normalize(left)
    == fs.normalize(right)
end

---@param value table
---@return string?
local function record_file(value)
  return string_value(value.file)
    or string_value(value.File)
    or string_value(value.path)
    or string_value(value.Path)
    or string_value(value.filename)
    or string_value(value.Filename)
end

---@param value table
---@return unknown
local function record_line(value)
  return value.line
    or value.Line
    or value.lineNumber
    or value.lineno
end

---@param value table
---@return unknown
local function record_column(value)
  return value.column
    or value.Column
    or value.col
    or value.columnNumber
end

---@param value table
---@return string?
local function record_rule(value)
  return string_value(value.rule)
    or string_value(value.Rule)
    or string_value(value.ruleId)
    or string_value(value.rule_id)
    or string_value(value.code)
    or string_value(value.Code)
end

---@param value table
---@return string?
local function record_message(value)
  return string_value(value.message)
    or string_value(value.Message)
    or string_value(value.reason)
    or string_value(value.description)
end

---@param value table
---@return unknown
local function record_severity(value)
  return value.severity
    or value.Severity
    or value.level
    or value.Level
end

---@param value table
---@return boolean
local function diagnostic_record(value)
  return record_message(value) ~= nil
    and (
      record_line(value) ~= nil
      or record_file(value) ~= nil
      or record_rule(value) ~= nil
    )
end

---@param value unknown
---@param records table[]
---@param depth integer
local function collect_records(
  value,
  records,
  depth
)
  if
    depth > 6
    or type(value) ~= "table"
  then
    return
  end

  if diagnostic_record(value) then
    records[#records + 1] = value

    return
  end

  for _, child in pairs(value) do
    if type(child) == "table" then
      collect_records(
        child,
        records,
        depth + 1
      )
    end
  end
end

---@param record table
---@param context LintContext
---@return vim.Diagnostic?
local function record_diagnostic(
  record,
  context
)
  local message = record_message(
    record
  )

  if message == nil then
    return nil
  end

  local rule = record_rule(
    record
  )

  local path = record_file(
    record
  )

  local lnum = zero_based_line(
    record_line(record)
  )

  local col = zero_based_col(
    record_column(record)
  )

  if path ~= nil then
    local normalized = absolute_path(
      path,
      context
    )

    if
      nonempty_string(context.filename)
      and not same_path(
        normalized,
        fs.normalize(context.filename)
      )
    then
      --
      -- File mode should normally return only diagnostics for the requested
      -- .proto file. Keep this guard nevertheless so plugin/config failures
      -- cannot place another file's coordinates inside the current buffer.
      --
      message = string.format(
        "%s: %s",
        path,
        message
      )

      lnum = 0
      col = 0
    end
  end

  return {
    bufnr = context.bufnr,

    code = rule,

    col = col,

    end_col = col,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      compact(message),
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      record_severity(record)
    ),

    source = SOURCE,

    user_data = {
      file = path,

      rule = rule,
    },
  }
end

---@param text string
---@return unknown?
local function decode_json(text)
  local trimmed = vim.trim(text)

  if trimmed == "" then
    return nil
  end

  local ok, decoded = pcall(
    json.decode,
    trimmed
  )

  if not ok then
    return nil
  end

  return decoded
end

---@param text string
---@return string?
local function operational_message(text)
  local cleaned = strip_ansi(
    vim.trim(text)
  )

  if cleaned == "" then
    return nil
  end

  --
  -- Do not turn arbitrary logging into diagnostics. Prefer lines that look
  -- like actual parser/config/runtime failures.
  --
  for line in cleaned:gmatch(
    "[^\r\n]+"
  ) do
    local normalized = compact(line)
    local lower = normalized:lower()

    if
      lower:find(
        "error",
        1,
        true
      ) ~= nil
      or lower:find(
        "failed",
        1,
        true
      ) ~= nil
      or lower:find(
        "invalid",
        1,
        true
      ) ~= nil
      or lower:find(
        "parse",
        1,
        true
      ) ~= nil
      or lower:find(
        "cannot",
        1,
        true
      ) ~= nil
    then
      return truncate(
        normalized,
        MAX_MESSAGE_BYTES
      )
    end
  end

  local first = cleaned:match(
    "([^\r\n]+)"
  )

  if first == nil then
    return nil
  end

  return truncate(
    compact(first),
    MAX_MESSAGE_BYTES
  )
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(
  output,
  context
)
  local message = operational_message(
    output
  )

  if message == nil then
    return {}
  end

  local line_number =
    output:match(
      "[Ll]ine%s+(%d+)"
    )
      or output:match(
        ":(%d+):%d+"
      )

  local column =
    output:match(
      ":%d+:(%d+)"
    )

  local lnum = zero_based_line(
    line_number
  )

  local col = zero_based_col(
    column
  )

  return {
    {
      bufnr = context.bufnr,

      code = "protolint-error",

      col = col,

      end_col = col,

      end_lnum = lnum,

      lnum = lnum,

      message = message,

      severity = diagnostic.severity.ERROR,

      source = SOURCE,
    },
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
  return {
    {
      bufnr = context.bufnr,

      code = "output-limit",

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        "protolint output exceeded the %d-byte parser limit",
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
local function parse(
  output,
  context
)
  assert(
    type(context) == "table",
    "protolint parser requires LintContext"
  )

  assert(
    type(context.bufnr) == "number",
    "protolint parser requires context.bufnr"
  )

  if output == "" then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(
      context
    )
  end

  local decoded = decode_json(
    output
  )

  if decoded == nil then
    return parse_failure(
      output,
      context
    )
  end

  ---@type table[]
  local records = {}

  collect_records(
    decoded,
    records,
    0
  )

  if #records == 0 then
    return {}
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for index = 1, #records do
    if
      #diagnostics
      >= MAX_DIAGNOSTICS
    then
      break
    end

    local item = record_diagnostic(
      records[index],
      context
    )

    if item ~= nil then
      diagnostics[
        #diagnostics + 1
      ] = item
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == "table",
    "protolint arguments require LintContext"
  )

  if not nonempty_string(
    context.filename
  ) then
    return {
      "lint",
      "-reporter",
      "json",
      "-no-error-on-unmatched-pattern",
    }
  end

  return {
    "lint",

    "-reporter",
    "json",

    "-no-error-on-unmatched-pattern",

    context.filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = true,

  cmd = "protolint",

  cwd = project_root,

  --
  -- protolint:
  --
  --   0 = successful, clean
  --   1 = successful, violations found
  --   2 = operational/parser/runtime error
  --
  -- Exit code 1 must not suppress parser execution.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = "both",

  timeout = 30000,
}