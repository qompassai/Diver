-- #################################################################
-- /qompassai/lua/linters/gdlint.lua
-- Qompass AI Diver Native GDScript Linter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://godotengine.org/asset-library/asset/4612
---@source https://github.com/graydwarf/godot-gdscript-linter
---@source https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html
--
-- This linter invokes godot-gdscript-linter's analyzer CLI through a headless
-- Godot or Redot executable. Configure optional overrides with:
--
--   NVIM_GODOT_EXECUTABLE=/path/to/godot
--   NVIM_GDLINT_ROOT=/path/to/godot-gdscript-linter
--
-- A discovered linter root must contain:
--
--   addons/gdscript-linter/analyzer/analyze-cli.gd
--

local diagnostic = vim.diagnostic
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local MAX_DIAGNOSTICS = 512
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'gdlint'

local CLI_RELATIVE_PATH = 'addons/gdscript-linter/analyzer/analyze-cli.gd'
local DEFAULT_INSTALL_ROOT = fs.joinpath(fn.stdpath('data'), 'godot-gdscript-linter')

local ANSI_ESCAPE_PATTERN = string.char(27) .. '%[[%d;]*[mK]'
local NONEMPTY_LINE_PATTERN = '[^' .. string.char(13) .. string.char(10) .. ']+'

---@type string[]
local ROOT_MARKERS = {
  '.gdlint.cfg',
  'project.godot',
  '.git',
}

---@type string[]
local GODOT_EXECUTABLES = {
  'godot',
  'godot4',
  'redot',
}

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == 'string' and value ~= ''
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

  local column = math.floor(number)

  if column <= 1 then
    return 0
  end

  return column - 1
end

---@param path string
---@return boolean
local function is_file(path)
  if path == '' then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function is_absolute_path(path)
  if path:sub(1, 1) == '/' then
    return true
  end

  local separator = string.char(92)

  if path:sub(1, 2) == separator .. separator then
    return true
  end

  return path:match('^%a:[/\\]') ~= nil
end

---@param path string
---@return string
local function normalize(path)
  if path == '' then
    return ''
  end

  return fs.normalize(fn.fnamemodify(path, ':p'))
end

---@param command string
---@return string?
local function exepath(command)
  local path = fn.exepath(command)

  if not nonempty_string(path) then
    return nil
  end

  return fs.normalize(path)
end

---@return string?
local function godot_executable()
  local configured = vim.env.NVIM_GODOT_EXECUTABLE

  if nonempty_string(configured) then
    local candidate = normalize(fn.expand(configured))

    if fn.executable(candidate) == 1 then
      return candidate
    end
  end

  for _, command in ipairs(GODOT_EXECUTABLES) do
    local candidate = exepath(command)

    if candidate ~= nil then
      return candidate
    end
  end

  return nil
end

---@param context LintContext
---@return string
local function project_root(context)
  if nonempty_string(context.root) then
    local root = fs.normalize(context.root)

    if is_file(fs.joinpath(root, 'project.godot')) then
      return root
    end
  end

  if nonempty_string(context.filename) then
    local detected = fs.root(context.filename, {
      'project.godot',
    })

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    detected = fs.root(context.filename, {
      '.gdlint.cfg',
      '.git',
    })

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(context.filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  if nonempty_string(context.cwd) then
    return fs.normalize(context.cwd)
  end

  return fs.normalize(fn.getcwd())
end

---@param root string
---@return string?
local function project_local_linter_root(root)
  if is_file(fs.joinpath(root, CLI_RELATIVE_PATH)) then
    return root
  end

  return nil
end

---@return string?
local function configured_linter_root()
  local configured = vim.env.NVIM_GDLINT_ROOT

  if not nonempty_string(configured) then
    return nil
  end

  local root = normalize(fn.expand(configured))

  if is_file(fs.joinpath(root, CLI_RELATIVE_PATH)) then
    return root
  end

  return nil
end

---@return string?
local function default_linter_root()
  if is_file(fs.joinpath(DEFAULT_INSTALL_ROOT, CLI_RELATIVE_PATH)) then
    return DEFAULT_INSTALL_ROOT
  end

  local local_share = normalize(fn.expand('~/.local/share/godot-gdscript-linter'))

  if is_file(fs.joinpath(local_share, CLI_RELATIVE_PATH)) then
    return local_share
  end

  return nil
end

---@param context LintContext
---@return string?
local function linter_root(context)
  local root = project_root(context)
  local local_root = project_local_linter_root(root)

  if local_root ~= nil then
    return local_root
  end

  return configured_linter_root() or default_linter_root()
end

---@param value string
---@return integer
local function severity(value)
  local lower = value:lower()

  if lower == 'critical' or lower == 'error' then
    return diagnostic.severity.ERROR
  end

  if lower == 'warning' or lower == 'warn' then
    return diagnostic.severity.WARN
  end

  if lower == 'info' or lower == 'information' then
    return diagnostic.severity.INFO
  end

  if lower == 'hint' then
    return diagnostic.severity.HINT
  end

  return diagnostic.severity.WARN
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub(ANSI_ESCAPE_PATTERN, '')
end

---@class GdLintRecord
---@field path string
---@field line number
---@field column number
---@field severity string
---@field code? string
---@field message string

---@param text string?
---@return string?
local function normalize_code(text)
  if type(text) ~= 'string' or text == '' then
    return nil
  end

  local code = vim.trim(text)

  if code:match('^[%w_-]+$') ~= nil then
    return code
  end

  return nil
end

---@param line string
---@return GdLintRecord?
local function parse_clickable(line)
  local path
  local line_number
  local column
  local level
  local code
  local message

  path, line_number, column, level, code, message = line:match('^(.+):(%d+):(%d+):%s*([%a]+)%s+%[([%w_-]+)%]:%s*(.+)$')

  if path ~= nil and line_number ~= nil and column ~= nil and level ~= nil and code ~= nil and message ~= nil then
    return {
      path = path,
      line = tonumber(line_number) or 1,
      column = tonumber(column) or 1,
      severity = level,
      code = normalize_code(code),
      message = message,
    }
  end

  path, line_number, level, code, message = line:match('^(.+):(%d+):%s*([%a]+)%s+%[([%w_-]+)%]:%s*(.+)$')

  if path ~= nil and line_number ~= nil and level ~= nil and code ~= nil and message ~= nil then
    return {
      path = path,
      line = tonumber(line_number) or 1,
      column = 1,
      severity = level,
      code = normalize_code(code),
      message = message,
    }
  end

  path, line_number, column, level, message = line:match('^(.+):(%d+):(%d+):%s*([%a]+):%s*(.+)$')

  if path ~= nil and line_number ~= nil and column ~= nil and level ~= nil and message ~= nil then
    return {
      path = path,
      line = tonumber(line_number) or 1,
      column = tonumber(column) or 1,
      severity = level,
      message = message,
    }
  end

  path, line_number, level, message = line:match('^(.+):(%d+):%s*([%a]+):%s*(.+)$')

  if path ~= nil and line_number ~= nil and level ~= nil and message ~= nil then
    return {
      path = path,
      line = tonumber(line_number) or 1,
      column = 1,
      severity = level,
      message = message,
    }
  end

  return nil
end

---@param path string
---@param context LintContext
---@return boolean
local function same_file(path, context)
  if not nonempty_string(context.filename) then
    return false
  end

  local candidate = path

  if not is_absolute_path(candidate) then
    candidate = fs.joinpath(project_root(context), candidate)
  end

  return normalize(candidate) == normalize(context.filename)
end

---@param record GdLintRecord
---@param context LintContext
---@return vim.Diagnostic
local function record_diagnostic(record, context)
  local lnum = zero_based_line(record.line)
  local col = zero_based_col(record.column)
  local message = compact(record.message)

  if not same_file(record.path, context) then
    message = string.format('%s: %s', record.path, message)
    lnum = 0
    col = 0
  end

  return {
    bufnr = context.bufnr,
    code = record.code,
    col = col,
    end_col = col,
    end_lnum = lnum,
    lnum = lnum,
    message = truncate(message, MAX_MESSAGE_BYTES),
    severity = severity(record.severity),
    source = SOURCE,
    user_data = {
      path = record.path,
      severity = record.severity,
    },
  }
end

---@param line string
---@return boolean
local function operational_error(line)
  local lower = line:lower()

  return lower:find('error:', 1, true) ~= nil
    or lower:find('failed', 1, true) ~= nil
    or lower:find('not found', 1, true) ~= nil
    or lower:find('cannot open', 1, true) ~= nil
end

---@param line string
---@param context LintContext
---@return vim.Diagnostic
local function operational_diagnostic(line, context)
  return {
    bufnr = context.bufnr,
    code = 'operational-error',
    col = 0,
    end_col = 0,
    end_lnum = 0,
    lnum = 0,
    message = truncate(compact(line), MAX_MESSAGE_BYTES),
    severity = diagnostic.severity.ERROR,
    source = SOURCE,
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function missing_runtime(context)
  return {
    {
      bufnr = context.bufnr,
      code = 'missing-runtime',
      col = 0,
      end_col = 0,
      end_lnum = 0,
      lnum = 0,
      message = 'Godot/Redot executable was not found; set NVIM_GODOT_EXECUTABLE or install Godot',
      severity = diagnostic.severity.ERROR,
      source = SOURCE,
    },
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function missing_linter(context)
  return {
    {
      bufnr = context.bufnr,
      code = 'missing-linter',
      col = 0,
      end_col = 0,
      end_lnum = 0,
      lnum = 0,
      message = table.concat({
        'GDScript Linter CLI was not found; clone ',
        'graydwarf/godot-gdscript-linter and set ',
        'NVIM_GDLINT_ROOT to its repository root',
      }),
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
      message = string.format('gdlint output exceeded the %d-byte parser limit', MAX_OUTPUT_BYTES),
      severity = diagnostic.severity.WARN,
      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'gdlint parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'gdlint parser requires context.bufnr')

  if godot_executable() == nil then
    return missing_runtime(context)
  end

  if linter_root(context) == nil then
    return missing_linter(context)
  end

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local diagnostics = {}
  local text = strip_ansi(output)

  for raw_line in text:gmatch(NONEMPTY_LINE_PATTERN) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local line = vim.trim(raw_line)

    if line ~= '' then
      local record = parse_clickable(line)

      if record ~= nil then
        diagnostics[#diagnostics + 1] = record_diagnostic(record, context)
      elseif operational_error(line) then
        diagnostics[#diagnostics + 1] = operational_diagnostic(line, context)
      end
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'gdlint arguments require LintContext')

  local analyzer_root = linter_root(context)

  if analyzer_root == nil then
    return {}
  end

  return {
    '--headless',
    '--path',
    analyzer_root,
    '--script',
    'res://' .. CLI_RELATIVE_PATH,
    '--',
    '--path',
    project_root(context),
    '--clickable',
  }
end

local CMD = godot_executable() or 'godot'

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = false,
  cmd = CMD,
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'both',
  timeout = 60000,
}