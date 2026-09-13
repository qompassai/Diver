-- #################################################################
-- ~/.config/nvim/lua/linters/markdownlint-cli2.lua
-- Native markdownlint-cli2 Linter; Lua 5.1 language contract.
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/DavidAnson/markdownlint-cli2
-- Requires the supplied .markdownlint-cli2.jsonc and stdout reporter in the
-- project root. Merge existing policy deliberately; do not overwrite it.
-- Current buffer goes through stdin, named "stdin" by CLI2, not its filename.
-- Thus filename-based overrides/ignores must account for this virtual name.
-- No --fix or --format. The supplied config disables fixes and extra scans.
-- Never invokes npx, a shell, or package installation during linting.
-- Keep outputFormatters/noBanner/noProgress/showFound compatible with JSON.
-- Inline suppression remains enabled. Root-local config remains authoritative.
-- The native runner must cancel/discard stale results and enforce the timeout.
local fs = vim.fs
local severity = vim.diagnostic.severity
local SOURCE = 'markdownlint-cli2'
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_DIAGNOSTICS = 512
local MAX_RECORDS = 10000
local MAX_LINE_BYTES = 1024 * 1024
local CONFIG_MARKERS = {
  '.markdownlint-cli2.jsonc',
  '.markdownlint-cli2.yaml',
  '.markdownlint-cli2.cjs',
  '.markdownlint-cli2.mjs',
}
local ROOT_MARKERS = { CONFIG_MARKERS, 'package.json', '.git' }

local function nonempty(value)
  return type(value) == 'string' and value ~= '' and value or nil
end

local function root(context)
  local cwd = nonempty(context.cwd) or vim.fn.getcwd()
  local file = nonempty(context.filename)
  if file then
    if file:sub(1, 1) ~= '/' then
      file = fs.joinpath(cwd, file)
    end
    return fs.root(file, CONFIG_MARKERS)
      or nonempty(context.root)
      or fs.root(file, ROOT_MARKERS)
      or fs.dirname(file)
      or cwd
  end
  return nonempty(context.root) or cwd
end

local function clean(text)
  text = vim.trim(text:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '))
  if #text <= MAX_MESSAGE_BYTES then
    return text
  end
  local stop = MAX_MESSAGE_BYTES - 3
  while stop > 0 do
    local byte = text:byte(stop + 1)
    if not byte or byte < 128 or byte >= 192 then
      break
    end
    stop = stop - 1
  end
  return text:sub(1, stop) .. '...'
end

---@return vim.Diagnostic
local function status(context, code, message)
  return {
    bufnr = context.bufnr,
    lnum = 0,
    col = 0,
    severity = severity.WARN,
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

-- markdownlint's JavaScript string offsets are UTF-16, not byte offsets.
local function byte_column(line, units)
  if #line > MAX_LINE_BYTES then
    return nil
  end
  local offset, count = 0, 0
  while offset < #line and count < units do
    local byte = line:byte(offset + 1)
    local width = byte < 128 and 1 or byte < 224 and 2 or byte < 240 and 3 or 4
    local step = width == 4 and 2 or 1
    if count + step > units then
      return nil
    end
    offset, count = offset + width, count + step
  end
  if count ~= units or offset > #line then
    return nil
  end
  return offset
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(
    type(context) == 'table' and type(context.bufnr) == 'number',
    'markdownlint-cli2 requires LintContext'
  )
  if #output > MAX_OUTPUT_BYTES then
    return { status(context, 'output-limit', 'markdownlint-cli2 exceeded the 16 MiB parser limit.') }
  end
  local ok, report = pcall(vim.json.decode, output)
  if not ok or type(report) ~= 'table' or not vim.islist(report) or not output:match('^%s*%[') then
    return {
      status(
        context,
        'invalid-report',
        'No valid JSON array from markdownlint-cli2. Install the companion config and stdout reporter; check CLI stderr for configuration or startup errors.'
      ),
    }
  end
  local count = vim.api.nvim_buf_line_count(context.bufnr)
  local cwd = fs.normalize(root(context))
  local diagnostics, malformed, foreign = {}, false, false
  local limited = #report > MAX_RECORDS
  for index = 1, math.min(#report, MAX_RECORDS) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      limited = true
      break
    end
    local item = report[index]
    if
      type(item) ~= 'table'
      or not nonempty(item.ruleDescription)
      or not nonempty(item.fileName)
    then
      malformed = true
    elseif
      item.fileName ~= 'stdin' and fs.normalize(item.fileName) ~= fs.joinpath(cwd, 'stdin')
    then
      foreign = true
    else
      local valid_row = integer(item.lineNumber)
        and item.lineNumber > 0
        and item.lineNumber <= count
      local row = valid_row and item.lineNumber - 1 or 0
      local col, finish = 0, nil
      local range = item.errorRange
      if
        valid_row
        and type(range) == 'table'
        and integer(range[1])
        and range[1] > 0
        and integer(range[2])
      then
        local line = vim.api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1] or ''
        local start = byte_column(line, range[1] - 1)
        if start then
          col = start
          finish = byte_column(line, range[1] - 1 + range[2])
        end
      end
      local message = item.ruleDescription
      if nonempty(item.errorDetail) then
        message = message .. ': ' .. item.errorDetail
      end
      if nonempty(item.errorContext) then
        message = message .. ' [' .. item.errorContext .. ']'
      end
      local names = type(item.ruleNames) == 'table' and item.ruleNames or {}
      local code = nonempty(names[1])
      local level = item.severity == 'warning' and severity.WARN or severity.ERROR
      local finding = {
        bufnr = context.bufnr,
        lnum = row,
        col = col,
        source = SOURCE,
        code = code and clean(code) or nil,
        message = clean(message),
        severity = level,
        user_data = {
          rule_name = nonempty(names[2]) and clean(names[2]) or nil,
          url = nonempty(item.ruleInformation) and clean(item.ruleInformation) or nil,
          reported_line = integer(item.lineNumber) and item.lineNumber or nil,
          fix_available = type(item.fixInfo) == 'table',
        },
      }
      if finish then
        finding.end_lnum, finding.end_col = row, finish
      end
      diagnostics[#diagnostics + 1] = finding
    end
  end
  if malformed or foreign then
    diagnostics[#diagnostics + 1] = status(
      context,
      'incomplete-report',
      'Some report entries were malformed or belonged to another input; check the companion configuration.'
    )
  end
  if limited then
    diagnostics[#diagnostics + 1] =
      status(context, 'result-limit', 'Only the first 512 diagnostics are shown.')
  end
  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(vim.api.nvim_buf_is_loaded(context.bufnr), 'markdownlint-cli2 requires a loaded buffer')
  return { '--no-globs', '-' }
end

---@type Linter
return {
  cmd = 'markdownlint-cli2',
  args = arguments,
  append_fname = false,
  automatic = true,
  cwd = root,
  env = { NO_COLOR = '1' },
  exit_codes = { 0, 1 },
  ignore_exitcode = false,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = true,
  stream = 'stdout',
  timeout = 30000,
}