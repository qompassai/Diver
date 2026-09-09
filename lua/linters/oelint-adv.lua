-- #################################################################
-- ~/.config/nvim/lua/linters/oelint-adv.lua
-- Native OpenEmbedded / Yocto Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/priv-kweihmann/oelint-adv
---@source https://github.com/priv-kweihmann/oelint-adv#output-message-format
---@source https://github.com/priv-kweihmann/oelint-adv#configuration-file
--
-- Install into an isolated Python environment on Arch, for example:
--   uv tool install oelint-adv
-- Ensure oelint-adv is on Neovim's PATH.
--
-- Register 'oelint-adv' for the bitbake filetype in your native linter loader.
-- Intended files: .bb, .bbappend, .bbclass, .inc and BitBake .conf files.
-- Run on BufWritePost. This CLI reads saved files, not buffer stdin.
-- Unnamed buffers must be skipped by the runner. Modified buffers produce a
-- save-required diagnostic rather than displaying locations from old content.
--
-- Project policy remains in .oelint.cfg / OELINT_CONFIG and rule files.
-- Keep fix, nobackup, print_rulefile and clear_caches disabled in that config;
-- the CLI has no negative flags to override those configured actions.
-- Use trusted configurations and custom Python rules only.
-- This module never requests --fix or creates temporary recipe copies.
--
-- Defaults: fast mode, one worker, no new cache opt-in, normal rule selection.
-- Existing configuration controls suppressions, release, constants and caches.
-- Optional overrides:
--   NVIM_OELINT_ADV_MODE=all
--   NVIM_OELINT_ADV_JOBS=2             (1..8)
--   NVIM_OELINT_ADV_RELEASE=scarthgap  (validated by oelint-adv)
--
-- Diagnostics belong only to the requested file; included-file findings are
-- filtered by canonical path. Open an included file to lint it separately.
-- Branch/permutation details are retained in messages. No columns are reported
-- by the tool, so diagnostics use column zero rather than invented ranges.
-- The runner owns cancellation, stale-result rejection and process buffering.
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local SOURCE = 'oelint-adv'
local MAX_DIAGNOSTICS = 512
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_LINE_BYTES = 64 * 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_OUTPUT_LINES = 65536
local MAX_POSITION = 2147483647
local MESSAGE_FORMAT = '{path}\t{line}\t{severity}\t{id}\t{msg}'

local ROOT_MARKERS = {
  '.oelint.cfg',
  'conf/layer.conf',
  '.git',
}

local SEVERITIES = {
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

  -- Prefer the nearest linter configuration, even inside a larger repository.
  if filename ~= nil then
    local configured = fs.root(filename, '.oelint.cfg')

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

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'oelint-adv parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'oelint-adv parser requires context.bufnr')

  if context.modified then
    return { status_diagnostic(context, 'save-required', 'Save this buffer before running oelint-adv; it reads files from disk.') }
  end

  local filename = string_value(context.filename)

  if filename == nil then
    return { status_diagnostic(context, 'filename-required', 'Save this buffer to a BitBake file before running oelint-adv.') }
  end

  if #output > MAX_OUTPUT_BYTES then
    return { status_diagnostic(context, 'output-limit', 'oelint-adv output exceeded the 16 MiB parser limit; results are incomplete.') }
  end

  local cwd = project_root(context)
  local target = canonical_path(filename, string_value(context.cwd) or cwd)
  ---@type vim.Diagnostic[]
  local diagnostics = {}
  ---@type table<string, boolean>
  local seen = {}
  ---@type table<string, string>
  local paths = {}
  local unparsed = false
  local limited = false
  local line_count = 0

  for raw_line in output:gmatch('[^\r\n]+') do
    line_count = line_count + 1

    if line_count > MAX_OUTPUT_LINES then
      limited = true
      break
    end

    if #raw_line > MAX_LINE_BYTES then
      unparsed = true
    else
      local line = raw_line:gsub('\27%[[%d;]*[mK]', '')
      local path, row, level, rule, message = line:match('^([^\t]+)\t(%d+)\t([a-z]+)\t([^\t]+)\t(.*)$')
      local severity = level and SEVERITIES[level] or nil
      local number = row and tonumber(row) or nil

      if path ~= nil and rule ~= nil and message ~= nil and severity ~= nil
        and number ~= nil and number <= MAX_POSITION and #rule <= 256
      then
        local resolved = paths[path]

        if resolved == nil then
          resolved = canonical_path(path, cwd)
          paths[path] = resolved
        end

        if resolved == target then
          local text = clean_message(message)
          local lnum = math.max(0, math.floor(number) - 1)
          local key = table.concat({ tostring(lnum), tostring(severity), rule, text }, '\t')

          if text == '' then
            unparsed = true
          elseif not seen[key] then
            if #diagnostics >= MAX_DIAGNOSTICS then
              limited = true
              break
            end

            seen[key] = true
            diagnostics[#diagnostics + 1] = {
              bufnr = context.bufnr,
              code = rule,
              col = 0,
              lnum = lnum,
              message = text,
              severity = severity,
              source = SOURCE,
            }
          end
        end
      elseif vim.trim(line) ~= '' then
        unparsed = true
      end
    end
  end

  if unparsed then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'unparsed-output', 'oelint-adv returned unexpected or oversized output. Check its configuration, arguments and Python environment; results may be incomplete.')
  end

  if limited then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'result-limit', 'oelint-adv reached the editor parser limit; run the CLI for the complete report.')
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'oelint-adv arguments require LintContext')
  local filename = string_value(context.filename)
  assert(filename ~= nil, 'oelint-adv requires a saved filename')

  local mode = string_value(vim.env.NVIM_OELINT_ADV_MODE) or 'fast'
  assert(mode == 'fast' or mode == 'all', 'NVIM_OELINT_ADV_MODE must be fast or all')

  local jobs = tonumber(string_value(vim.env.NVIM_OELINT_ADV_JOBS) or '1')
  assert(jobs ~= nil and jobs >= 1 and jobs <= 8 and jobs == math.floor(jobs),
    'NVIM_OELINT_ADV_JOBS must be an integer from 1 to 8')

  ---@type string[]
  local args = {
    '--quiet',
    '--exit-zero',
    '--output', '/dev/stderr',
    '--outputformat', 'stdout',
    '--messageformat', MESSAGE_FORMAT,
    '--jobs', tostring(math.floor(jobs)),
    '--mode', mode,
  }

  local release = string_value(vim.env.NVIM_OELINT_ADV_RELEASE)

  if release ~= nil then
    args[#args + 1] = '--release'
    args[#args + 1] = release
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
  cmd = 'oelint-adv',
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'both',
  timeout = 60000,
}