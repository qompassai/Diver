-- ~/.config/nvim/lua/linters/fsharplint.lua
-- Native Neovim 0.13+ linter; Lua 5.1 syntax; no plugin dependency.
---@source https://github.com/fsprojects/FSharpLint
---@source https://github.com/fsprojects/FSharpLint/blob/master/src/FSharpLint.Console/Output.fs
--
-- Install: dotnet tool install --global dotnet-fsharplint
-- Ensure the tool installation directory is on Neovim's PATH.
-- Local tool manifests also work with `dotnet fsharplint`; restore them yourself.
-- Register with your native runner using the same convention as cfn-lint.lua.
-- Trigger after BufWritePost for fsharp buffers. No stdin or automatic fixes.
--
-- Default: lint the saved file; force File mode to avoid wildcard expansion.
-- Optional NVIM_FSHARPLINT_PROJECT: an explicit .fsproj path, relative to cwd
-- selected below or absolute. Enables project analysis; only this buffer's
-- findings are published. Project dependencies must already be restored.
-- Optional NVIM_FSHARPLINT_CONFIG: explicit JSON config path; otherwise use
-- nearest ancestor fsharplint.json. Without either, use tool defaults.
-- Your runner should cancel/discard results when the buffer changes.
-- Avoid running this alongside FSAC's FSharpLint diagnostics if duplicates
-- are unwanted. No LSP settings are changed by this module.
local fs = vim.fs
local severity = vim.diagnostic.severity
local SOURCE = 'fsharplint'
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_RECORDS = 10000
local MAX_TEXT = 4096
local MAX_LINE = 1024 * 1024
local ROOT_MARKERS = { 'fsharplint.json', 'global.json', '.config/dotnet-tools.json', '.git' }

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

-- FSharpLint passes through F# compiler columns: zero-based UTF-16 units.
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

local function config_file(context)
  local override = nonempty(vim.env.NVIM_FSHARPLINT_CONFIG)
  if override then return absolute(override, root(context)) end
  local directory = fs.root(absolute(context.filename, context.cwd), { 'fsharplint.json' })
  return directory and fs.joinpath(directory, 'fsharplint.json') or nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table' and type(context.bufnr) == 'number', 'fsharplint requires LintContext')
  if context.modified then
    return { status(context, 'save-required', 'Save the buffer before running FSharpLint.') }
  end
  if #output > MAX_OUTPUT then
    return { status(context, 'output-limit', 'FSharpLint output exceeded 16 MiB.') }
  end
  local target = canonical(context.filename, context.cwd)
  local diagnostics, records, last = {}, 0, nil
  local loaded = vim.api.nvim_buf_is_loaded(context.bufnr)
  local count = loaded and vim.api.nvim_buf_line_count(context.bufnr) or 0
  local cache = {}
  local function position(row, column)
    row, column = tonumber(row), tonumber(column)
    if not integer(row) or row > count or not column or column < 0
      or column ~= math.floor(column) then return nil end
    local lnum = row - 1
    if cache[lnum] == nil then
      cache[lnum] = vim.api.nvim_buf_get_lines(context.bufnr, lnum, lnum + 1, false)[1] or ''
    end
    local col = byte_column(cache[lnum], column)
    if col == nil then return nil end
    return lnum, col
  end
  local saw_warning, saw_completion = false, false
  local unrecognized
  for raw in output:gmatch('[^\r\n]+') do
    records = records + 1
    if records > MAX_RECORDS or #diagnostics >= MAX_DIAGNOSTICS then
      diagnostics[#diagnostics + 1] = status(context, 'diagnostic-limit', 'FSharpLint report was truncated by the parser limit.')
      break
    end
    local line = raw:gsub('\27%[[%d;]*[mK]', ''):gsub('\r$', '')
    local path, sl, sc, el, ec, rule, message = line:match('^(.*)%((%d+),(%d+),(%d+),(%d+)%)%s*:%s*FSharpLint warning%s+(FL%d+):%s*(.*)$')
    if path then
      saw_warning, last = true, nil
      if canonical(path, root(context)) == target then
        local lnum, col = position(sl, sc)
        local end_lnum, end_col = position(el, ec)
        local item = { bufnr = context.bufnr, lnum = lnum or 0, col = col or 0,
          severity = severity.WARN, source = SOURCE, code = rule,
          message = clean(message), user_data = { filename = path, rule = rule,
            url = 'https://fsprojects.github.io/FSharpLint/how-tos/rules/' .. rule .. '.html' } }
        if lnum and end_lnum and (end_lnum > lnum or (end_lnum == lnum and end_col >= col)) then
          item.end_lnum, item.end_col = end_lnum, end_col
        end
        diagnostics[#diagnostics + 1], last = item, item
      end
    elseif line:match('^FSharpLint error:') then
      local item = status(context, 'fsharplint-error', line)
      item.severity = severity.ERROR
      diagnostics[#diagnostics + 1], last = item, item
    elseif line:match('^=+ Summary: %d+ warnings =+$') then
      saw_completion, last = true, nil
    elseif line:match('^Running FSharpLint') or line:match('^Starting')
      or line:match('^WARNING: Using a project') or line:match('^%-+$')
      or line:match('^=+ Linting ') or line:match('^=+ Finished: ') then
      last = nil
    elseif vim.trim(line) ~= '' then
      if last then last.message = clean(last.message .. ' ' .. line)
      elseif not unrecognized then unrecognized = clean(line) end
    end
  end
  if not saw_warning and not saw_completion and #diagnostics == 0 then
    diagnostics[1] = status(context, 'no-report', 'FSharpLint did not return a recognized report. '
      .. (unrecognized or 'Check the .NET SDK, tool installation, and configuration.'))
  end
  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  local filename = assert(nonempty(context.filename), 'FSharpLint requires a named, saved file')
  local project = nonempty(vim.env.NVIM_FSHARPLINT_PROJECT)
  local target = project and absolute(project, root(context)) or absolute(filename, context.cwd)
  local args = { 'fsharplint', '--format', 'MSBuild', 'lint', '--file-type', project and 'Project' or 'File' }
  local config = config_file(context)
  if config then
    args[#args + 1], args[#args + 2] = '--lint-config', config
  end
  args[#args + 1] = target
  return args
end

---@type Linter
return {
  cmd = 'dotnet',
  args = arguments,
  append_fname = false,
  automatic = true,
  cwd = root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'both',
  timeout = 120000,
}