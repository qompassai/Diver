-- #################################################################
-- /qompassai/Diver/lua/linters/luacheck.lua
-- Qompass AI Diver Native Luacheck Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Detects a Lua target per buffer. The precedence is:
--   1. vim.b[bufnr].luacheck_std
--   2. A Lua shebang, such as #!/usr/bin/env lua5.4 or luajit
--   3. A leading ---@version annotation
--   4. vim.g.luacheck_std
--   5. The Neovim/LuaJIT default
--
-- The linter reads the active buffer header, so unsaved edits are respected.
-- A requested standard unavailable in the installed Luacheck falls back to
-- the nearest older available Lua standard. Lua 5.5 therefore requires a
-- Luacheck release that understands lua55 to lint 5.5-only syntax exactly.
-- #################################################################

local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local HEADER_LINES_MAX = 64
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local TIMEOUT_MS = 15000

local SOURCE = 'luacheck'
local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

---@class LuacheckParsedDiagnostic
---@field line integer
---@field column integer
---@field end_column integer
---@field code string
---@field message string

---@class LuacheckTarget
---@field requested string
---@field standard string
---@field neovim boolean

local STANDARD_CANDIDATES = {
  luajit = {
    'luajit',
    'lua51',
  },
  lua51 = {
    'lua51',
  },
  lua52 = {
    'lua52',
    'lua51',
  },
  lua53 = {
    'lua53',
    'lua52',
    'lua51',
  },
  lua54 = {
    'lua54',
    'lua53',
    'lua52',
    'lua51',
  },
  lua55 = {
    'lua55',
    'lua54',
    'lua53',
    'lua52',
    'lua51',
  },
}

---@type table<string, boolean>
local standard_available = {}

---@type table<string, boolean>
local standard_checked = {}

---@type table<string, boolean>
local fallback_notified = {}

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0)

  local parsed = tonumber(value)
  if parsed == nil then
    return fallback
  end

  parsed = floor(parsed)
  if parsed < 0 then
    return fallback
  end

  return parsed
end

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string')
  return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function strip_ansi(value)
  assert(type(value) == 'string')
  return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
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
    value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
  end

  return value
end

---@param code string
---@return integer
local function severity(code)
  assert(type(code) == 'string')
  assert(code ~= '')
  return code:sub(1, 1) == 'E' and ERROR or WARN
end

---@param value unknown
---@return string?
local function normalize_standard(value)
  if type(value) ~= 'string' then
    return nil
  end

  local compact = value:lower():gsub('%s+', '')
  compact = compact:gsub('^lua', 'lua')

  if compact == 'jit' or compact == 'luajit' or compact == 'lua51jit' then
    return 'luajit'
  end

  local major, minor = compact:match('^lua?(5)%.?([1-5])$')
  if major and minor then
    return 'lua' .. major .. minor
  end

  return nil
end

---@param standard string
---@return boolean
local function has_standard(standard)
  if standard_checked[standard] then
    return standard_available[standard]
  end

  fn.system({
    'luacheck',
    '--std',
    standard,
    '--version',
  })
  standard_checked[standard] = true
  standard_available[standard] = vim.v.shell_error == 0
  return standard_available[standard]
end

---@param requested string
---@return string
local function resolve_standard(requested)
  local candidates = STANDARD_CANDIDATES[requested] or STANDARD_CANDIDATES.luajit

  for _, candidate in ipairs(candidates) do
    if has_standard(candidate) then
      if candidate ~= requested and not fallback_notified[requested] then
        fallback_notified[requested] = true
        vim.schedule(function()
          vim.notify(
            ('Luacheck does not provide %s; using %s. Upgrade Luacheck for exact %s support.'):format(
              requested,
              candidate,
              requested
            ),
            vim.log.levels.WARN,
            { title = 'Native Luacheck' }
          )
        end)
      end
      return candidate
    end
  end

  return requested
end

---@param bufnr integer
---@return string
local function buffer_header(bufnr)
  if api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) then
    return table.concat(api.nvim_buf_get_lines(bufnr, 0, HEADER_LINES_MAX, false), '\n')
  end

  return ''
end

---@param header string
---@return string?
local function standard_from_shebang(header)
  local first_line = header:match('^([^\n]*)') or ''
  local executable = first_line:match('^#!%s*(.-)%s*$')
  if not executable then
    return nil
  end

  local lowered = executable:lower()
  if lowered:find('luajit', 1, true) then
    return 'luajit'
  end

  local major, minor = lowered:match('lua%s*(5)%.?([1-5])')
  if major and minor then
    return 'lua' .. major .. minor
  end

  return nil
end

---@param header string
---@return string?
local function standard_from_annotation(header)
  local annotation = header:match('%-%-%-@version%s+([^\r\n]+)')
  if not annotation then
    return nil
  end

  local exact = annotation:match('^%s*(5%.[1-5])%s*$')
  if exact then
    return normalize_standard(exact)
  end

  local operator, version = annotation:match('^%s*([><]=?)%s*(5%.[1-5])')
  if not operator or not version then
    return nil
  end

  local major, minor = version:match('^(5)%.([1-5])$')
  local target = tonumber(minor)
  if operator == '>' and target < 5 then
    target = target + 1
  end

  return 'lua' .. major .. target
end

---@param context LintContext
---@param header string
---@return boolean
local function is_neovim_context(context, header)
  local override = vim.b[context.bufnr].luacheck_neovim
  if type(override) == 'boolean' then
    return override
  end

  local filename = context.filename:lower()
  if
    filename:find('/.config/nvim/', 1, true)
    or filename:find('/qompassai/diver/', 1, true)
    or filename:find('\\appdata\\local\\nvim\\', 1, true)
  then
    return true
  end

  return header:find('vim%.api', 1, false) ~= nil
    or header:find('vim%.g', 1, false) ~= nil
    or header:find('vim%.opt', 1, false) ~= nil
end

---@param context LintContext
---@return LuacheckTarget
local function target_for(context)
  assert(type(context) == 'table')
  assert(type(context.bufnr) == 'number')
  assert(type(context.filename) == 'string')

  local header = buffer_header(context.bufnr)
  local requested = normalize_standard(vim.b[context.bufnr].luacheck_std)
    or standard_from_shebang(header)
    or standard_from_annotation(header)
    or normalize_standard(vim.g.luacheck_std)
    or 'luajit'

  return {
    requested = requested,
    standard = resolve_standard(requested),
    neovim = is_neovim_context(context, header),
  }
end

---@param line string
---@return LuacheckParsedDiagnostic?
local function parse_line(line)
  assert(type(line) == 'string')

  if line == '' or #line > LINE_LENGTH_MAX then
    return nil
  end

  line = normalize_message(line)
  if line == '' then
    return nil
  end

  local line_number, start_column, end_column, code, message =
    line:match('^.-:(%d+):(%d+)%-(%d+):%s*%(([EW]%d%d%d)%)%s*(.+)$')

  if line_number ~= nil and start_column ~= nil and end_column ~= nil and code ~= nil and message ~= nil then
    local parsed_line = integer(line_number, 0)
    local parsed_start_column = integer(start_column, 0)
    local parsed_end_column = integer(end_column, 0)
    message = normalize_message(message)

    if parsed_line < 1 or parsed_start_column < 1 or parsed_end_column < parsed_start_column or message == '' then
      return nil
    end

    return {
      line = parsed_line,
      column = parsed_start_column,
      end_column = parsed_end_column,
      code = code,
      message = message,
    }
  end

  line_number, start_column, code, message = line:match('^.-:(%d+):(%d+):%s*%(([EW]%d%d%d)%)%s*(.+)$')
  if line_number == nil or start_column == nil or code == nil or message == nil then
    return nil
  end

  local parsed_line = integer(line_number, 0)
  local parsed_start_column = integer(start_column, 0)
  message = normalize_message(message)

  if parsed_line < 1 or parsed_start_column < 1 or message == '' then
    return nil
  end

  return {
    line = parsed_line,
    column = parsed_start_column,
    end_column = parsed_start_column,
    code = code,
    message = message,
  }
end

---@param entry LuacheckParsedDiagnostic
---@return vim.Diagnostic.Set
local function diagnostic_from_entry(entry)
  assert(type(entry) == 'table')

  local lnum = max(entry.line - 1, 0)
  local col = max(entry.column - 1, 0)
  local end_col = max(entry.end_column, col + 1)

  return {
    lnum = lnum,
    end_lnum = lnum,
    col = col,
    end_col = end_col,
    severity = severity(entry.code),
    source = SOURCE,
    code = entry.code,
    message = ('[%s] %s'):format(entry.code, entry.message),
    user_data = {
      analyzer = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, context)
  assert(type(output) == 'string')
  assert(type(context) == 'table', 'luacheck parser requires a LintContext')
  assert(#output <= OUTPUT_LENGTH_MAX, 'luacheck output exceeded maximum size')

  if output == '' then
    return {}
  end

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for line in output:gmatch('[^\r\n]+') do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local entry = parse_line(line)
    if entry ~= nil then
      diagnostics[#diagnostics + 1] = diagnostic_from_entry(entry)
    end
  end

  if #diagnostics == 0 then
    local message = normalize_message(output)
    if message ~= '' then
      diagnostics[1] = {
        lnum = 0,
        end_lnum = 0,
        col = 0,
        end_col = 1,
        severity = ERROR,
        source = SOURCE,
        code = 'invalid-output',
        message = message,
        user_data = {
          analyzer = SOURCE,
          location = 'unparsed',
        },
      }
    end
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(type(context) == 'table')
  assert(type(context.bufnr) == 'number')
  assert(type(context.filename) == 'string')
  assert(context.filename ~= '')

  local target = target_for(context)
  local result = {
    '--formatter',
    'plain',
    '--codes',
    '--ranges',
    '--no-color',
    '--no-cache',
    '--quiet',
    '--no-config',
    '--std',
    target.standard,
  }

  if target.neovim then
    result[#result + 1] = '--globals'
    result[#result + 1] = 'vim'
  end

  result[#result + 1] = '--filename'
  result[#result + 1] = context.filename
  result[#result + 1] = '--'
  result[#result + 1] = '-'

  return result
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(type(context) == 'table')
  assert(type(context.filename) == 'string')
  assert(context.filename ~= '')

  local directory = fs.dirname(context.filename)
  if type(directory) == 'string' and directory ~= '' then
    return fs.normalize(directory)
  end

  return fn.getcwd()
end

---@type Linter
return {
  automatic = true,
  cmd = 'luacheck',
  args = args,
  append_fname = false,
  cwd = cwd,
  ignore_exitcode = true,
  parser = parse,
  root_markers = {
    '.luacheckrc',
    '.git',
  },
  stdin = true,
  stream = 'stdout',
  timeout = TIMEOUT_MS,
}
