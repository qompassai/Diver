
-- #################################################################
-- ~/.config/nvim/lua/linters/mh_lint.lua
-- Native MISS_HIT MATLAB / Octave Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://florianschanda.github.io/miss_hit/lint.html
---@source https://github.com/florianschanda/miss_hit
--
-- Install in an isolated environment on Arch:
--   uv tool install miss-hit
-- Verify that mh_lint is on Neovim's PATH: mh_lint --version
--
-- Native Linter / LintContext interface; register 'mh_lint' for MATLAB .m
-- buffers (and Octave buffers if you use a separate octave filetype).
-- Run after saving, normally on BufWritePost. The CLI reads disk files.
-- The runner must skip unnamed buffers and reject stale process results.
-- Simulink containers are deliberately excluded: their block locations cannot
-- be mapped directly to a Neovim text buffer. No temporary files or shell.
--
-- Uses --brief to retain check IDs, --single to bound worker overhead, and
-- UTF-8 input by default. No style checks, fixing, or MATLAB execution.
-- Honors miss_hit.cfg / .miss_hit and justification pragmas automatically.
-- Low checks -> INFO; medium -> WARN; high and syntax/lex errors -> ERROR.
-- CLI lines are one-based; columns are zero-based Unicode character offsets.
-- Columns are converted to Neovim UTF-8 byte offsets against the saved buffer.
-- The brief format has no end position, so none is invented.
--
-- Optional overrides (each value is passed as a single argv entry):
--   NVIM_MH_LINT_MATLAB=2021a
--   NVIM_MH_LINT_OCTAVE=6.4       -- mutually exclusive with MATLAB override
--   NVIM_MH_LINT_ENCODING=cp1252  -- must match the saved file's encoding
--   NVIM_MH_LINT_ENTRY_POINT=my_entry
-- An entry point enables project analysis and may analyze additional files.
-- Findings in other .m files are not attached to this buffer. Configuration
-- errors are shown at the buffer start with their original location included.
-- Parser limits do not limit process-output buffering; the runner owns that.
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv
local api = vim.api

local SOURCE = 'mh_lint'
local MAX_DIAGNOSTICS = 512
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_LINE_BYTES = 64 * 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_OUTPUT_LINES = 65536
local MAX_POSITION = 2147483647

local ROOT_MARKERS = {
  { 'miss_hit.cfg', '.miss_hit' },
  '.git',
}

local SEVERITIES = {
  ['check (low)'] = diagnostic.severity.INFO,
  ['check (medium)'] = diagnostic.severity.WARN,
  ['check (high)'] = diagnostic.severity.ERROR,
  ['lex error'] = diagnostic.severity.ERROR,
  error = diagnostic.severity.ERROR,
  warning = diagnostic.severity.WARN,
  info = diagnostic.severity.INFO,
}

---@param value any
---@return string?
local function string_value(value)
  if type(value) == 'string' and value ~= '' then
    return value
  end

  return nil
end

---@param context LintContext
---@return string
local function project_root(context)
  local filename = string_value(context.filename)

  -- Prefer the nearest MISS_HIT configuration, even inside a larger repository.
  if filename ~= nil then
    local configured = fs.root(filename, { 'miss_hit.cfg', '.miss_hit' })

    if configured ~= nil then
      return fs.normalize(configured)
    end
  end

  local root = string_value(context.root)

  if root ~= nil then
    return fs.normalize(root)
  end

  if filename ~= nil then
    local detected = fs.root(filename, ROOT_MARKERS)

    if detected ~= nil then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if parent ~= nil and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(string_value(context.cwd) or vim.fn.getcwd())
end

---@param path string
---@param cwd string
---@return string
local function absolute_path(path, cwd)
  if path:sub(1, 1) ~= '/' then
    path = fs.joinpath(cwd, path)
  end

  return fs.normalize(path)
end

---@param path string
---@param cwd string
---@return string
local function canonical_path(path, cwd)
  local absolute = absolute_path(path, cwd)

  return uv.fs_realpath(absolute) or absolute
end

---@param value string
---@return string
local function clean_message(value)
  local text = vim.trim(value:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '))

  if #text > MAX_MESSAGE_BYTES then
    local finish = MAX_MESSAGE_BYTES - 3

    -- Do not split a UTF-8 codepoint when truncating.
    while finish > 0 do
      local byte = text:byte(finish + 1)

      if byte == nil or byte < 128 or byte >= 192 then
        break
      end

      finish = finish - 1
    end

    text = text:sub(1, finish) .. '...'
  end

  return text
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status_diagnostic(context, code, message)
  return {
    bufnr = context.bufnr,
    code = code,
    col = 0,
    lnum = 0,
    message = message,
    severity = diagnostic.severity.WARN,
    source = SOURCE,
  }
end

---@param value string?
---@return integer?
local function position(value)
  local number = value and tonumber(value) or nil

  if number == nil or number < 0 or number > MAX_POSITION then
    return nil
  end

  return math.floor(number)
end

---@param bufnr integer
---@param lnum integer
---@param column integer
---@return integer
local function byte_column(bufnr, lnum, column)
  if column == 0 or not api.nvim_buf_is_loaded(bufnr) then
    return 0
  end

  if lnum >= api.nvim_buf_line_count(bufnr) then
    return 0
  end

  local line = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''

  if #line > MAX_LINE_BYTES then
    return 0
  end

  local offset = 1
  local characters = 0

  while offset <= #line and characters < column do
    offset = offset + 1

    -- Neovim represents decoded buffer text as UTF-8. Skip continuation bytes.
    while offset <= #line do
      local byte = line:byte(offset)

      if byte < 128 or byte >= 192 then
        break
      end

      offset = offset + 1
    end

    characters = characters + 1
  end

  return offset - 1
end

---@param line string
---@return string?, string?, string?
local function message_parts(line)
  local location, kind, message = line:match('^(.-): (check %(%a+%)): (.*)$')

  if location == nil then
    location, kind, message = line:match('^(.-): (lex error): (.*)$')
  end

  if location == nil then
    location, kind, message = line:match('^(.-): (%a+): (.*)$')
  end

  return location, kind, message
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'mh_lint parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'mh_lint parser requires context.bufnr')

  if context.modified then
    return { status_diagnostic(context, 'save-required', 'Save this buffer before running mh_lint; it reads files from disk.') }
  end

  local filename = string_value(context.filename)

  if filename == nil then
    return { status_diagnostic(context, 'filename-required', 'Save this buffer as a MATLAB or Octave .m file before running mh_lint.') }
  end

  if #output > MAX_OUTPUT_BYTES then
    return { status_diagnostic(context, 'output-limit', 'mh_lint output exceeded the 16 MiB parser limit; results are incomplete.') }
  end

  local cwd = project_root(context)
  local target = canonical_path(filename, string_value(context.cwd) or cwd)
  ---@type vim.Diagnostic[]
  local diagnostics = {}
  ---@type table<string, boolean>
  local seen = {}
  ---@type table<string, string>
  local paths = {}
  local unexpected = false
  local limited = false
  local completed = false
  local line_count = 0

  for raw_line in output:gmatch('[^\r\n]+') do
    line_count = line_count + 1

    if line_count > MAX_OUTPUT_LINES then
      limited = true
      break
    end

    if #raw_line > MAX_LINE_BYTES then
      unexpected = true
    else
      local line = raw_line:gsub('\27%[[%d;]*[mK]', '')
      local location, kind, message = message_parts(line)
      local severity = kind and SEVERITIES[kind] or nil

      if location ~= nil and severity ~= nil and message ~= nil then
        local path, row, column = location:match('^(.*):(%d+):(%d+)$')

        if path == nil then
          path, row = location:match('^(.*):(%d+)$')
        end

        path = path or location
        local resolved = paths[path]

        if resolved == nil then
          resolved = canonical_path(path, cwd)
          paths[path] = resolved
        end

        local own_file = resolved == target
        local basename = path:match('([^/]+)$')
        local configuration = basename == 'miss_hit.cfg' or basename == '.miss_hit'
        local row_number = position(row)
        local column_number = position(column)

        if (row ~= nil and row_number == nil) or (column ~= nil and column_number == nil) then
          unexpected = true
        elseif own_file or configuration then
          local text = clean_message(message)
          local code = text:match('%[([%w_%.%-]+)%]$')
          local lnum = math.max(0, (row_number or 1) - 1)
          local col = 0

          if own_file then
            col = byte_column(context.bufnr, lnum, column_number or 0)
          else
            text = clean_message(location .. ': ' .. text)
            lnum = 0
          end

          local key = table.concat({ location, tostring(kind), text }, '\t')

          if not seen[key] then
            if #diagnostics >= MAX_DIAGNOSTICS then
              limited = true
              break
            end

            seen[key] = true
            diagnostics[#diagnostics + 1] = {
              bufnr = context.bufnr,
              code = code,
              col = col,
              lnum = lnum,
              message = text,
              severity = severity,
              source = SOURCE,
              user_data = {
                kind = kind,
                filename = path,
                line = row_number,
                character_column = column_number,
              },
            }
          end
        end
      elseif line:match('^MISS_HIT Lint Summary:') ~= nil then
        completed = true
      elseif vim.trim(line) ~= '' then
        unexpected = true
      end
    end
  end

  if unexpected then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'unparsed-output', 'mh_lint returned unexpected output. Check its arguments, configuration and Python environment; results may be incomplete.')
  elseif not completed and #diagnostics == 0 and not limited then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'missing-summary', 'mh_lint returned no completion summary or current-file diagnostics. Check the executable and timeout.')
  end

  if limited then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'result-limit', 'mh_lint reached the editor parser limit; run the CLI for the complete report.')
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'mh_lint arguments require LintContext')
  local filename = string_value(context.filename)
  assert(filename ~= nil and filename:sub(-2) == '.m', 'mh_lint requires a saved .m filename')

  local matlab = string_value(vim.env.NVIM_MH_LINT_MATLAB)
  local octave = string_value(vim.env.NVIM_MH_LINT_OCTAVE)
  assert(matlab == nil or octave == nil, 'Set only one of NVIM_MH_LINT_MATLAB and NVIM_MH_LINT_OCTAVE')

  ---@type string[]
  local args = {
    '--brief',
    '--single',
    '--input-encoding', string_value(vim.env.NVIM_MH_LINT_ENCODING) or 'utf-8',
  }

  if matlab ~= nil then
    args[#args + 1] = '--matlab'
    args[#args + 1] = matlab
  elseif octave ~= nil then
    args[#args + 1] = '--octave'
    args[#args + 1] = octave
  end

  local entry_point = string_value(vim.env.NVIM_MH_LINT_ENTRY_POINT)

  if entry_point ~= nil then
    args[#args + 1] = '--entry-point'
    args[#args + 1] = entry_point
  end

  args[#args + 1] = '--'
  args[#args + 1] = absolute_path(filename, string_value(context.cwd) or project_root(context))

  return args
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'mh_lint',
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'both',
  timeout = 60000,
}