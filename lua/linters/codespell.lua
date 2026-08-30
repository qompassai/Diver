-- #################################################################
-- /qompassai/Diver/lua/linters/codespell.lua
-- Qompass AI Diver Native Codespell Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/codespell-project/codespell

local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs

local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local max = math.max
local type = type

local SOURCE = 'codespell'
local CODE = 'misspelling'

---@class CodespellParsedDiagnostic
---@field filename string
---@field line integer
---@field wrong string
---@field replacement string
---@field reason? string

---@class CodespellPositionState
---@field [string] integer

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string')

  return (
    value:gsub(
      '^%s*(.-)%s*$',
      '%1'
    )
  )
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string')

  value = value:gsub('\r\n', '\n')
  value = value:gsub('\r', '\n')
  value = trim(value)

  if #value > MESSAGE_LENGTH_MAX then
    value =
      value:sub(
        1,
        MESSAGE_LENGTH_MAX
      )
      .. '\n[message truncated]'
  end

  return value
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
  assert(path ~= '')
  assert(root ~= '')

  if path:sub(1, 7) == 'file://' then
    local ok, filename = pcall(
      vim.uri_to_fname,
      path
    )

    if
      ok
      and type(filename) == 'string'
      and filename ~= ''
    then
      return fs.normalize(filename)
    end
  end

  if fs.is_absolute(path) then
    return fs.normalize(path)
  end

  return fs.normalize(
    fs.joinpath(
      root,
      path
    )
  )
end

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(
  candidate,
  filename,
  root
)
  assert(candidate ~= '')
  assert(filename ~= '')
  assert(root ~= '')

  return normalize_path(
    candidate,
    root
  ) == filename
end

---@param value string
---@return string
local function strip_reason(value)
  assert(type(value) == 'string')

  local replacement =
    value:match(
      '^(.-)%s%s+|%s+'
    )

  if replacement ~= nil then
    return trim(replacement)
  end

  return trim(value)
end

---@param value string
---@return string?
local function extract_reason(value)
  assert(type(value) == 'string')

  local reason =
    value:match(
      '%s%s+|%s+(.+)%s*$'
    )

  if reason == nil then
    return nil
  end

  reason =
    normalize_message(reason)

  if reason == '' then
    return nil
  end

  return reason
end

---@param line string
---@return CodespellParsedDiagnostic?
local function parse_line(line)
  assert(type(line) == 'string')

  if
    line == ''
    or #line > LINE_LENGTH_MAX
  then
    return nil
  end

  --
  -- Current Codespell file diagnostic form:
  --
  --   path/file.ext:42: teh ==> the
  --
  -- Dictionary entries that cannot be corrected automatically may append:
  --
  --   path/file.ext:42: word ==> replacement  | explanation
  --
  local filename,
    line_number,
    wrong,
    replacement = line:match(
      '^(.+):(%d+):%s+(.+)%s+==>%s+(.*)$'
    )

  if
    filename == nil
    or line_number == nil
    or wrong == nil
    or replacement == nil
  then
    return nil
  end

  local parsed_line =
    tonumber(line_number)

  if parsed_line == nil then
    return nil
  end

  parsed_line =
    math.floor(parsed_line)

  if parsed_line < 1 then
    return nil
  end

  wrong =
    trim(wrong)

  replacement =
    normalize_message(replacement)

  if
    wrong == ''
    or replacement == ''
  then
    return nil
  end

  return {
    filename = filename,
    line = parsed_line,
    wrong = wrong,
    replacement = strip_reason(replacement),
    reason = extract_reason(replacement),
  }
end

---@param bufnr integer
---@param lnum integer
---@return string?
local function buffer_line(bufnr, lnum)
  if
    bufnr < 1
    or not api.nvim_buf_is_valid(bufnr)
  then
    return nil
  end

  local line_count =
    api.nvim_buf_line_count(bufnr)

  if
    lnum < 0
    or lnum >= line_count
  then
    return nil
  end

  local lines =
    api.nvim_buf_get_lines(
      bufnr,
      lnum,
      lnum + 1,
      false
    )

  local line = lines[1]

  if type(line) ~= 'string' then
    return nil
  end

  return line
end

---@param bufnr integer
---@param lnum integer
---@param wrong string
---@param state CodespellPositionState
---@return integer
local function locate_word(
  bufnr,
  lnum,
  wrong,
  state
)
  assert(lnum >= 0)
  assert(wrong ~= '')

  local text =
    buffer_line(
      bufnr,
      lnum
    )

  if text == nil then
    return 0
  end

  --
  -- Codespell itself preserves the spelling/case of the matched token in its
  -- diagnostic output. Searching literally therefore gives us a byte offset,
  -- which is exactly what vim.Diagnostic expects for `col`.
  --
  local key =
    tostring(lnum)
    .. '\0'
    .. wrong

  local start =
    state[key] or 1

  local first,
    last = text:find(
      wrong,
      start,
      true
    )

  if first == nil then
    --
    -- A changed buffer can disagree with the on-disk file that Codespell
    -- analyzed. Fall back to the first occurrence before giving up entirely.
    --
    first,
      last = text:find(
        wrong,
        1,
        true
      )
  end

  if
    first == nil
    or last == nil
  then
    return 0
  end

  state[key] =
    last + 1

  return first - 1
end

---@param entry CodespellParsedDiagnostic
---@param context LintContext
---@param filename string
---@param root string
---@param positions CodespellPositionState
---@return vim.Diagnostic?
local function diagnostic_from_entry(
  entry,
  context,
  filename,
  root,
  positions
)
  if
    not belongs_to_buffer(
      entry.filename,
      filename,
      root
    )
  then
    return nil
  end

  --
  -- Codespell reports one-based source lines.
  -- Neovim diagnostics use zero-based source lines.
  --
  local lnum = max(
    entry.line - 1,
    0
  )

  local col =
    locate_word(
      context.bufnr,
      lnum,
      entry.wrong,
      positions
    )

  local end_col =
    col + #entry.wrong

  if end_col <= col then
    end_col = col + 1
  end

  local message =
    ('Possible misspelling: %s → %s'):format(
      entry.wrong,
      entry.replacement
    )

  if entry.reason ~= nil then
    message =
      message
      .. ' ('
      .. entry.reason
      .. ')'
  end

  message =
    normalize_message(message)

  return {
    lnum = lnum,
    end_lnum = lnum,

    col = col,
    end_col = end_col,

    message = message,

    severity = WARN,

    source = SOURCE,
    code = CODE,

    user_data = {
      wrong = entry.wrong,
      replacement = entry.replacement,
      reason = entry.reason,
    },
  }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
  if output == '' then
    return {}
  end

  assert(
    type(context) == 'table',
    'codespell parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'codespell output exceeded maximum size'
  )

  local filename =
    fs.normalize(
      context.filename
    )

  local root =
    fs.normalize(
      context.root
    )

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  ---@type CodespellPositionState
  local positions = {}

  for line in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local raw =
      parse_line(line)

    if raw ~= nil then
      local entry =
        diagnostic_from_entry(
          raw,
          context,
          filename,
          root,
          positions
        )

      if entry ~= nil then
        diagnostics[#diagnostics + 1] =
          entry
      end
    end
  end

  assert(
    #diagnostics <= DIAGNOSTICS_MAX
  )

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(context.filename ~= '')
  assert(context.root ~= '')

  return {
    --
    -- Deterministic machine parsing. Codespell normally enables ANSI output
    -- only for terminals, but explicitly disabling it prevents environment or
    -- wrapper behavior from changing the diagnostic grammar.
    --
    '--disable-colors',

    --
    -- Quiet mask:
    --
    --   1  encoding fallback warnings
    --   2  binary-file warnings
    --  32  config-file announcements
    --
    -- We intentionally do NOT suppress dictionary findings or explanations.
    --
    '--quiet-level',
    '35',

    --
    -- An explicitly opened Neovim buffer can itself live in a hidden path
    -- such as `.github/`. Since we lint exactly one filename, enabling hidden
    -- files cannot cause recursive hidden-tree traversal.
    --
    '--check-hidden',

    context.filename,
  }
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(context.root ~= '')

  return fs.normalize(
    context.root
  )
end

return ---@type Linter
{
  automatic = false,

  cmd = 'codespell',

  args = args,

  append_fname = false,

  cwd = cwd,

  --
  -- Codespell returns EX_DATAERR (65) when misspellings are found.
  -- That is normal diagnostic-producing behavior.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    '.codespellrc',

    'pyproject.toml',
    'setup.cfg',

    '.git',
  },

  stdin = false,

  --
  -- Misspelling diagnostics are printed to stdout. Operational warnings and
  -- --count output use stderr.
  --
  stream = 'stdout',

  timeout = 30000,
}