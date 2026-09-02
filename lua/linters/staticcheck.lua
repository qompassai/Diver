-- #################################################################
-- ~/.config/nvim/lua/linters/staticcheck.lua
-- Qompass AI Diver Native Staticcheck Linter
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
---@source https://staticcheck.dev/
---@source https://staticcheck.dev/docs/configuration/
---@source https://staticcheck.dev/docs/configuration/options/
---@source https://staticcheck.dev/docs/running-staticcheck/cli/
---@source https://staticcheck.dev/docs/running-staticcheck/cli/formatters/
--
-- Arch Linux:
--
--   sudo pacman -S staticcheck
--
-- or:
--
--   go install honnef.co/go/tools/cmd/staticcheck@latest
--
-- Tiger ownership policy:
--
--   staticcheck.lua
--     -> correctness / bug analysis only
--     -> SA* checks
--
--   revive
--     -> style / naming / documentation / idioms
--
--   gopls
--     -> compiler, types, editor analysis, refactoring
--     -> gopls.staticcheck = false
--
--   golangci-lint
--     -> aggregation / CI
--     -> do not enable its Staticcheck linter when standalone Staticcheck
--        diagnostics are also enabled in Neovim
--
-- Keeping Staticcheck restricted to SA* intentionally excludes:
--
--   S*   simplification
--   ST*  stylecheck
--   QF*  quick fixes
--   U*   unused declarations
--
-- This prevents the highest-value areas of overlap with revive, gopls'
-- editor-oriented modernization/style analyses, and other golangci-lint
-- linters.
--
-- Neovim compatibility:
--
-- This module targets Neovim 0.13+ and Neovim's Lua 5.1-compatible language
-- contract. It deliberately uses no Lua 5.2+ syntax, goto, FFI, jit APIs,
-- deprecated vim.loop aliases, or plugin APIs.

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = "staticcheck"

---@type string[]
local ROOT_MARKERS = {
  "staticcheck.conf",
  "go.work",
  "go.mod",
  ".git",
}

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == "string"
    and value ~= ""
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

  local integer = math.floor(number)

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

---@param context LintContext
---@return string
local function project_root(context)
  if nonempty_string(context.root) then
    return fs.normalize(
      context.root
    )
  end

  if nonempty_string(context.filename) then
    local detected = fs.root(
      context.filename,
      {
        "go.work",
        "go.mod",
        ".git",
      }
    )

    if
      type(detected) == "string"
      and detected ~= ""
    then
      return fs.normalize(
        detected
      )
    end

    local parent = fs.dirname(
      context.filename
    )

    if
      type(parent) == "string"
      and parent ~= ""
    then
      return fs.normalize(
        parent
      )
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

---@param context LintContext
---@return string
local function package_directory(context)
  if nonempty_string(context.filename) then
    local parent = fs.dirname(
      context.filename
    )

    if
      type(parent) == "string"
      and parent ~= ""
    then
      return fs.normalize(
        parent
      )
    end
  end

  return project_root(
    context
  )
end

---@param path string
---@param base string
---@return string
local function absolute_path(path, base)
  if path == "" then
    return ""
  end

  if fs.isabs(path) then
    return fs.normalize(
      path
    )
  end

  return fs.normalize(
    fs.joinpath(
      base,
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

---@param value unknown
---@return integer
local function severity(value)
  local name = string_value(
    value
  )

  if name == nil then
    return diagnostic.severity.WARN
  end

  name = name:lower()

  if name == "error" then
    return diagnostic.severity.ERROR
  end

  if name == "warning" then
    return diagnostic.severity.WARN
  end

  if name == "ignored" then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@class StaticcheckLocation
---@field file? string
---@field line? integer
---@field column? integer

---@class StaticcheckRecord
---@field code? string
---@field severity? string
---@field location? StaticcheckLocation
---@field end? StaticcheckLocation
---@field message? string

---@param value unknown
---@return StaticcheckRecord?
local function decode_record(value)
  if type(value) ~= "table" then
    return nil
  end

  local message = string_value(
    value.message
  )

  if message == nil then
    return nil
  end

  return value
end

---@param record StaticcheckRecord
---@param context LintContext
---@return vim.Diagnostic?
local function record_diagnostic(
  record,
  context
)
  local location = record.location

  if type(location) ~= "table" then
    return nil
  end

  local path = string_value(
    location.file
  )

  if path == nil then
    return nil
  end

  local package_root = package_directory(
    context
  )

  local absolute = absolute_path(
    path,
    package_root
  )

  --
  -- Staticcheck analyzes Go packages, not individual source files.
  --
  -- Running it for "." may therefore report diagnostics from sibling files
  -- in the same package. Our LintParser API attaches diagnostics to one
  -- buffer, so never place another source file's coordinates into the current
  -- buffer.
  --
  if
    not nonempty_string(context.filename)
    or not same_path(
      absolute,
      fs.normalize(context.filename)
    )
  then
    return nil
  end

  local lnum = zero_based(
    location.line
  )

  local col = zero_based(
    location.column
  )

  local end_lnum = lnum
  local end_col = col

  if type(record["end"]) == "table" then
    local finish = record["end"]

    if finish.line ~= nil then
      end_lnum = zero_based(
        finish.line
      )
    end

    if finish.column ~= nil then
      end_col = zero_based(
        finish.column
      )
    end
  end

  if
    end_lnum < lnum
    or (
      end_lnum == lnum
      and end_col < col
    )
  then
    end_lnum = lnum
    end_col = col
  end

  local message = string_value(
    record.message
  )

  if message == nil then
    return nil
  end

  return {
    bufnr = context.bufnr,

    code = string_value(
      record.code
    ),

    col = col,

    end_col = end_col,

    end_lnum = end_lnum,

    lnum = lnum,

    message = truncate(
      compact(message),
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      record.severity
    ),

    source = SOURCE,

    user_data = {
      check = string_value(
        record.code
      ),

      file = absolute,
    },
  }
end

---@param line string
---@return StaticcheckRecord?
local function parse_json_line(line)
  local text = vim.trim(
    line
  )

  if text == "" then
    return nil
  end

  local ok, decoded = pcall(
    json.decode,
    text
  )

  if not ok then
    return nil
  end

  return decode_record(
    decoded
  )
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

  for raw_line in cleaned:gmatch(
    "[^\r\n]+"
  ) do
    local line = compact(
      raw_line
    )

    local lower = line:lower()

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
        "cannot",
        1,
        true
      ) ~= nil
      or lower:find(
        "invalid",
        1,
        true
      ) ~= nil
      or lower:find(
        "compile",
        1,
        true
      ) ~= nil
      or lower:find(
        "package",
        1,
        true
      ) ~= nil
    then
      return truncate(
        line,
        MAX_MESSAGE_BYTES
      )
    end
  end

  return nil
end

---@param message string
---@param context LintContext
---@return vim.Diagnostic
local function operational_diagnostic(
  message,
  context
)
  return {
    bufnr = context.bufnr,

    code = "staticcheck-error",

    col = 0,

    end_col = 0,

    end_lnum = 0,

    lnum = 0,

    message = message,

    severity = diagnostic.severity.ERROR,

    source = SOURCE,
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
        "Staticcheck output exceeded the %d-byte parser limit",
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
    "staticcheck parser requires LintContext"
  )

  assert(
    type(context.bufnr) == "number",
    "staticcheck parser requires context.bufnr"
  )

  if output == "" then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(
      context
    )
  end

  local text = strip_ansi(
    output
  )

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  ---@type string[]
  local unparsed = {}

  --
  -- Staticcheck's JSON formatter is JSON Lines / NDJSON:
  --
  --   one complete JSON object per reported problem
  --
  -- It is intentionally not a JSON array.
  --
  for raw_line in text:gmatch(
    "[^\r\n]+"
  ) do
    if
      #diagnostics
      >= MAX_DIAGNOSTICS
    then
      break
    end

    local line = vim.trim(
      raw_line
    )

    if line ~= "" then
      local record = parse_json_line(
        line
      )

      if record ~= nil then
        --
        -- `ignored` normally appears only with -show-ignored. We don't pass
        -- that flag, but avoid producing an ignored diagnostic if upstream
        -- behavior or local wrappers change.
        --
        if record.severity ~= "ignored" then
          local item = record_diagnostic(
            record,
            context
          )

          if item ~= nil then
            diagnostics[
              #diagnostics + 1
            ] = item
          end
        end
      else
        unparsed[
          #unparsed + 1
        ] = line
      end
    end
  end

  if
    #diagnostics == 0
    and #unparsed > 0
  then
    local message = operational_message(
      table.concat(
        unparsed,
        "\n"
      )
    )

    if message ~= nil then
      diagnostics[1] = operational_diagnostic(
        message,
        context
      )
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == "table",
    "staticcheck arguments require LintContext"
  )

  return {
    --
    -- Machine-readable newline-delimited JSON.
    --
    "-f",
    "json",

    --
    -- Tiger ownership boundary:
    --
    -- Only Staticcheck SA correctness checks run here.
    --
    -- This keeps:
    --
    --   S*  simplifications
    --   ST* style
    --   QF* quick fixes
    --   U*  unused declarations
    --
    -- under gopls/revive/golangci policy instead.
    --
    "-checks",
    "SA*",

    --
    -- "." means the package containing the current file because cwd() below
    -- is set to that file's directory.
    --
    ".",
  }
end

---@param context LintContext
---@return string
local function cwd(context)
  return package_directory(
    context
  )
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  --
  -- Staticcheck performs whole-package SSA/type analysis. It is substantially
  -- heavier than a lexical linter and gopls already supplies live editor
  -- analysis.
  --
  -- Run this on demand or on your explicit lint-on-save pipeline instead of
  -- on every text change.
  --
  automatic = false,

  cmd = "staticcheck",

  cwd = cwd,

  --
  -- Staticcheck returns non-zero when findings are configured to fail the
  -- invocation. Diagnostics must still be parsed.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = "both",

  timeout = 60000,
}