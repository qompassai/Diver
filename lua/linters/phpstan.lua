-- #################################################################
-- /qompassai/Diver/lua/linters/phpstan.lua
-- Qompass AI Diver Native PHPStan Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/phpstan/phpstan/releases/tag/2.2.14
-- Native Linter / LintContext interface; LuaJIT, Neovim 0.13+.
-- Requires /usr/bin/php, project vendor/bin/phpstan, and project NEON config.
-- Install: composer require --dev --with-all-dependencies phpstan/phpstan:2.2.14
-- Saved files only. Register for php on BufWritePost; no shell or auto-install.
-- CLI booleans without a negative form are disabled by omission (see README).
-- Project configuration selects level/rules; bundled NEON explicitly selects 10.
-- Runner owns cancellation, stale-job suppression, stderr and process failures.
local fs = vim.fs
local uv = vim.uv
local SOURCE = 'phpstan'
local PHP = '/usr/bin/php'
local VENDOR_BINARY = 'vendor/bin/phpstan'
local CACHE = fs.joinpath(vim.fn.stdpath('cache'), 'phpstan')
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_FILES = 1024
local MAX_RECORDS = 10000
local CONFIG_NAMES = {
  '.phpstan.neon',
  'phpstan.neon',
  '.phpstan.neon.dist',
  'phpstan.neon.dist',
  '.phpstan.dist.neon',
  'phpstan.dist.neon',
}
local ROOT_MARKERS = vim.list_extend(vim.deepcopy(CONFIG_NAMES), { 'composer.json', '.git' })

---@param context LintContext
---@return string
local function root(context)
  return fs.root(context.filename, CONFIG_NAMES)
    or fs.root(context.filename, { 'composer.json', '.git' })
    or context.root
    or context.cwd
end

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
  if path:sub(1, 1) ~= '/' then
    path = fs.joinpath(cwd, path)
  end
  path = fs.normalize(path)
  return uv.fs_realpath(path) or path
end

---@param value string
---@return string
local function clean(value)
  local message = vim.trim(value:gsub('[%z\1-\31\127]', ' '))
  if #message > 4096 then
    local last = 4093
    while last > 0 do
      local byte = message:byte(last + 1)
      if not byte or byte < 128 or byte >= 192 then
        break
      end
      last = last - 1
    end
    message = message:sub(1, last) .. '...'
  end
  return message
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status(context, code, message)
  return {
    bufnr = context.bufnr,
    lnum = 0,
    col = 0,
    severity = vim.diagnostic.severity.ERROR,
    source = SOURCE,
    code = code,
    message = clean(message),
  }
end

local function integer(value)
  return type(value) == 'number'
    and value >= 0
    and value < 2147483647
    and value == math.floor(value)
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(context.filename ~= '' and not context.modified, 'PHPStan requires a saved buffer')
  local cwd = root(context)
  local config
  for _, name in ipairs(CONFIG_NAMES) do
    local path = fs.joinpath(cwd, name)
    if vim.fn.filereadable(path) == 1 then
      config = path
      break
    end
  end
  assert(config, 'Install phpstan.neon.dist in the project root')
  local executable = fs.joinpath(cwd, VENDOR_BINARY)
  assert(vim.fn.filereadable(executable) == 1, 'Install project-local phpstan/phpstan:2.2.14')
  vim.fn.mkdir(CACHE, 'p')
  assert(uv.fs_chmod(CACHE, 448), 'Cannot protect PHPStan cache directory')
  return {
    executable,
    'analyse',
    '--configuration=' .. config,
    '--error-format=json',
    '--memory-limit=512M',
    '--no-progress',
    '--no-ansi',
    '--no-interaction',
    '--',
    canonical(context.filename, context.cwd),
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  if context.modified then
    return { status(context, 'save-required', 'Save the buffer before running PHPStan.') }
  end
  if #output > MAX_OUTPUT then
    return { status(context, 'output-limit', 'PHPStan output exceeded 16 MiB.') }
  end
  local ok, report = pcall(vim.json.decode, output)
  if
    not ok
    or type(report) ~= 'table'
    or type(report.totals) ~= 'table'
    or not integer(report.totals.errors)
    or not integer(report.totals.file_errors)
    or type(report.files) ~= 'table'
    or type(report.errors) ~= 'table'
    or not vim.islist(report.errors)
  then
    return {
      status(
        context,
        'invalid-report',
        'PHPStan returned no valid JSON report; inspect stderr and configuration.'
      ),
    }
  end
  ---@type vim.Diagnostic[]
  local result = {}
  local target = canonical(context.filename, context.cwd)
  local cwd = root(context)
  local count = vim.api.nvim_buf_line_count(context.bufnr)
  local files, records, file_errors = 0, 0, 0
  local malformed, foreign, limited = false, false, false
  for path, group in pairs(report.files) do
    files = files + 1
    if files > MAX_FILES then
      limited = true
      break
    end
    if
      type(path) ~= 'string'
      or type(group) ~= 'table'
      or type(group.messages) ~= 'table'
      or not vim.islist(group.messages)
      or not integer(group.errors)
      or group.errors ~= #group.messages
    then
      malformed = true
    else
      file_errors = file_errors + group.errors
      local matches = canonical(path, cwd) == target
      for _, issue in ipairs(group.messages) do
        records = records + 1
        if records > MAX_RECORDS or #result >= MAX_DIAGNOSTICS then
          limited = true
          break
        end
        if
          type(issue) ~= 'table'
          or type(issue.message) ~= 'string'
          or issue.message == ''
          or type(issue.ignorable) ~= 'boolean'
          or (
            issue.line ~= vim.NIL
            and issue.line ~= nil
            and (not integer(issue.line) or issue.line < 1)
          )
        then
          malformed = true
        elseif not matches then
          foreign = true
        else
          local row = integer(issue.line) and math.max(0, issue.line - 1) or 0
          local item = status(
            context,
            type(issue.identifier) == 'string' and clean(issue.identifier) or 'analysis',
            issue.message
          )
          item.lnum = math.min(row, count - 1)
          if type(issue.tip) == 'string' and issue.tip ~= '' then
            item.message = clean(item.message .. ' Tip: ' .. issue.tip)
          end
          item.user_data = {
            filename = path,
            reported_line = integer(issue.line) and issue.line or nil,
            ignorable = issue.ignorable,
            tip = type(issue.tip) == 'string' and clean(issue.tip) or nil,
          }
          result[#result + 1] = item
        end
      end
      if limited then
        break
      end
    end
  end
  for _, message in ipairs(report.errors) do
    if #result >= MAX_DIAGNOSTICS then
      limited = true
      break
    end
    if type(message) == 'string' and message ~= '' then
      result[#result + 1] = status(context, 'project-error', message)
    else
      malformed = true
    end
  end
  if
    report.totals.errors ~= #report.errors
    or (not limited and file_errors ~= report.totals.file_errors)
  then
    malformed = true
  end
  if foreign then
    result[#result + 1] = status(
      context,
      'other-files',
      'PHPStan reported errors outside this buffer, possibly a trait context. Run project analysis to inspect them.'
    )
  end
  if malformed then
    result[#result + 1] =
      status(context, 'malformed-result', 'Some PHPStan results were malformed or inconsistent.')
  end
  if limited then
    result[#result + 1] = status(
      context,
      'result-limit',
      'PHPStan reached the editor result limit; run project analysis for all results.'
    )
  end
  return result
end

---@type Linter
return {
  cmd = PHP,
  args = arguments,
  append_fname = false,
  automatic = true,
  cwd = root,
  env = { PHPSTAN_TMP_DIR = CACHE, NO_COLOR = '1' },
  exit_codes = { 0, 1 },
  ignore_exitcode = false,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'stdout',
  timeout = 120000,
}