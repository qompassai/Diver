-- ~/.config/nvim/lua/linters/markuplint.lua
-- Native markuplint adapter for Neovim 0.13+ (Lua 5.1 compatible).
---@source https://github.com/markuplint/markuplint
---@source https://markuplint.dev/docs/guides/cli
--
-- Install markuplint and any framework parsers in your project, and expose
-- node_modules/.bin/markuplint to your runner's PATH (or install globally).
-- Register this module in your native runner, using the same convention as
-- cfn-lint.lua. It is not an nvim-lint parser signature.
--
-- Tiger policy:
-- * Scan one saved file; run after BufWritePost. No automatic fixes.
-- * Preserve native config discovery, rules, ignores, and parser selection.
-- * Do not use stdin: markuplint 4.18.3 requires a TTY on stdout for pipes.
-- * Parse native JSON; retain rule IDs/reasons and convert UTF-16 columns
--   to Neovim byte columns. Validate raw text before adding end ranges.
-- * Bound output, records, messages, and per-line position conversion.
-- * Invoke argv directly; escape filename glob syntax, without a shell.
--
-- Requires a named, saved file. Modified buffers get a save reminder instead
-- of disk diagnostics. Your runner should discard results after edits.
local fs = vim.fs
local severity = vim.diagnostic.severity
local SOURCE = 'markuplint'
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_RECORDS = 10000
local MAX_TEXT = 4096
local MAX_LINE = 1024 * 1024
local ROOT_MARKERS = { '.markuplintrc', '.markuplintrc.json', '.markuplintrc.yaml',
  '.markuplintrc.yml', '.markuplintrc.js', '.markuplintrc.cjs',
  'markuplint.config.js', 'markuplint.config.cjs', 'package.json', '.git' }

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
    return fs.root(filename, ROOT_MARKERS) or nonempty(context.root) or fs.dirname(filename) or cwd
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
  return type(value) == 'number' and value == value and value >= 1
    and value < 2147483647 and value == math.floor(value)
end

-- Markuplint columns count JavaScript UTF-16 code units, starting at one.
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

local function parse(output, context)
  assert(type(context) == 'table' and type(context.bufnr) == 'number', 'markuplint requires LintContext')
  if context.modified then
    return { status(context, 'save-required', 'Save the buffer before running markuplint.') }
  end
  if not nonempty(context.filename) then
    return { status(context, 'filename-required', 'markuplint requires a named, saved file.') }
  end
  if #output > MAX_OUTPUT then
    return { status(context, 'output-limit', 'markuplint output exceeded the 16 MiB parser limit.') }
  end
  local text = vim.trim(output)
  local ok, report = pcall(vim.json.decode, text)
  if not ok or text:sub(1, 1) ~= '[' or type(report) ~= 'table' or not vim.islist(report) then
    return { status(context, 'invalid-report', 'markuplint did not return a JSON report. '
      .. (text ~= '' and clean(text) or 'Check the executable and project configuration.')) }
  end
  local cwd = root(context)
  local target = canonical(context.filename, nonempty(context.cwd) or cwd)
  local loaded = vim.api.nvim_buf_is_loaded(context.bufnr)
  local count = loaded and vim.api.nvim_buf_line_count(context.bufnr) or 0
  local cache = {}
  local function line_at(index)
    if index < 0 or index >= count then return nil end
    if cache[index] == nil then
      cache[index] = vim.api.nvim_buf_get_lines(context.bufnr, index, index + 1, false)[1]
    end
    return cache[index]
  end
  local diagnostics = {}
  local malformed = false
  for index = 1, math.min(#report, MAX_RECORDS) do
    if #diagnostics >= MAX_DIAGNOSTICS then
      diagnostics[#diagnostics + 1] = status(context, 'diagnostic-limit', 'Only the first 512 markuplint diagnostics are shown.')
      break
    end
    local finding = report[index]
    if type(finding) ~= 'table' or not nonempty(finding.message) or not nonempty(finding.filePath) then
      malformed = true
    elseif canonical(finding.filePath, cwd) == target and finding.severity ~= 'off' then
      local lnum = integer(finding.line) and finding.line - 1 or 0
      if count > 0 then lnum = math.min(lnum, count - 1) else lnum = 0 end
      local line = line_at(lnum)
      local col = line and integer(finding.col) and byte_column(line, finding.col - 1) or nil
      local item = { bufnr = context.bufnr, lnum = lnum, col = col or 0,
        severity = finding.severity == 'error' and severity.ERROR or severity.WARN,
        source = SOURCE, code = nonempty(finding.ruleId), message = clean(finding.message),
        user_data = { filename = finding.filePath, rule = nonempty(finding.ruleId),
          reason = nonempty(finding.reason) and clean(finding.reason) or nil } }
      -- The raw span can cross lines. Only highlight a span that still matches
      -- the buffer, and normalize CRLF to Neovim's newline representation.
      local raw = nonempty(finding.raw)
      if col and raw and #raw <= MAX_TEXT then
        raw = raw:gsub('\r\n', '\n')
        local parts = vim.split(raw, '\n', { plain = true })
        local end_lnum = lnum + #parts - 1
        local last = line_at(end_lnum)
        if last then
          local actual = {}
          for row = lnum, end_lnum do actual[#actual + 1] = line_at(row) end
          actual[1] = actual[1]:sub(col + 1)
          actual[#actual] = actual[#actual]:sub(1, #parts[#parts])
          if table.concat(actual, '\n') == raw then
            item.end_lnum = end_lnum
            item.end_col = #parts == 1 and col + #raw or #parts[#parts]
          end
        end
      end
      diagnostics[#diagnostics + 1] = item
    end
  end
  if malformed then
    diagnostics[#diagnostics + 1] = status(context, 'invalid-record', 'Some markuplint report records were malformed.')
  end
  if #report > MAX_RECORDS then
    diagnostics[#diagnostics + 1] = status(context, 'record-limit', 'markuplint report exceeded the 10000-record parser limit.')
  end
  return diagnostics
end

local function arguments(context)
  local filename = assert(nonempty(context.filename), 'markuplint requires a named, saved file')
  filename = absolute(filename, nonempty(context.cwd) or vim.fn.getcwd())
  -- CLI targets are globs. Backslash-escape metacharacters, including extglobs.
  filename = filename:gsub('([\\*?%[%]{}()!+@])', '\\%1')
  return { '--format', 'JSON', '--no-color', '--no-allow-empty-input', filename }
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'markuplint',
  cwd = root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'both',
  timeout = 60000,
}