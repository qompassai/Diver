-- #################################################################
-- ~/.config/nvim/lua/linters/dash.lua
-- Qompass AI Diver Native dash Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source http://gondor.apana.org.au/~herbert/dash/
-- Native Linter/LintContext interface from cfn-lint.lua, Lua 5.1 compatible.
-- Arch Linux: sudo pacman -S --needed dash coreutils
-- See dash-gawk-setup.md for the full option policy and runner contract.
-- /usr/bin/env supplies a clean, deterministic environment without a shell.
-- Timeout, streaming, changed-buffer cancellation belong to the native runner.
local SOURCE = 'dash'
local severity = vim.diagnostic.severity
local MAX_OUTPUT = 4 * 1024 * 1024
local MAX_DIAGNOSTICS = 256
local MAX_MESSAGE = 4096
local ROOT_MARKERS = { '.git' }

---@param context LintContext
---@return string
local function cwd(context)
  local base = context.cwd or vim.fn.getcwd()
  if context.filename and context.filename ~= '' then
    local name = context.filename
    if name:sub(1, 1) ~= '/' then
      name = vim.fs.joinpath(base, name)
    end
    return vim.fs.dirname(vim.fs.normalize(name)) or base
  end
  return context.root or base
end

---@param text string
---@return string
local function clean(text)
  text = vim.trim(text:gsub('\27%[[%d;]*[mK]', ''):gsub('%c', ' '))
  if #text <= MAX_MESSAGE then
    return text
  end
  local stop = MAX_MESSAGE - 3
  while stop > 0 do
    local byte = text:byte(stop + 1)
    if not byte or byte < 128 or byte >= 192 then
      break
    end
    stop = stop - 1
  end
  return text:sub(1, stop) .. '...'
end

---@param context LintContext
---@param message string
---@param row integer?
---@param level integer?
---@return vim.Diagnostic
local function finding(context, message, row, level)
  local count = vim.api.nvim_buf_line_count(context.bufnr)
  return {
    bufnr = context.bufnr,
    lnum = math.max(0, math.min((row or 1) - 1, count - 1)),
    col = 0, -- Neither adapter claims a reliable byte column.
    message = clean(message),
    severity = level or severity.ERROR,
    source = SOURCE,
  }
end
---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  if #output > MAX_OUTPUT then
    return { finding(context, 'dash output exceeded the 4 MiB parser limit.') }
  end
  local result = {}
  for line in output:gmatch('[^\r\n]+') do
    if #result >= MAX_DIAGNOSTICS then
      result[#result + 1] = finding(context, 'Additional diagnostics omitted.', nil, severity.WARN)
      break
    end
    if vim.trim(line) ~= '' then
      local row, message = line:match('^.-dash: (%d+): (.+)$')
      result[#result + 1] = finding(context, message or line, tonumber(row))
    end
  end
  return result
end

---@param _context LintContext
---@return string[]
local function arguments(_context)
  return {
    '-i',
    'LC_ALL=C',
    'PATH=/usr/bin:/bin',
    '/usr/bin/dash',
    '-n', -- Parse commands without executing them.
    '-s', -- Read the entire current buffer from standard input.
    '--', -- No script pathname, arguments, login mode, or interactive mode.
  }
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = '/usr/bin/env',
  cwd = cwd,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = true,
  stream = 'both',
  timeout = 10000,
}