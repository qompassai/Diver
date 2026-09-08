-- #################################################################
-- ~/.config/nvim/lua/linters/vsg.lua
-- Qompass AI Diver Native VHDL Style Guide Linter
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
---@source https://github.com/jeremiah-c-leary/vhdl-style-guide
---@source https://vhdl-style-guide.readthedocs.io/en/latest/usage.html
---@source https://vhdl-style-guide.readthedocs.io/en/latest/formatting_terminal_output.html
--
-- Installation:
--
--   python -m pip install --user vsg
--
-- or preferably in an isolated Python environment/tool manager:
--
--   pipx install vsg
--
-- Verify:
--
--   vsg --version
--
-- Tiger policy:
--
--   * lint unsaved VHDL through stdin;
--   * use VSG's documented editor-oriented syntastic output;
--   * run all lint phases instead of stopping at the first failing phase;
--   * retain VSG rule IDs as vim.Diagnostic codes;
--   * preserve VSG warning/error severity;
--   * bound output, line size, message size, and diagnostic count;
--   * treat operational/configuration failures separately;
--   * never invoke --fix from the linter;
--   * leave rule policy in VSG JSON/YAML configuration files;
--   * use Lua 5.1-compatible syntax for Neovim 0.13+.
--
-- VSG exit codes:
--
--   0 = clean
--   1 = rule violation detected
--   2 = deprecated rule configured
--
-- Therefore ignore_exitcode must remain true.
--
-- VSG supports VHDL style enforcement but upstream still documents parser
-- limitations such as embedded PSL and VHDL-2019 coverage. Keep semantic/
-- language diagnostics in a VHDL LSP/compiler rather than trying to make VSG
-- replace them.

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 512
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'vsg'

---@type string[]
local ROOT_MARKERS = {
  'vsg.yaml',
  'vsg.yml',
  'vsg.json',
  '.vsg.yaml',
  '.vsg.yml',
  '.vsg.json',
  'vsg_config.yaml',
  'vsg_config.yml',
  'vsg_config.json',
  'hdl-prj.json',
  'vhdl_ls.toml',
  'Makefile',
  'CMakeLists.txt',
  '.git',
}

---@type string[]
local CONFIG_NAMES = {
  'vsg.yaml',
  'vsg.yml',
  'vsg.json',
  '.vsg.yaml',
  '.vsg.yml',
  '.vsg.json',
  'vsg_config.yaml',
  'vsg_config.yml',
  'vsg_config.json',
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

---@param path string
---@return boolean
local function is_file(path)
  local stat = vim.uv.fs_stat(path)

  return stat ~= nil
    and stat.type == 'file'
end

---@param context LintContext
---@return string
local function project_root(context)
  local context_root = string_value(
    context.root
  )

  if context_root ~= nil then
    return fs.normalize(
      context_root
    )
  end

  local filename = string_value(
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

---@param context LintContext
---@return string?
local function configuration(context)
  local root = project_root(
    context
  )

  for _, name in ipairs(CONFIG_NAMES) do
    local candidate = fs.joinpath(
      root,
      name
    )

    if is_file(candidate) then
      return candidate
    end
  end

  return nil
end

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.ERROR
  end

  local normalized = level:upper()

  if normalized == 'ERROR' then
    return diagnostic.severity.ERROR
  end

  if normalized == 'WARNING' then
    return diagnostic.severity.WARN
  end

  return diagnostic.severity.ERROR
end

---@class VsgFinding
---@field line integer
---@field message string
---@field path string
---@field rule string
---@field severity string

---@param line string
---@return VsgFinding?
local function parse_syntastic_line(line)
  if
    line == ''
    or #line > MAX_LINE_BYTES
  then
    return nil
  end

  --
  -- Official VSG syntastic format:
  --
  --   <status>: <filename>(<line_number>)<rule> -- <solution>
  --
  -- Example:
  --
  --   ERROR: src/foo.vhd(38)entity_017 -- Move : -1 columns
  --
  local level
  local path
  local line_number
  local rule
  local message

  level,
    path,
    line_number,
    rule,
    message =
    line:match(
      '^([A-Z]+):%s+(.+)%((%d+)%)'
        .. '([%w_]+)%s+%-%-%s+(.+)$'
    )

  if
    level == nil
    or path == nil
    or line_number == nil
    or rule == nil
    or message == nil
  then
    return nil
  end

  return {
    line = tonumber(line_number) or 1,

    message = message,

    path = path,

    rule = rule,

    severity = level,
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

---@param finding VsgFinding
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(
  finding,
  context
)
  local lnum = zero_based_line(
    finding.line
  )

  local message = compact(
    finding.message
  )

  if not same_file(
    finding.path,
    context
  ) then
    message = string.format(
      '%s: %s',
      finding.path,
      message
    )

    lnum = 0
  end

  return {
    bufnr = context.bufnr,

    code = finding.rule,

    col = 0,

    end_col = 0,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      message,
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      finding.severity
    ),

    source = SOURCE,

    user_data = {
      path = finding.path,

      rule = finding.rule,

      vsg_severity = finding.severity,
    },
  }
end

---@param line string
---@return boolean
local function operational_error(line)
  local lower = line:lower()

  return lower:find(
    'deprecated',
    1,
    true
  ) ~= nil
    or lower:find(
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
      'invalid',
      1,
      true
    ) ~= nil
    or lower:find(
      'cannot',
      1,
      true
    ) ~= nil
    or lower:find(
      'configuration',
      1,
      true
    ) ~= nil
    or lower:find(
      'traceback',
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

  for raw_line in text:gmatch(
    '[^\r\n]+'
  ) do
    local line = compact(
      raw_line
    )

    if operational_error(line) then
      return truncate(
        line,
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
  local message = error_message(
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
        '%((%d+)%)'
      )

  local lnum = zero_based_line(
    line_number
  )

  return {
    {
      bufnr = context.bufnr,

      code = 'vsg-error',

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
        'VSG output exceeded the %d-byte parser limit',
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
    'vsg parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'vsg parser requires context.bufnr'
  )

  if output == '' then
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
  local failures = {}

  for raw_line in text:gmatch(
    '[^\r\n]+'
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

    if line ~= '' then
      local finding = parse_syntastic_line(
        line
      )

      if finding ~= nil then
        diagnostics[
          #diagnostics + 1
        ] = finding_diagnostic(
          finding,
          context
        )
      elseif operational_error(line) then
        failures[
          #failures + 1
        ] = line
      end
    end
  end

  if
    #diagnostics == 0
    and #failures > 0
  then
    return parse_failure(
      table.concat(
        failures,
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
    'vsg arguments require LintContext'
  )

  ---@type string[]
  local args = {
    --
    -- VSG explicitly documents syntastic output for Vim/editor use.
    --
    '--output_format',
    'syntastic',

    --
    -- Do not halt analysis when an earlier phase reports violations.
    -- Without this, later style phases may never run.
    --
    '--all_phases',

    --
    -- Read the current Neovim buffer instead of the saved file.
    --
    '--stdin',

    --
    -- Keep the editor invocation deterministic and avoid multiprocessing
    -- overhead. --stdin disables multiprocessing upstream as well.
    --
  }

  local config = configuration(
    context
  )

  if config ~= nil then
    args[#args + 1] =
      '--configuration'

    args[#args + 1] =
      config
  end

  return args
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  --
  -- VSG is multi-phase AST/style analysis. It is appropriate on save or
  -- after a short debounce, but is heavier than a lexical checker.
  --
  automatic = false,

  cmd = 'vsg',

  cwd = project_root,

  --
  -- 1 means lint violations. 2 can mean deprecated rule configuration.
  -- Either way, emitted diagnostics must be parsed.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = true,

  stream = 'both',

  timeout = 60000,
}