-- #################################################################
-- ~/.config/nvim/lua/linters/pony-lint.lua
-- Qompass AI Diver Native Pony Linter
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
---@source https://www.ponylang.io/use/linting/
---@source https://www.ponylang.io/use/linting/rule-reference/
---@source https://github.com/ponylang/ponyc

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 4 * 1024 * 1024
local SOURCE = "pony-lint"

---@type string[]
local ROOT_MARKERS = {
  "corral.json",
  ".pony-lint.json",
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
local function zero_based(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local integer =
    math.floor(number)

  if integer <= 1 then
    return 0
  end

  return integer - 1
end

---@param value unknown
---@return integer
local function zero_based_column(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local integer =
    math.floor(number)

  if integer <= 1 then
    return 0
  end

  return integer - 1
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub(
    "\27%[[%d;]*[mK]",
    ""
  )
end

---@param path string
---@return string
local function normalize_path(path)
  if path == "" then
    return ""
  end

  return fs.normalize(path)
end

---@param context LintContext
---@return string
local function project_root(context)
  if nonempty_string(context.root) then
    return normalize_path(
      context.root
    )
  end

  if nonempty_string(context.filename) then
    --
    -- Prefer the Corral project root because pony-lint's documented
    -- configuration model treats corral.json as the project anchor.
    --
    local corral_root = fs.root(
      context.filename,
      {
        "corral.json",
      }
    )

    if
      type(corral_root) == "string"
      and corral_root ~= ""
    then
      return normalize_path(
        corral_root
      )
    end

    local git_root = fs.root(
      context.filename,
      {
        ".git",
      }
    )

    if
      type(git_root) == "string"
      and git_root ~= ""
    then
      return normalize_path(
        git_root
      )
    end

    local lint_root = fs.root(
      context.filename,
      {
        ".pony-lint.json",
      }
    )

    if
      type(lint_root) == "string"
      and lint_root ~= ""
    then
      return normalize_path(
        lint_root
      )
    end

    local parent =
      fs.dirname(
        context.filename
      )

    if
      type(parent) == "string"
      and parent ~= ""
    then
      return normalize_path(
        parent
      )
    end
  end

  if nonempty_string(context.cwd) then
    return normalize_path(
      context.cwd
    )
  end

  return normalize_path(
    vim.fn.getcwd()
  )
end

---@param rule string?
---@return integer
local function severity(rule)
  if rule == nil then
    return diagnostic.severity.WARN
  end

  if rule:find(
    "safety/",
    1,
    true
  ) == 1
  then
    return diagnostic.severity.ERROR
  end

  if rule:find(
    "lint/",
    1,
    true
  ) == 1
  then
    return diagnostic.severity.ERROR
  end

  if rule:find(
    "style/",
    1,
    true
  ) == 1
  then
    return diagnostic.severity.WARN
  end

  return diagnostic.severity.WARN
end

---@param value string?
---@return string?
local function normalize_rule(value)
  if not nonempty_string(value) then
    return nil
  end

  local rule = vim.trim(value)

  rule = rule:gsub(
    "^%[",
    ""
  )

  rule = rule:gsub(
    "%]$",
    ""
  )

  rule = rule:gsub(
    "^%(",
    ""
  )

  rule = rule:gsub(
    "%)$",
    ""
  )

  if
    rule:match(
      "^[%a][%w_-]*/[%w_-]+$"
    ) ~= nil
  then
    return rule
  end

  return nil
end

---@class PonyLintRecord
---@field column string?
---@field line string?
---@field message string
---@field path string?
---@field rule string?

---@param line string
---@return PonyLintRecord?
local function parse_record(line)
  local path
  local line_number
  local column
  local rest

  --
  -- Primary diagnostic shape:
  --
  --   path:line:column: ...
  --
  -- Pony's documentation guarantees file, line, and column information,
  -- but intentionally does not make this parser dependent on one exact
  -- message rendering.
  --
  path,
    line_number,
    column,
    rest =
    line:match(
      "^(.+):(%d+):(%d+):%s*(.+)$"
    )

  if
    path == nil
    or line_number == nil
    or column == nil
    or rest == nil
  then
    return nil
  end

  local rule
  local message

  --
  -- Form:
  --
  --   style/foo: diagnostic text
  --
  rule,
    message =
    rest:match(
      "^([%a][%w_-]*/[%w_-]+):%s*(.+)$"
    )

  if
    rule ~= nil
    and message ~= nil
  then
    return {
      column = column,

      line = line_number,

      message = message,

      path = path,

      rule = rule,
    }
  end

  --
  -- Form:
  --
  --   diagnostic text [style/foo]
  --
  message,
    rule =
    rest:match(
      "^(.-)%s+%[([%a][%w_-]*/[%w_-]+)%]%s*$"
    )

  if
    rule ~= nil
    and message ~= nil
  then
    return {
      column = column,

      line = line_number,

      message = message,

      path = path,

      rule = rule,
    }
  end

  --
  -- Form:
  --
  --   diagnostic text (style/foo)
  --
  message,
    rule =
    rest:match(
      "^(.-)%s+%(([%a][%w_-]*/[%w_-]+)%)%s*$"
    )

  if
    rule ~= nil
    and message ~= nil
  then
    return {
      column = column,

      line = line_number,

      message = message,

      path = path,

      rule = rule,
    }
  end

  return {
    column = column,

    line = line_number,

    message = rest,

    path = path,

    rule = nil,
  }
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

  return normalize_path(left)
    == normalize_path(right)
end

---@param record PonyLintRecord
---@param context LintContext
---@return vim.Diagnostic
local function record_diagnostic(
  record,
  context
)
  local rule =
    normalize_rule(
      record.rule
    )

  local lnum =
    zero_based(
      record.line
    )

  local col =
    zero_based_column(
      record.column
    )

  local message =
    compact(
      record.message
    )

  local record_path =
    record.path
      or ""

  if
    record_path ~= ""
    and context.filename ~= ""
    and not same_path(
      record_path,
      context.filename
    )
  then
    message = string.format(
      "%s: %s",
      record_path,
      message
    )

    --
    -- A diagnostic for .pony-lint.json, .ignore, or another auxiliary
    -- file cannot accurately be positioned in the current Pony buffer.
    --
    lnum = 0
    col = 0
  end

  message = truncate(
    message,
    MAX_MESSAGE_BYTES
  )

  return {
    bufnr = context.bufnr,

    code = rule,

    col = col,

    end_col = col,

    end_lnum = lnum,

    lnum = lnum,

    message = message,

    severity = severity(rule),

    source = SOURCE,

    user_data = {
      path =
        record.path,

      rule =
        rule,
    },
  }
end

---@param line string
---@return boolean
local function looks_operational(line)
  local lower =
    line:lower()

  return lower:find(
    "error",
    1,
    true
  ) ~= nil
    or lower:find(
      "unreadable",
      1,
      true
    ) ~= nil
    or lower:find(
      "malformed",
      1,
      true
    ) ~= nil
    or lower:find(
      "failed",
      1,
      true
    ) ~= nil
end

---@param line string
---@param context LintContext
---@return vim.Diagnostic
local function operational_diagnostic(
  line,
  context
)
  return {
    bufnr = context.bufnr,

    code = "lint/operational-error",

    col = 0,

    end_col = 0,

    end_lnum = 0,

    lnum = 0,

    message = truncate(
      compact(line),
      MAX_MESSAGE_BYTES
    ),

    severity =
      diagnostic.severity.ERROR,

    source = SOURCE,
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
  return {
    {
      bufnr = context.bufnr,

      code =
        "lint/output-limit",

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        "pony-lint output exceeded the %d-byte parser limit",
        MAX_OUTPUT_BYTES
      ),

      severity =
        diagnostic.severity.WARN,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(
    type(context) == "table",
    "pony-lint parser requires LintContext"
  )

  assert(
    type(context.bufnr) == "number",
    "pony-lint parser requires context.bufnr"
  )

  if output == "" then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(
      context
    )
  end

  local text =
    strip_ansi(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for raw_line in text:gmatch(
    "[^\r\n]+"
  ) do
    if
      #diagnostics
      >= MAX_DIAGNOSTICS
    then
      break
    end

    local line =
      vim.trim(raw_line)

    if line ~= "" then
      local record =
        parse_record(line)

      if record ~= nil then
        diagnostics[
          #diagnostics + 1
        ] = record_diagnostic(
          record,
          context
        )
      elseif looks_operational(line) then
        diagnostics[
          #diagnostics + 1
        ] = operational_diagnostic(
          line,
          context
        )
      end
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == "table",
    "pony-lint arguments require LintContext"
  )

  if
    not nonempty_string(
      context.filename
    )
  then
    return {}
  end

  --
  -- Do not pass --config here.
  --
  -- pony-lint's documented configuration discovery handles:
  --
  --   1. .pony-lint.json in cwd
  --   2. corral.json project roots
  --   3. hierarchical subdirectory .pony-lint.json overrides
  --
  -- Hard-coding one config path would defeat hierarchical configuration.
  --
  return {
    context.filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = true,

  cmd = "pony-lint",

  cwd = project_root,

  --
  -- pony-lint exit status:
  --
  --   0 = clean
  --   1 = lint violations
  --   2 = operational/configuration error
  --
  -- A status of 1 is expected when diagnostics exist, so the linter
  -- framework must still parse its output.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = "both",

  timeout = 30000,
}