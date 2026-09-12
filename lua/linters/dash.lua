-- #################################################################
-- ~/.config/nvim/lua/linters/gawk.lua
-- Qompass AI Diver Native gawk Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://www.gnu.org/software/gawk/manual/html_node/Options.html
-- Native Linter/LintContext interface from cfn-lint.lua, Lua 5.1 compatible.
-- Arch Linux: sudo pacman -S --needed gawk coreutils
-- See dash-gawk-setup.md for the full option policy and runner contract.
-- /usr/bin/env supplies a clean, deterministic environment without a shell.
-- Timeout, streaming, changed-buffer cancellation belong to the native runner.
local SOURCE = 'gawk'
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
    return { finding(context, 'gawk output exceeded the 4 MiB parser limit.') }
  end
  ---@type vim.Diagnostic[]
  local result = {}
  ---@type string?
  local excerpt
  for line in output:gmatch('[^\r\n]+') do
    if #result >= MAX_DIAGNOSTICS then
      result[#result + 1] = finding(context, 'Additional diagnostics omitted.', nil, severity.WARN)
      break
    end
    local file, row, message = line:match('^.-gawk: (.-):(%d+):%s?(.*)$')
    if line:match('^.-gawk: In file included from ') then
      -- The following finding carries the included filename and line.
    elseif file and row and message then
      local warning = message:match('^warning:') ~= nil
      local caret = message:match('^%s*%^%s*(.*)$')
      local explicit = warning or message:match('^error:') or message:match('^fatal:')
      if caret or explicit then
        local text = caret or message
        if caret and excerpt then
          text = text .. ' | ' .. excerpt
        end
        local item = finding(
          context,
          text,
          file == '-' and tonumber(row) or nil,
          warning and severity.WARN or severity.ERROR
        )
        item.user_data = { filename = file, reported_line = tonumber(row) }
        if file ~= '-' then
          item.message = clean(file .. ':' .. row .. ': ' .. item.message)
        end
        result[#result + 1] = item
        excerpt = nil
      else
        -- Gawk prints a source excerpt before its caret/message line.
        if excerpt then
          result[#result + 1] = finding(context, excerpt)
        end
        excerpt = line
      end
    elseif vim.trim(line) ~= '' and not line:match('^.-gawk: In file included from ') then
      if excerpt then
        result[#result + 1] = finding(context, excerpt)
        excerpt = nil
      end
      local warning = line:match('gawk: warning:') ~= nil
      result[#result + 1] = finding(context, line, nil, warning and severity.WARN or severity.ERROR)
    end
  end
  if excerpt and #result < MAX_DIAGNOSTICS then
    result[#result + 1] = finding(context, excerpt)
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
    'AWKPATH=.',
    'AWKLIBPATH=/nonexistent',
    '/usr/bin/gawk',
    '--lint', -- All compile-time lint warnings, including GNU extensions.
    '--sandbox', -- Prohibit dynamic extensions if a loading path is reached.
    '--no-optimize', -- Preserve checks that optimization could eliminate.
    '--pretty-print=/dev/null', -- Compile only; discard formatted output.
    '--file=-', -- Program text is the unsaved current buffer, not input data.
    '--', -- No runtime data files or variable assignments.
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