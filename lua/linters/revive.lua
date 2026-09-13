
-- #################################################################
-- ~/.config/nvim/lua/linters/revive.lua
-- Native Revive Go Linter; self-contained configuration, Lua 5.1 compatible.
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/mgechev/revive/tree/v1.16.0
--
-- TOOL INSTALLATION (Arch Linux):
--   sudo pacman -S --needed go
--   GOBIN="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/tools/bin" \
--     go install github.com/mgechev/revive@v1.16.0
--   "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/tools/bin/revive" -version
-- For a custom NVIM_APPNAME, use stdpath('data')/tools/bin for GOBIN.
-- Installation may download Go modules/toolchains; linting never installs them.
-- Revive v1.16.0 was tested. The bundled config lists all 104 built-in rules.
--
-- REGISTRATION:
--   local lint = require('linters')
--   lint.linters_by_ft.go = lint.linters_by_ft.go or {}
--   if not vim.tbl_contains(lint.linters_by_ft.go, 'revive') then
--     table.insert(lint.linters_by_ft.go, 'revive')
--   end
-- Use BufWritePost. The CLI has no stdin mode. The parser marks modified
-- buffers save-required. The runner must discard results after edits/renames.
-- This is your Native Linter / LintContext interface, not nvim-lint.
--
-- CONFIGURATION POLICY:
-- Edit CONFIG_TOML here: every global field, both directives, and every rule's
-- arguments/severity/disabled/exclude fields are explicit. The 23 standard
-- rules are enabled; the other 81 are explicitly disabled. Optional argument
-- values are fully set, even for disabled rules; enabling them is a separate
-- policy decision. Empty argument lists mean no optional flags/exceptions.
-- Both directive checks require rule names and reasons for disabling checks.
-- A private runtime TOML is necessary because Revive only accepts a config
-- pathname. This file creates it lazily and removes it on normal Neovim exit.
-- No project TOML or source file is created or overwritten. Project/global
-- revive.toml is not merged: this embedded policy is authoritative.
--
-- go-version is explicitly prepended from the nearest go.mod go directive;
-- without one, TOOLING.fallback_go_version is used (1.26.0). No forced version
-- is applied to a module that already declares one. Go workspaces are not
-- flattened. Only the current saved file is linted, so package-wide/type-based
-- analysis may be incomplete compared with running Revive on its package.
-- Generated files retain Revive's normal skip policy (ignore-generated-header=false).
--
-- CLI POLICY: -config generated path; -formatter json; -max_open_files 64;
-- -set_exit_status=false (TOML exit codes govern); -version=false;
-- -exclude list empty; -- before one absolute filename; -h/-help omitted.
-- Alternate formatters and recursive/package scans are not selected.
-- The old enableAllRules spelling is not used; enable-all-rules=false and
-- enable-default-rules=false prevent future releases silently adding checks.
-- package-naming's mutually exclusive custom regexp is documented beside its
-- options. Removed/deprecated var-naming package options are not emitted.
-- For list-valued flags, omission from arguments explicitly means disabled;
-- no invented '=false' flag strings are supplied to Revive.
--
-- TOOL ENVIRONMENT: no color, error-only internal logs, local Go toolchain,
-- GOPROXY/GOSUMDB off. Remaining environment (PATH/HOME/GOPATH/GOCACHE/GOFLAGS,
-- GOOS/GOARCH and workspace settings) is inherited for the installed toolchain.
-- This is not an OS sandbox. Missing dependency export data may reduce typed
-- checks; prepare dependencies separately rather than downloading while editing.
--
-- DIAGNOSTICS: JSON null is a clean result; severities and metadata are kept.
-- Go token columns are one-based bytes; Lua converts them to zero-based byte
-- positions. No basename-only matching, invented one-character ranges, or
-- dropped bufnr fields. End ranges are used only when valid for this buffer.
-- //line-remapped filenames are kept out of unrelated source locations.
-- Operational errors remain visible through the runner and invalid-report
-- statuses; stdout alone is JSON, stderr is not mixed into the report.
--
-- LIMITS: 60s runner timeout, 64 open files in Revive, 16 MiB parsed output,
-- 10,000 examined records, 512 diagnostics plus status notices, 4096-byte
-- messages, 256 KiB go.mod, 32 private configs per module instance/session.
-- Output limits are checked after collection, not a child-process memory cap.
-- Normal Lua loading performs no disk writes or external commands.
--
-- VALIDATION: Revive v1.16.0 accepted all 104 rule configurations. Real CLI
-- and headless Neovim 0.12.5 tests passed; LuaLS 3.19.1: zero diagnostics.
-- Neovim 0.13 was unavailable. Only APIs present in 0.12 are used.
--
local CONFIG_TOML = [=[
# Revive v1.16.0 explicit policy. Go version is prepended by Lua.
ignore-generated-header = false
confidence = 0.8
severity = "warning"
enable-all-rules = false
enable-default-rules = false
error-code = 1
warning-code = 1
exclude = []

# Both directive checks are explicitly enabled at warning severity.
[directive.specify-disable-reason]
severity = "warning"
[directive.specify-disable-rule]
severity = "warning"

# Empty CSV allowlists; a^ matches no function, so no functions are ignored.
[rule.add-constant]
arguments = [{ max-lit-count = "2", allow-strs = "", allow-ints = "", allow-floats = "", ignore-funcs = "a^" }]
severity = "warning"
disabled = true
exclude = []

[rule.argument-limit]
arguments = [8]
severity = "warning"
disabled = true
exclude = []

[rule.atomic]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.banned-characters]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.bare-return]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.blank-imports]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.bool-literal-in-expr]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.call-to-gc]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.cognitive-complexity]
arguments = [7]
severity = "warning"
disabled = true
exclude = []

[rule.comment-spacings]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.comments-density]
arguments = [0]
severity = "warning"
disabled = true
exclude = []

[rule.confusing-naming]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.confusing-results]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.constant-logical-expr]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.context-as-argument]
arguments = [{ allow-types-before = "" }]
severity = "warning"
disabled = false
exclude = []

[rule.context-keys-type]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.cyclomatic]
arguments = [10]
severity = "warning"
disabled = true
exclude = []

[rule.datarace]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.deep-exit]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.defer]
arguments = [["loop", "call-chain", "method-call", "return", "recover", "immediate-recover"]]
severity = "warning"
disabled = true
exclude = []

[rule.dot-imports]
arguments = [{ allowed-packages = [] }]
severity = "warning"
disabled = false
exclude = []

[rule.duplicated-imports]
arguments = []
severity = "warning"
disabled = true
exclude = []

# Flags preserve-scope and allow-jump are both disabled (empty list).
[rule.early-return]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.empty-block]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.empty-lines]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.enforce-map-style]
arguments = ["any"]
severity = "warning"
disabled = true
exclude = []

[rule.enforce-repeated-arg-type-style]
arguments = [{ func-arg-style = "any", func-ret-val-style = "any" }]
severity = "warning"
disabled = true
exclude = []

[rule.enforce-slice-style]
arguments = ["any"]
severity = "warning"
disabled = true
exclude = []

# Flags allow-no-default and allow-default-not-last are disabled.
[rule.enforce-switch-style]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.epoch-naming]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.error-naming]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.error-return]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.error-strings]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.errorf]
arguments = []
severity = "warning"
disabled = false
exclude = []

# All nine optional flags are disabled: check-private-receivers,
# disable-stuttering-check, say-repetitive-instead-of-stutters,
# check-public-interface, disable-checks-on-constants/functions/methods/types/variables.
[rule.exported]
arguments = []
severity = "warning"
disabled = false
exclude = []

# Disabled until a project-specific header regexp is supplied.
[rule.file-header]
arguments = [""]
severity = "warning"
disabled = true
exclude = []

[rule.file-length-limit]
arguments = [{ max = 0, skip-comments = false, skip-blank-lines = false }]
severity = "warning"
disabled = true
exclude = []

[rule.filename-format]
arguments = ["^[_a-zA-Z][_a-zA-Z0-9]*\\.go$"]
severity = "warning"
disabled = true
exclude = []

[rule.flag-parameter]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.forbidden-call-in-wg-go]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.function-length]
arguments = [50, 75]
severity = "warning"
disabled = true
exclude = []

[rule.function-result-limit]
arguments = [3]
severity = "warning"
disabled = true
exclude = []

[rule.get-return]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.identical-branches]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.identical-ifelseif-branches]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.identical-ifelseif-conditions]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.identical-switch-branches]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.identical-switch-conditions]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.if-return]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.import-alias-naming]
arguments = [{ allow-regex = "^[a-z][a-z0-9]{0,}$", deny-regex = "a^" }]
severity = "warning"
disabled = true
exclude = []

[rule.import-shadowing]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.imports-blocklist]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.increment-decrement]
arguments = []
severity = "warning"
disabled = false
exclude = []

# preserve-scope is disabled.
[rule.indent-error-flow]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.inefficient-map-lookup]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.line-length-limit]
arguments = [{ max = 80, excludes = [] }]
severity = "warning"
disabled = true
exclude = []

[rule.marshal-receiver]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.max-control-nesting]
arguments = [5]
severity = "warning"
disabled = true
exclude = []

[rule.max-public-structs]
arguments = [5]
severity = "warning"
disabled = true
exclude = []

[rule.modifies-parameter]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.modifies-value-receiver]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.multiline-if-init]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.nested-structs]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.optimize-operands-order]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.package-comments]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.package-directory-mismatch]
arguments = [{ ignore-directories = ["testdata"] }]
severity = "warning"
disabled = true
exclude = []

# convention-name-check-regex is omitted: its presence is incompatible with
# specifying skip-convention-name-check, even false. Built-in conventions selected.
[rule.package-naming]
arguments = [{ skip-convention-name-check = false, skip-top-level-check = false, skip-default-bad-name-check = false, check-extra-bad-name = false, user-defined-bad-names = [], skip-collision-with-common-std = false, check-collision-with-all-std = false }]
severity = "warning"
disabled = true
exclude = []

[rule.range]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.range-val-address]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.range-val-in-closure]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.receiver-naming]
arguments = [{ max-length = -1 }]
severity = "warning"
disabled = false
exclude = []

[rule.redefines-builtin-id]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.redundant-build-tag]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.redundant-import-alias]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.redundant-test-main-exit]
arguments = []
severity = "warning"
disabled = true
exclude = []

# No scope/regexp/message triples: no project-specific string policies.
[rule.string-format]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.string-of-int]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.struct-tag]
arguments = []
severity = "warning"
disabled = true
exclude = []

# preserve-scope is disabled.
[rule.superfluous-else]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.time-date]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.time-equal]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.time-naming]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.unchecked-type-assertion]
arguments = [{ accept-ignored-assertion-result = false }]
severity = "warning"
disabled = true
exclude = []

[rule.unconditional-recursion]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.unexported-naming]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.unexported-return]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.unhandled-error]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.unnecessary-format]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.unnecessary-if]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.unnecessary-stmt]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.unreachable-code]
arguments = []
severity = "warning"
disabled = false
exclude = []

[rule.unsecure-url-scheme]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.unused-parameter]
arguments = [{ allow-regex = "^_$" }]
severity = "warning"
disabled = false
exclude = []

[rule.unused-receiver]
arguments = [{ allow-regex = "^_$" }]
severity = "warning"
disabled = true
exclude = []

[rule.use-any]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.use-errors-new]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.use-fmt-print]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.use-slices-sort]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.use-waitgroup-go]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.useless-break]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.useless-fallthrough]
arguments = []
severity = "warning"
disabled = true
exclude = []

[rule.var-declaration]
arguments = []
severity = "warning"
disabled = false
exclude = []

# Deprecated package-name options are intentionally omitted; use package-naming.
[rule.var-naming]
arguments = [[], [], [{ skip-initialism-name-checks = false, upper-case-const = false }]]
severity = "warning"
disabled = false
exclude = []

[rule.waitgroup-by-value]
arguments = []
severity = "warning"
disabled = true
exclude = []
]=]

local fs = vim.fs
local uv = vim.uv
local severity = vim.diagnostic.severity
local SOURCE = 'revive'
local MAX_OUTPUT = 16 * 1024 * 1024
local MAX_DIAGNOSTICS = 512
local MAX_RECORDS = 10000
local MAX_MESSAGE = 4096
local MAX_CONFIGS = 32
local MAX_GOMOD = 256 * 1024
local ROOT_MARKERS = { 'go.mod', 'go.work', '.git' }
local TOOLING = {
  executable = fs.joinpath(vim.fn.stdpath('data'), 'tools', 'bin', 'revive'),
  formatter = 'json',
  max_open_files = 64,
  set_exit_status = false,
  version = false,
  excludes = {}, -- CLI -exclude values; TOML also explicitly sets exclude=[].
  timeout_ms = 60000,
  automatic = true,
  fallback_go_version = '1.26.0',
  env = {
    NO_COLOR = '1',
    REVIVE_FORCE_COLOR = '0',
    REVIVE_LOG_LEVEL = 'error',
    GOTOOLCHAIN = 'local',
    GOPROXY = 'off',
    GOSUMDB = 'off',
  },
}

local function nonempty(value)
  return type(value) == 'string' and value ~= '' and value or nil
end

local function absolute(path, cwd)
  if path:sub(1, 1) ~= '/' then
    path = fs.joinpath(cwd, path)
  end
  return fs.normalize(path)
end

---@param context LintContext
---@return string
local function root(context)
  local cwd = nonempty(context.cwd) or vim.fn.getcwd()
  local file = nonempty(context.filename)
  if file then
    file = absolute(file, cwd)
    return fs.root(file, { 'go.mod' }) or fs.root(file, ROOT_MARKERS) or fs.dirname(file) or cwd
  end
  return nonempty(context.root) or cwd
end

local function canonical(path, cwd)
  path = absolute(path, cwd)
  return uv.fs_realpath(path) or path
end

local function clean(message)
  message = vim.trim(message:gsub('[%z\1-\31\127]', ' '):gsub('%s+', ' '))
  if #message <= MAX_MESSAGE then
    return message
  end
  local stop = MAX_MESSAGE - 3
  while stop > 0 do
    local byte = message:byte(stop + 1)
    if not byte or byte < 128 or byte >= 192 then
      break
    end
    stop = stop - 1
  end
  return message:sub(1, stop) .. '...'
end

---@return vim.Diagnostic
local function status(context, code, message)
  return {
    bufnr = context.bufnr,
    lnum = 0,
    col = 0,
    code = code,
    message = clean(message),
    severity = severity.WARN,
    source = SOURCE,
  }
end

local function integer(value)
  return type(value) == 'number'
    and value >= 0
    and value < 2147483647
    and value == math.floor(value)
end

local function position(value, context)
  if
    type(value) ~= 'table'
    or not integer(value.Line)
    or value.Line < 1
    or not integer(value.Column)
    or value.Column < 1
  then
    return nil
  end
  if value.Line > vim.api.nvim_buf_line_count(context.bufnr) then
    return nil
  end
  local row = value.Line - 1
  local line = vim.api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1] or ''
  if value.Column - 1 > #line then
    return row, 0, false
  end
  return row, value.Column - 1, true
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(
    type(context) == 'table' and type(context.bufnr) == 'number',
    'revive requires LintContext'
  )
  if not nonempty(context.filename) then
    return {
      status(context, 'filename-required', 'Save and name this Go buffer before running Revive.'),
    }
  end
  if context.modified then
    return {
      status(
        context,
        'save-required',
        'Revive reads the saved file; save the buffer before linting.'
      ),
    }
  end
  if #output > MAX_OUTPUT then
    return { status(context, 'output-limit', 'Revive output exceeded the 16 MiB parser limit.') }
  end
  -- Revive's JSON formatter serializes its nil slice as null on a clean run.
  if vim.trim(output) == 'null' then
    return {}
  end
  local ok, report = pcall(vim.json.decode, output)
  if not ok or type(report) ~= 'table' or not vim.islist(report) or not output:match('^%s*%[') then
    return {
      status(
        context,
        'invalid-report',
        'Revive did not return JSON. Check its executable, embedded configuration and CLI stderr.'
      ),
    }
  end
  local cwd = root(context)
  local target = canonical(context.filename, nonempty(context.cwd) or cwd)
  local results, malformed, foreign = {}, false, false
  local limited = #report > MAX_RECORDS
  for index = 1, math.min(#report, MAX_RECORDS) do
    if #results >= MAX_DIAGNOSTICS then
      limited = true
      break
    end
    local issue = report[index]
    if type(issue) ~= 'table' or not nonempty(issue.Failure) then
      malformed = true
    else
      local range = type(issue.Position) == 'table' and issue.Position or {}
      local start = type(range.Start) == 'table' and range.Start or {}
      local finish = type(range.End) == 'table' and range.End or {}
      local filename = nonempty(start.Filename)
      if filename and canonical(filename, cwd) ~= target then
        foreign = true
      else
        local row, col, exact = position(start, context)
        local end_row, end_col, end_exact = position(finish, context)
        local item = {
          bufnr = context.bufnr,
          lnum = row or 0,
          col = col or 0,
          severity = issue.Severity == 'error' and severity.ERROR or severity.WARN,
          source = SOURCE,
          message = clean(issue.Failure),
          code = nonempty(issue.RuleName) and clean(issue.RuleName) or nil,
          user_data = {
            category = nonempty(issue.Category) and clean(issue.Category) or nil,
            confidence = type(issue.Confidence) == 'number' and issue.Confidence or nil,
            filename = filename and clean(filename) or nil,
            offset = integer(start.Offset) and start.Offset or nil,
            replacement_available = nonempty(issue.ReplacementLine) ~= nil,
          },
        }
        local end_file = nonempty(finish.Filename)
        if
          exact
          and end_exact
          and row
          and end_row
          and end_file
          and canonical(end_file, cwd) == target
          and (end_row > row or (end_row == row and end_col >= col))
        then
          item.end_lnum, item.end_col = end_row, end_col
        end
        results[#results + 1] = item
      end
    end
  end
  if malformed or foreign then
    results[#results + 1] = status(
      context,
      'incomplete-report',
      'Some Revive results were malformed or named another file. Check source //line directives and the full CLI report.'
    )
  end
  if limited then
    results[#results + 1] = status(
      context,
      'result-limit',
      'Revive reached the editor diagnostic limit; run the CLI for all findings.'
    )
  end
  return results
end

local function go_version(cwd)
  local path = fs.joinpath(cwd, 'go.mod')
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return TOOLING.fallback_go_version
  end
  assert(stat.size <= MAX_GOMOD, 'go.mod exceeds the 256 KiB reader limit')
  local fd = assert(uv.fs_open(path, 'r', 0))
  local text, read_error = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  assert(text, read_error)
  for line in text:gmatch('[^\r\n]+') do
    local version = line:match('^%s*go%s+(%d+%.%d+%.?%d*)%s*')
    if version then
      return version
    end
  end
  return TOOLING.fallback_go_version
end

---@type string?
local temporary_directory
---@type table<string, string>
local configs = {}
local config_count = 0

local function cleanup()
  for _, path in pairs(configs) do
    uv.fs_unlink(path)
  end
  if temporary_directory then
    uv.fs_rmdir(temporary_directory)
  end
end

local function config_path(version)
  if configs[version] then
    return configs[version]
  end
  assert(config_count < MAX_CONFIGS, 'Revive temporary config limit reached; restart Neovim')
  if not temporary_directory then
    -- mkdtemp creates a unique private directory, mode 0700 on Linux.
    temporary_directory = assert(uv.fs_mkdtemp(vim.fn.tempname() .. '-revive-XXXXXX'))
    vim.api.nvim_create_autocmd('VimLeavePre', {
      once = true,
      callback = cleanup,
      desc = 'Remove private Revive configuration files',
    })
  end
  local path = fs.joinpath(temporary_directory, 'go-' .. version .. '.toml')
  local content = 'go-version = "' .. version .. '"\n' .. CONFIG_TOML
  local fd = assert(uv.fs_open(path, 'wx', 384)) -- 0600; exclusive creation.
  local offset = 0
  while offset < #content do
    local written, write_error = uv.fs_write(fd, content:sub(offset + 1), offset)
    if not written or written == 0 then
      uv.fs_close(fd)
      uv.fs_unlink(path)
      error(write_error or 'Could not write Revive configuration')
    end
    offset = offset + written
  end
  assert(uv.fs_close(fd))
  configs[version] = path
  config_count = config_count + 1
  return path
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'revive arguments require LintContext')
  local file = nonempty(context.filename)
  assert(file, 'Revive requires a named, saved Go file')
  local cwd = root(context)
  file = absolute(file, nonempty(context.cwd) or cwd)
  local stat = uv.fs_stat(file)
  assert(stat and stat.type == 'file', 'Revive input must be an existing regular file')
  local args = {
    '-config',
    config_path(go_version(cwd)),
    '-formatter',
    TOOLING.formatter,
    '-max_open_files',
    tostring(TOOLING.max_open_files),
    '-set_exit_status=' .. tostring(TOOLING.set_exit_status),
    '-version=' .. tostring(TOOLING.version),
  }
  for _, pattern in ipairs(TOOLING.excludes) do
    args[#args + 1] = '-exclude'
    args[#args + 1] = pattern
  end
  args[#args + 1] = '--'
  args[#args + 1] = file
  return args
end

---@type Linter
return {
  cmd = TOOLING.executable,
  args = arguments,
  append_fname = false,
  automatic = TOOLING.automatic,
  cwd = root,
  env = TOOLING.env,
  exit_codes = { 0, 1 },
  ignore_exitcode = false,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'stdout',
  timeout = TOOLING.timeout_ms,
}