
-- ~/.config/nvim/lua/linters/spectral.lua
-- Native Spectral linter for Neovim 0.13+; Lua 5.1 language contract.
---@source https://github.com/stoplightio/spectral
--
-- Install in your project: npm install --save-dev @stoplight/spectral-cli
-- Expose node_modules/.bin/spectral to your runner's PATH, or install into
-- a user-owned npm global prefix. This adapter never downloads executables.
-- Register `spectral` in your native runner, following cfn-lint.lua's pattern.
-- This uses parser(output, LintContext), not nvim-lint's parser signature.
--
-- A ruleset is required. Use your existing project policy. For a NEW OpenAPI
-- project, a minimal PROJECT_ROOT/.spectral.yaml could contain:
--   extends: [spectral:oas]
-- For AsyncAPI use spectral:asyncapi; for generic JSON/YAML define custom rules.
-- Do not replace an existing ruleset just to install this adapter.
--
-- Tiger policy:
-- * Lint the current buffer over stdin, including unsaved changes.
-- * Supply its absolute filename for relative $ref resolution.
-- * Discover the nearest supported ruleset, preserving native filename choice.
-- * Keep all severities, rule IDs, JSON paths, URLs, and exact valid ranges.
-- * Filter diagnostics belonging to external references out of this buffer.
-- * Bound parsing and conversion; invoke argv directly, without a shell.
-- * Keep project rules, formats, overrides, and custom functions authoritative.
--
-- Optional NVIM_SPECTRAL_RULESET: explicit local ruleset path, absolute or
-- relative to the selected project cwd. Useful for custom names or .ts files.
-- No fabricated fallback filename is used: name the buffer before linting.
-- The runner should cancel/discard results after the buffer changes.
-- Requires only the `spectral` executable; tested with CLI 6.16.3.
local fs = vim.fs
local severity = vim.diagnostic.severity
local SOURCE = 'spectral'
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_RECORDS = 10000
local MAX_TEXT = 4096
local MAX_LINE = 1024 * 1024
local RULESET_MARKERS = {
  '.spectral.yaml', '.spectral.yml', '.spectral.json', '.spectral.js', '.spectral.mjs',
  'spectral.yaml', 'spectral.yml', 'spectral.json', 'spectral.js', 'spectral.mjs',
}
local ROOT_MARKERS = { RULESET_MARKERS, 'package.json', '.git' }
local SEVERITIES = { [0] = severity.ERROR, [1] = severity.WARN, [2] = severity.INFO, [3] = severity.HINT }


local function nonempty(value)
  return type(value) == 'string' and value ~= '' and value or nil
end

local function clean(value)
  value = type(value) == 'string' and value or ''
  value = vim.trim(value:gsub('\27%[[%d;]*[mK]', ''):gsub('%c', ' '):gsub('%s+', ' '))
  if #value <= MAX_TEXT then return value end
  local stop = MAX_TEXT - 3
  while stop > 0 and (value:byte(stop + 1) or 0) >= 128
    and (value:byte(stop + 1) or 0) < 192 do
    stop = stop - 1
  end
  return value:sub(1, stop) .. '...'
end

local function absolute(path, cwd)
  if path:sub(1, 1) ~= '/' and not path:match('^%a:[/\\]') then
    path = fs.joinpath(cwd, path)
  end
  return fs.normalize(path)
end

local function root(context)
  local cwd = nonempty(context.cwd) or vim.fn.getcwd()
  local filename = nonempty(context.filename)
  if filename then
    filename = absolute(filename, cwd)
    return fs.root(filename, RULESET_MARKERS) or nonempty(context.root)
      or fs.root(filename, ROOT_MARKERS) or fs.dirname(filename) or cwd
  end
  return nonempty(context.root) or cwd
end

local function canonical(path, cwd)
  path = absolute(path, cwd)
  return vim.uv.fs_realpath(path) or path
end

local function status(context, code, message)
  return { bufnr = context.bufnr, lnum = 0, col = 0,
    severity = severity.WARN, source = SOURCE, code = code, message = clean(message) }
end

local function integer(value)
  return type(value) == 'number' and value == value and value >= 0
    and value < 2147483647 and value == math.floor(value)
end

-- Spectral positions are zero-based UTF-16; Neovim requires byte columns.
local function byte_column(line, units)
  if #line > MAX_LINE then return nil end
  local offset, count = 0, 0
  while offset < #line and count < units do
    local byte = line:byte(offset + 1)
    local width = byte < 128 and 1 or byte < 224 and 2 or byte < 240 and 3 or 4
    local step = width == 4 and 2 or 1
    if count + step > units then return nil end
    offset, count = offset + width, count + step
  end
  if count ~= units or offset > #line then return nil end
  return offset
end

---@param source string
---@param context LintContext
---@return boolean
local function current_source(source, context)
  if source:match('^file:') then
    local ok, filename = pcall(vim.uri_to_fname, source)
    if not ok then return false end
    source = filename
  elseif source:match('^%a[%w+.-]*://') then
    return false
  end
  return canonical(source, root(context))
    == canonical(context.filename, nonempty(context.cwd) or vim.fn.getcwd())
end

local function json_path(value)
  if type(value) ~= 'table' then return nil end
  local parts = {}
  for index = 1, math.min(#value, 128) do
    local part = value[index]
    if type(part) == 'string' then parts[#parts + 1] = clean(part)
    elseif type(part) == 'number' and integer(part) then parts[#parts + 1] = part end
  end
  return parts
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table' and type(context.bufnr) == 'number', 'spectral requires LintContext')
  if not nonempty(context.filename) then
    return { status(context, 'filename-required', 'Name the buffer before running Spectral.') }
  end
  if #output > MAX_OUTPUT then
    return { status(context, 'output-limit', 'Spectral output exceeded the 16 MiB parser limit.') }
  end
  local text = vim.trim(output)
  local ok, report = pcall(vim.json.decode, text)
  if not ok or text:sub(1, 1) ~= '[' or type(report) ~= 'table' or not vim.islist(report) then
    local item = status(context, 'spectral-error', 'Spectral did not return a JSON report. '
      .. (text ~= '' and clean(text) or 'Check the executable and project ruleset.'))
    item.severity = severity.ERROR
    return { item }
  end
  local loaded = vim.api.nvim_buf_is_loaded(context.bufnr)
  local count = loaded and vim.api.nvim_buf_line_count(context.bufnr) or 0
  local cache = {}
  local function position(value)
    if type(value) ~= 'table' or not integer(value.line) or not integer(value.character)
      or value.line >= count then return nil end
    local row = value.line
    if cache[row] == nil then
      cache[row] = vim.api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1] or ''
    end
    local col = byte_column(cache[row], value.character)
    if col == nil then return nil end
    return row, col
  end
  local diagnostics, malformed = {}, false
  for index = 1, math.min(#report, MAX_RECORDS) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      diagnostics[#diagnostics + 1] = status(context, 'diagnostic-limit', 'Only the first 512 Spectral diagnostics are shown.')
      break
    end
    local finding = report[index]
    if type(finding) ~= 'table' or not nonempty(finding.message) then
      malformed = true
    elseif finding.severity ~= -1 then
      local source = nonempty(finding.source)
      if source == nil or current_source(source, context) then
        local range = type(finding.range) == 'table' and finding.range or {}
        local lnum, col = position(range.start)
        local end_lnum, end_col = position(range['end'])
        local code = nonempty(finding.code)
        if type(finding.code) == 'number' and integer(finding.code) then code = tostring(finding.code) end
        local url = nonempty(finding.documentationUrl)
        local item = {
          bufnr = context.bufnr,
          lnum = lnum or 0,
          col = col or 0,
          severity = SEVERITIES[finding.severity] or severity.WARN,
          source = SOURCE,
          code = code and clean(code) or nil,
          message = clean(finding.message),
          user_data = { filename = source, path = json_path(finding.path),
            documentation_url = url and clean(url) or nil },
        }
        if lnum and end_lnum and (end_lnum > lnum or (end_lnum == lnum and end_col >= col)) then
          item.end_lnum, item.end_col = end_lnum, end_col
        end
        diagnostics[#diagnostics + 1] = item
      end
    end
  end
  if malformed then
    diagnostics[#diagnostics + 1] = status(context, 'invalid-record', 'Some Spectral report records were malformed.')
  end
  if #report > MAX_RECORDS then
    diagnostics[#diagnostics + 1] = status(context, 'record-limit', 'Spectral report exceeded the 10000-record parser limit.')
  end
  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  local filename = assert(nonempty(context.filename), 'Spectral requires a named buffer')
  local args = {
    'lint',
    '--format', 'json',
    '--encoding', 'utf8',
    '--quiet',
    '--show-documentation-url',
    '--fail-severity', 'error',
    '--stdin-filepath', absolute(filename, nonempty(context.cwd) or vim.fn.getcwd()),
  }
  local ruleset = nonempty(vim.env.NVIM_SPECTRAL_RULESET)
  if ruleset then
    args[#args + 1], args[#args + 2] = '--ruleset', absolute(ruleset, root(context))
  end
  -- No positional document: the CLI reads stdin when it is a pipe.
  -- Do not pass '-' (a document/glob), --output, or --display-only-failures.
  return args
end

---@type Linter
return {
  cmd = 'spectral',
  args = arguments,
  append_fname = false,
  automatic = true,
  cwd = root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = true,
  stream = 'both',
  timeout = 60000,
}