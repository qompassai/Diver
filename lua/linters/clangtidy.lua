-- #################################################################
-- /qompassai/Diver/lua/linters/clangtidy.lua
-- Qompass AI Diver Native Clang-Tidy Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local TIMEOUT_MS = 60000

local SOURCE = 'clang-tidy'

---@class ClangTidyContext : LintContext
---@field bufnr integer
---@field cwd string
---@field filename string
---@field root string

---@type table<string, integer>
local severities = {
  ['error'] = ERROR,
  ['fatal error'] = ERROR,
  ['hint'] = HINT,
  ['information'] = INFO,
  ['info'] = INFO,
  ['note'] = HINT,
  ['warn'] = WARN,
  ['warning'] = WARN,
}

---@param value string|number|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  local parsed = tonumber(value)
  if parsed == nil then
    return fallback
  end

  parsed = math.floor(parsed)
  return parsed >= 0 and parsed or fallback
end

---@param value string|nil
---@return integer
local function severity(value)
  return value and severities[value:lower()] or WARN
end

---@param path string
---@return string
local function normalize_path(path)
  return fs.normalize(path) or path
end

---@param path string
---@return string
local function path_basename(path)
  return fs.basename(path) or path
end

---@param path string
---@return boolean
local function is_absolute_path(path)
  return path:sub(1, 1) == '/' or path:match('^%a:[/\\]') ~= nil or path:match('^\\\\') ~= nil
end

---@param path string
---@return boolean
local function is_file(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == 'file'
end

---@param value unknown
---@return string?
local function configured_build_directory(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  local directory = normalize_path(value)
  return is_file(fs.joinpath(directory, 'compile_commands.json')) and directory or nil
end

---@param context ClangTidyContext
---@return string?
local function compilation_database(context)
  local buffer_override = configured_build_directory(vim.b[context.bufnr].clangtidy_build_dir)
  if buffer_override then
    return buffer_override
  end

  local global_override = configured_build_directory(vim.g.clangtidy_build_dir)
  if global_override then
    return global_override
  end

  local root = normalize_path(context.root)
  local candidates = {
    root,
    fs.joinpath(root, 'build'),
    fs.joinpath(root, 'build-debug'),
    fs.joinpath(root, 'build-release'),
    fs.joinpath(root, 'cmake-build-debug'),
    fs.joinpath(root, 'cmake-build-release'),
    fs.joinpath(root, 'out'),
  }

  for _, directory in ipairs(candidates) do
    if is_file(fs.joinpath(directory, 'compile_commands.json')) then
      return directory
    end
  end

  return nil
end

---@param path string
---@param filename string
---@param root string
---@param basename string
---@return boolean
local function belongs_to_buffer(path, filename, root, basename)
  if path == '' then
    return true
  end

  local candidate = is_absolute_path(path) and normalize_path(path) or normalize_path(fs.joinpath(root, path))

  if candidate == filename then
    return true
  end

  -- A bare filename is safe to match only when Clang-Tidy supplied no path.
  return not path:find('/', 1, true) and not path:find('\\', 1, true) and path_basename(candidate) == basename
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
  if output == '' then
    return {}
  end

  if type(context) ~= 'table' then
    error('clang-tidy parser requires a LintContext', 0)
  end

  ---@cast context ClangTidyContext

  local filename = normalize_path(context.filename)
  local root = normalize_path(context.root)
  local basename = path_basename(filename)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    if #line <= LINE_LENGTH_MAX then
      local path, lnum, col, level, message = line:match('^(.-):(%d+):(%d+):%s*([^:]+):%s*(.+)$')

      if path and lnum and col and level and message and belongs_to_buffer(path, filename, root, basename) then
        local text, code = message:match('^(.-)%s+%[([^%]]+)%]%s*$')
        local row = math.max(integer(lnum, 1) - 1, 0)
        local column = math.max(integer(col, 1) - 1, 0)

        diagnostics[#diagnostics + 1] = {
          code = code,
          col = column,
          end_col = column + 1,
          end_lnum = row,
          lnum = row,
          message = text or message,
          severity = severity(level),
          source = SOURCE,
        }
      end
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  ---@cast context ClangTidyContext

  local result = {
    '--quiet',
  }

  local database = compilation_database(context)
  if database then
    result[#result + 1] = '-p'
    result[#result + 1] = database
  end

  result[#result + 1] = context.filename
  return result
end

---@param context LintContext
---@return string
local function cwd(context)
  return normalize_path(context.root)
end

---@type Linter
return {
  automatic = false,
  cmd = 'clang-tidy',
  args = args,
  append_fname = false,
  cwd = cwd,
  exit_codes = {
    [0] = true,
    [1] = true,
  },
  parser = parse,
  root_markers = {
    '.clang-tidy',
    'compile_commands.json',
    'CMakeLists.txt',
    'meson.build',
    '.git',
  },
  stdin = false,
  stream = 'both',
  timeout = TIMEOUT_MS,
}