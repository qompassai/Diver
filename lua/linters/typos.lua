-- ~/.config/nvim/lua/linters/typos.lua
local fs = vim.fs
local severity = vim.diagnostic.severity
local SOURCE = 'typos'
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_RECORDS = 10000
local MAX_TEXT = 4096
local ROOT_MARKERS = {
  'typos.toml',
  '_typos.toml',
  '.typos.toml',
  'Cargo.toml',
  'pyproject.toml',
  '.git',
}

local function nonempty(value)
  return type(value) == 'string' and value ~= '' and value or nil
end

local function clean(value)
  value = type(value) == 'string' and value or ''
  value = vim.trim(value:gsub('\27%[[%d;]*[mK]', ''):gsub('%c', ' '):gsub('%s+', ' '))
  if #value <= MAX_TEXT then
    return value
  end
  local stop = MAX_TEXT - 3
  while stop > 0 and (value:byte(stop + 1) or 0) >= 128 and (value:byte(stop + 1) or 0) < 192 do
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

local function natural(value)
  return type(value) == 'number' and value == value and value >= 0 and value < 2147483647 and value == math.floor(value)
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table' and type(context.bufnr) == 'number', 'typos requires LintContext')
  if context.modified then
    return { status(context, 'save-required', 'Save the buffer before running typos.') }
  end
  if #output > MAX_OUTPUT then
    return { status(context, 'output-limit', 'typos output exceeded 16 MiB.') }
  end
  local target = canonical(context.filename, context.cwd)
  local result, records = {}, 0
  local loaded = vim.api.nvim_buf_is_loaded(context.bufnr)
  local count = loaded and vim.api.nvim_buf_line_count(context.bufnr) or 0
  for raw in output:gmatch('[^\r\n]+') do
    records = records + 1
    if records > MAX_RECORDS or #result >= MAX_DIAGNOSTICS then
      result[#result + 1] = status(context, 'diagnostic-limit', 'typos report was truncated by the parser limit.')
      break
    end
    local ok, finding = pcall(vim.json.decode, raw)
    if not ok or type(finding) ~= 'table' then
      result[#result + 1] = status(context, 'invalid-report', 'typos: ' .. clean(raw))
    elseif finding.type == 'error' then
      result[#result + 1] = status(context, 'typos-error', nonempty(finding.msg) or 'typos failed.')
    elseif
      finding.type == 'typo'
      and nonempty(finding.path)
      and canonical(finding.path, root(context)) == target
      and nonempty(finding.typo)
    then
      local corrections = {}
      if type(finding.corrections) == 'table' then
        for index = 1, math.min(#finding.corrections, 16) do
          local correction = nonempty(finding.corrections[index])
          if correction then
            corrections[#corrections + 1] = clean(correction)
          end
        end
      end
      local filename = finding.line_num == nil or finding.line_num == vim.NIL
      local message = (filename and 'Filename: ' or '') .. 'Typo "' .. clean(finding.typo) .. '"'
      if #corrections > 0 then
        message = message .. '; use ' .. table.concat(corrections, ', ')
      end
      local item = {
        bufnr = context.bufnr,
        lnum = 0,
        col = 0,
        code = filename and 'filename-typo' or 'typo',
        severity = severity.WARN,
        source = SOURCE,
        message = clean(message),
        user_data = {
          typo = clean(finding.typo),
          corrections = corrections,
          filename = finding.path,
          filename_typo = filename,
        },
      }
      if
        not filename
        and natural(finding.line_num)
        and finding.line_num >= 1
        and finding.line_num <= count
        and natural(finding.byte_offset)
      then
        item.lnum = finding.line_num - 1
        local line = vim.api.nvim_buf_get_lines(context.bufnr, item.lnum, item.lnum + 1, false)[1] or ''
        local col = finding.byte_offset
        if col <= #line and line:sub(col + 1, col + #finding.typo) == finding.typo then
          item.col, item.end_lnum, item.end_col = col, item.lnum, col + #finding.typo
        end
      end
      result[#result + 1] = item
    elseif finding.type ~= 'binary_file' and finding.type ~= 'typo' then
      result[#result + 1] = status(context, 'unexpected-record', 'Unexpected typos JSON record type.')
    end
  end
  return result
end

---@param context LintContext
---@return string[]
local function arguments(context)
  local filename = assert(nonempty(context.filename), 'typos requires a named, saved file')
  return {
    '--threads',
    '1',
    '--sort',
    '--force-exclude',
    '--format',
    'json',
    '--color',
    'never',
    '--',
    absolute(filename, context.cwd),
  }
end

---@type Linter
return {
  cmd = 'typos',
  args = arguments,
  append_fname = false,
  automatic = true,
  cwd = root,
  ignore_exitcode = true, -- 0: clean; 2: typos; operational errors are parsed.
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'both',
  timeout = 30000,
}
