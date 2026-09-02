-- #################################################################
-- ~/.config/nvim/lua/linters/glinter.lua
-- Qompass AI Diver Native Glinter Linter
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
---@source https://github.com/pairshaped/glinter
--
-- Installation:
--
--   cd /path/to/gleam/project
--   gleam add --dev glinter
--
-- Verify:
--
--   gleam run -m glinter --format json
--
-- Glinter is a Gleam project dependency rather than a standalone binary.
-- Diver therefore invokes:
--
--   gleam run -m glinter --format json <current-file>
--
-- from the nearest directory containing gleam.toml.
--
-- Configuration belongs in gleam.toml:
--
--   [tools.glinter]
--   warnings_as_errors = true
--
--   [tools.glinter.rules]
--   avoid_panic = "error"
--   avoid_todo = "error"
--   ...
--
-- Tiger policy:
--
--   * lint only the current Gleam source file in editor mode;
--   * preserve glinter's AST-based semantics;
--   * preserve project-local gleam.toml configuration;
--   * request structured JSON;
--   * retain rule names and severities;
--   * reject unbounded output;
--   * cap individual messages;
--   * cap total diagnostics;
--   * prevent cross-file positions from being attached to the current buffer;
--   * convert parser/configuration failures into diagnostics;
--   * avoid shell interpolation entirely;
--   * use Lua 5.1-compatible syntax for Neovim 0.13+.
--
-- Upstream exit behavior:
--
--   0 = no errors; warnings may still exist
--   1 = one or more error-severity findings
--
-- Therefore ignore_exitcode must be true.
--
-- Glinter currently provides rules covering:
--
--   error handling
--   debug/production artifacts
--   style
--   type annotations
--   complexity
--   labels
--   imports
--   cross-module unused exports
--   FFI safety
--   nolint hygiene
--
-- Project-level analysis such as unused_exports may naturally need a broader
-- invocation than the editor's current-file mode. Run:
--
--   gleam run -m glinter
--
-- separately for full-project linting.

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local MAX_PARSE_DEPTH = 6
local SOURCE = 'glinter'

---@type string[]
local ROOT_MARKERS = {
  'gleam.toml',
  'manifest.toml',
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
  return vim.trim(
    value:gsub(
      '%s+',
      ' '
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
  ) .. '...'
end

---@param value any
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

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub(
    '\27%[[%d;]*[mK]',
    ''
  )
end

---@param context LintContext
---@return string
local function project_root(context)
  local filename = string_value(
    context.filename
  )

  if filename ~= nil then
    --
    -- gleam.toml is authoritative for Glinter because the package dependency
    -- and [tools.glinter] configuration both live there.
    --
    local detected = fs.root(
      filename,
      {
        'gleam.toml',
      }
    )

    if
      type(detected) == 'string'
      and detected ~= ''
    then
      return fs.normalize(
        detected
      )
    end
  end

  local context_root = string_value(
    context.root
  )

  if context_root ~= nil then
    return fs.normalize(
      context_root
    )
  end

  if filename ~= nil then
    local detected = fs.root(
      filename,
      {
        '.git',
      }
    )

    if
      type(detected) == 'string'
      and detected ~= ''
    then
      return fs.normalize(
        detected
      )
    end

    local parent = fs.dirname(
      filename
    )

    if
      type(parent) == 'string'
      and parent ~= ''
    then
      return fs.normalize(
        parent
      )
    end
  end

  local cwd = string_value(
    context.cwd
  )

  if cwd ~= nil then
    return fs.normalize(
      cwd
    )
  end

  return fs.normalize(
    vim.fn.getcwd()
  )
end

---@param value string?
---@return integer
local function severity(value)
  if value == nil then
    return diagnostic.severity.WARN
  end

  local normalized = value:lower()

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

  if normalized == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@param path string
---@param context LintContext
---@return string
local function absolute_path(path, context)
  if path == '' then
    return ''
  end

  if fs.isabs(path) then
    return fs.normalize(
      path
    )
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
    left == ''
    or right == ''
  then
    return false
  end

  return fs.normalize(left)
    == fs.normalize(right)
end

---@class GlinterFinding
---@field file? string
---@field line? integer
---@field message? string
---@field rule? string
---@field severity? string

---@param value any
---@return boolean
local function finding_record(value)
  if type(value) ~= 'table' then
    return false
  end

  return string_value(value.message) ~= nil
    and (
      string_value(value.rule) ~= nil
      or value.line ~= nil
      or string_value(value.file) ~= nil
    )
end

---@param value any
---@param findings table[]
---@param depth integer
local function collect_findings(
  value,
  findings,
  depth
)
  if
    depth > MAX_PARSE_DEPTH
    or type(value) ~= 'table'
  then
    return
  end

  if finding_record(value) then
    findings[#findings + 1] = value

    return
  end

  --
  -- Current Glinter JSON uses:
  --
  --   {
  --     "results": [...],
  --     "summary": {...}
  --   }
  --
  -- Recursive collection makes the parser tolerant of a future wrapper
  -- object without treating summary/stats fields as diagnostics.
  --
  for _, child in pairs(value) do
    if type(child) == 'table' then
      collect_findings(
        child,
        findings,
        depth + 1
      )
    end
  end
end

---@param finding GlinterFinding
---@param context LintContext
---@return vim.Diagnostic?
local function finding_diagnostic(
  finding,
  context
)
  local message = string_value(
    finding.message
  )

  if message == nil then
    return nil
  end

  local lnum = zero_based_line(
    finding.line
  )

  local path = string_value(
    finding.file
  )

  if path ~= nil then
    local absolute = absolute_path(
      path,
      context
    )

    local filename = string_value(
      context.filename
    )

    if
      filename ~= nil
      and not same_path(
        absolute,
        fs.normalize(filename)
      )
    then
      --
      -- Glinter can perform project/cross-module analysis. Never attach
      -- another source file's line number to the current Neovim buffer.
      --
      message = string.format(
        '%s: %s',
        path,
        message
      )

      lnum = 0
    end
  end

  local rule = string_value(
    finding.rule
  )

  return {
    bufnr = context.bufnr,

    code = rule,

    col = 0,

    end_col = 0,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      compact(message),
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      string_value(
        finding.severity
      )
    ),

    source = SOURCE,

    user_data = {
      file = path,

      rule = rule,

      glinter_severity = string_value(
        finding.severity
      ),
    },
  }
end

---@param output string
---@return any?
local function decode_output(output)
  local text = vim.trim(
    output
  )

  if text == '' then
    return nil
  end

  local ok, decoded = pcall(
    json.decode,
    text
  )

  if not ok then
    return nil
  end

  return decoded
end

---@param output string
---@return string?
local function operational_message(output)
  local text = strip_ansi(
    vim.trim(output)
  )

  if text == '' then
    return nil
  end

  for raw_line in text:gmatch(
    '[^\r\n]+'
  ) do
    local line = compact(
      raw_line
    )

    local lower = line:lower()

    if
      lower:find(
        'error',
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
        'could not',
        1,
        true
      ) ~= nil
      or lower:find(
        'unknown',
        1,
        true
      ) ~= nil
      or lower:find(
        'invalid',
        1,
        true
      ) ~= nil
      or lower:find(
        'gleam.toml',
        1,
        true
      ) ~= nil
      or lower:find(
        'module',
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

  local first = text:match(
    '([^\r\n]+)'
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
      '[Ll]ine%s+(%d+)'
    )
      or output:match(
        ':(%d+):'
      )

  local lnum = zero_based_line(
    line_number
  )

  return {
    {
      bufnr = context.bufnr,

      code = 'glinter-error',

      col = 0,

      end_col = 0,

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

      code = 'output-limit',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        'Glinter output exceeded the %d-byte parser limit',
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
    'glinter parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'glinter parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(
      context
    )
  end

  local decoded = decode_output(
    output
  )

  if decoded == nil then
    return parse_failure(
      output,
      context
    )
  end

  ---@type table[]
  local findings = {}

  collect_findings(
    decoded,
    findings,
    0
  )

  if #findings == 0 then
    return {}
  end

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  for index = 1, #findings do
    if
      #diagnostics
      >= MAX_DIAGNOSTICS
    then
      break
    end

    local item = finding_diagnostic(
      findings[index],
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
    type(context) == 'table',
    'glinter arguments require LintContext'
  )

  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return {
      'run',

      '-m',
      'glinter',

      '--format',
      'json',
    }
  end

  return {
    'run',

    '-m',
    'glinter',

    '--format',
    'json',

    --
    -- Glinter accepts specific files/directories after its CLI options.
    -- Using one real file keeps automatic editor linting bounded while
    -- allowing project-wide linting to remain a separate workflow.
    --
    filename,
  }
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  --
  -- Glinter parses Gleam into an AST and may perform cross-module analysis.
  -- Keep it out of every-keystroke linting. Save/on-demand execution is a
  -- better editor policy.
  --
  automatic = false,

  cmd = 'gleam',

  cwd = project_root,

  --
  -- Glinter exits 1 when any error-severity finding exists. Warning-only
  -- runs remain exit 0. In either case, JSON diagnostics are authoritative.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  --
  -- Glinter operates on project/file paths and needs gleam.toml dependency
  -- resolution, so stdin is not appropriate.
  --
  stdin = false,

  stream = 'both',

  timeout = 60000,
}