-- #################################################################
-- ~/.config/nvim/lua/linters/html-tidy.lua
-- Qompass AI Diver Native HTML Tidy Linter
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
---@source https://www.html-tidy.org/
---@source https://www.html-tidy.org/documentation/
---@source https://api.html-tidy.org/tidy/quickref_5.8.0.html
--
-- Arch Linux:
--
--   sudo pacman -S tidy
--
-- Verify:
--
--   tidy -version
--
-- Tiger-style policy:
--
--   * lint unsaved buffer contents through stdin;
--   * suppress repaired markup entirely;
--   * request warnings and errors only;
--   * expose upstream message IDs for diagnostic codes;
--   * raise Tidy's default six-error cap;
--   * bound diagnostics, lines, messages, and total output ourselves;
--   * never modify files;
--   * never force Tidy's formatter/cleanup output into the buffer;
--   * preserve project-level HTML_TIDY/config policy when supplied externally;
--   * remain Lua 5.1-compatible for Neovim 0.13+.
--
-- Tidy exit status:
--
--   0 = no warnings or errors
--   1 = warnings, no errors
--   2 = errors, possibly warnings
--  <0 = severe runtime/system error
--
-- Therefore `ignore_exitcode = true` is required so warnings/errors are
-- parsed instead of being treated as process failures.

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 512
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 4 * 1024 * 1024
local SOURCE = 'html-tidy'
local TIDY_SHOW_ERRORS = 512

---@type string[]
local ROOT_MARKERS = {
  'tidy.conf',
  '.tidyrc',
  '.htmltidy',
  'package.json',
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
  return output:gsub('\27%[[%d;]*[mK]', '')
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

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.WARN
  end

  local normalized = level:lower()

  if normalized == 'error' then
    return diagnostic.severity.ERROR
  end

  if
    normalized == 'warning'
    or normalized == 'warn'
  then
    return diagnostic.severity.WARN
  end

  if
    normalized == 'info'
    or normalized == 'information'
  then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.WARN
end

---@class HtmlTidyFinding
---@field code string?
---@field column integer
---@field line integer
---@field message string
---@field severity string

---@param line string
---@return HtmlTidyFinding?
local function parse_finding(line)
  if line == '' or #line > MAX_LINE_BYTES then
    return nil
  end

  local line_number
  local column
  local level
  local code
  local message

  --
  -- With:
  --
  --   --mute-id yes
  --
  -- modern Tidy can emit the message ID alongside the report. Be tolerant of
  -- multiple placements because distributions/builds can differ slightly.
  --
  -- Examples accepted:
  --
  --   line 4 column 1 - Warning: [MISSING_TITLE_ELEMENT] inserting ...
  --   line 4 column 1 - Warning: inserting ... [MISSING_TITLE_ELEMENT]
  --   line 4 column 1 - Warning: inserting ...
  --
  line_number,
    column,
    level,
    code,
    message =
    line:match(
      '^line%s+(%d+)%s+column%s+(%d+)%s+%-%s+([%a]+):%s+%[([^%]]+)%]%s*(.+)$'
    )

  if
    line_number ~= nil
    and column ~= nil
    and level ~= nil
    and message ~= nil
  then
    return {
      code = code,

      column = tonumber(column) or 1,

      line = tonumber(line_number) or 1,

      message = message,

      severity = level,
    }
  end

  line_number,
    column,
    level,
    message,
    code =
    line:match(
      '^line%s+(%d+)%s+column%s+(%d+)%s+%-%s+([%a]+):%s+(.+)%s+%[([^%]]+)%]$'
    )

  if
    line_number ~= nil
    and column ~= nil
    and level ~= nil
    and message ~= nil
  then
    return {
      code = code,

      column = tonumber(column) or 1,

      line = tonumber(line_number) or 1,

      message = message,

      severity = level,
    }
  end

  line_number,
    column,
    level,
    message =
    line:match(
      '^line%s+(%d+)%s+column%s+(%d+)%s+%-%s+([%a]+):%s+(.+)$'
    )

  if
    line_number == nil
    or column == nil
    or level == nil
    or message == nil
  then
    return nil
  end

  return {
    code = nil,

    column = tonumber(column) or 1,

    line = tonumber(line_number) or 1,

    message = message,

    severity = level,
  }
end

---@param finding HtmlTidyFinding
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(
  finding,
  context
)
  local lnum = zero_based(
    finding.line
  )

  local col = zero_based(
    finding.column
  )

  return {
    bufnr = context.bufnr,

    code = string_value(
      finding.code
    ),

    col = col,

    end_col = col,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      compact(finding.message),
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      finding.severity
    ),

    source = SOURCE,

    user_data = {
      message_id = finding.code,

      tidy_severity = finding.severity,
    },
  }
end

---@param line string
---@return boolean
local function operational_error(line)
  local lower = line:lower()

  return lower:find(
    'error:',
    1,
    true
  ) ~= nil
    or lower:find(
      'failed',
      1,
      true
    ) ~= nil
    or lower:find(
      'cannot',
      1,
      true
    ) ~= nil
    or lower:find(
      'unknown option',
      1,
      true
    ) ~= nil
    or lower:find(
      'config',
      1,
      true
    ) ~= nil
end

---@param output string
---@return string?
local function error_message(output)
  local text = strip_ansi(
    vim.trim(output)
  )

  if text == '' then
    return nil
  end

  for line in text:gmatch('[^\r\n]+') do
    local normalized = compact(line)

    if operational_error(normalized) then
      return truncate(
        normalized,
        MAX_MESSAGE_BYTES
      )
    end
  end

  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(
  output,
  context
)
  local message = error_message(output)

  if message == nil then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,

      code = 'tidy-error',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

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

      code = 'output-limit',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        'HTML Tidy output exceeded the %d-byte parser limit',
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
    'html-tidy parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'html-tidy parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(
      context
    )
  end

  local text = strip_ansi(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  ---@type string[]
  local unparsed = {}

  for raw_line in text:gmatch('[^\r\n]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local line = vim.trim(raw_line)

    if line ~= '' then
      local finding = parse_finding(line)

      if finding ~= nil then
        diagnostics[#diagnostics + 1] =
          finding_diagnostic(
            finding,
            context
          )
      elseif operational_error(line) then
        unparsed[#unparsed + 1] = line
      end
    end
  end

  if
    #diagnostics == 0
    and #unparsed > 0
  then
    return parse_failure(
      table.concat(
        unparsed,
        '\n'
      ),
      context
    )
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == 'table',
    'html-tidy arguments require LintContext'
  )

  return {
    --
    -- Do not emit cleaned/repaired HTML. This is a linter invocation, not a
    -- formatter invocation.
    --
    '--markup',
    'no',

    --
    -- Suppress summaries, banners, and nonessential informational output.
    --
    '--quiet',
    'yes',

    --
    -- Keep warnings. They are useful lint diagnostics.
    --
    '--show-warnings',
    'yes',

    --
    -- Tidy defaults to showing only six errors. Raise that limit and let the
    -- Tiger parser's MAX_DIAGNOSTICS enforce the real editor-side bound.
    --
    '--show-errors',
    tostring(TIDY_SHOW_ERRORS),

    --
    -- Expose stable upstream diagnostic/message identifiers when supported.
    --
    '--mute-id',
    'yes',

    --
    -- `stdin` is intentional. With no filename argument, Tidy reads current
    -- unsaved buffer contents directly from stdin.
    --
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  automatic = true,

  cmd = 'tidy',

  cwd = project_root,

  --
  -- Tidy documents:
  --
  --   0 = clean
  --   1 = warnings
  --   2 = errors
  --
  -- Both 1 and 2 contain valid diagnostics.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  --
  -- Diagnostic output is normally written to stderr. `both` also protects
  -- against wrappers/distributions that redirect it to stdout.
  --
  stream = 'both',

  timeout = 30000,
}