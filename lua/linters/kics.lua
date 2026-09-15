-- #################################################################
-- ~/.config/nvim/lua/linters/kics.lua
-- Native KICS Infrastructure-as-Code Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/Checkmarx/kics
---@source https://docs.kics.io/latest/commands/
---@source https://docs.kics.io/latest/results/
--
-- Requires python3 and kics on PATH, including KICS query/library assets.
-- Linter / LintContext interface for Neovim 0.13+. Register 'kics' only for
-- supported IaC buffers: Terraform, Dockerfile, Kubernetes, CloudFormation,
-- Ansible, etc. Prefer BufWritePost; this scanner reads saved files.
-- A single-file scan cannot replace a complete repository security scan.
--
-- KICS writes reports to disk. An embedded Python stdlib bridge creates a
-- private temporary report directory, invokes KICS without a shell, reads a
-- bounded JSON report, and removes the directory on success, failure, timeout
-- and SIGTERM. SIGKILL cannot run cleanup; avoid hard-killing the bridge.
-- Scan lifetime: 110 seconds; outer runner timeout: 120 seconds.
-- The runner owns stale-result rejection. No input copies or auto-remediation.
--
-- Secrets scanning remains enabled. Diagnostic messages retain only query
-- names/descriptions; actual/expected values, snippets, resource names and
-- search values are not copied. KICS reports can contain secrets, hence the
-- private directory and restrictive umask. Raw process logs are suppressed.
-- Full-description downloads and crash reporting are disabled for this child.
--
-- Options (absolute paths recommended):
--   NVIM_KICS_CONFIG=/path/kics.config   (otherwise use project kics.config)
--   NVIM_KICS_QUERIES_PATH=/path/assets/queries
--   NVIM_KICS_LIBRARIES_PATH=/path/assets/libraries
-- KICS_* environment settings remain available; editor-owned flags override
-- path, report/log destinations, concurrency and result exit-code policy.
-- CLI flags and report schema checked against upstream docs; KICS itself was
-- not available for an end-to-end scan during creation.
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv
local json = vim.json
local SOURCE = 'kics'
local MAX_OUTPUT_BYTES = 16 * 1024 * 1024
local MAX_MESSAGE_BYTES = 4096
local MAX_DIAGNOSTICS = 512
local MAX_QUERIES = 8192
local MAX_FINDINGS = 32768
local ROOT_MARKERS = { 'kics.config', '.git' }
local SEVERITIES = {
  CRITICAL = diagnostic.severity.ERROR,
  HIGH = diagnostic.severity.ERROR,
  MEDIUM = diagnostic.severity.WARN,
  LOW = diagnostic.severity.INFO,
  INFO = diagnostic.severity.HINT,
  TRACE = diagnostic.severity.HINT,
}

local BRIDGE = [=[
import csv, io, json, os, pathlib, signal, subprocess, sys, tempfile
LIMIT = 16 * 1024 * 1024

def interrupted(signum, frame):
    raise SystemExit(128 + signum)

signal.signal(signal.SIGTERM, interrupted)
os.umask(0o077)

def fail(code):
    print(json.dumps({"bridge_error": code}))

try:
    options = json.loads(sys.argv[1])
    if options.get("modified"):
        fail("save-required")
        sys.exit(0)
    target = pathlib.Path(options["filename"])
    if not target.is_file():
        fail("file-unavailable")
        sys.exit(0)
    encoded = io.StringIO()
    csv.writer(encoded, lineterminator="").writerow([str(target)])
    env = os.environ.copy()
    env["DISABLE_CRASH_REPORT"] = "0"
    with tempfile.TemporaryDirectory(prefix="nvim-kics-") as directory:
        args = ["kics", "scan", "--path", encoded.getvalue(),
                "--output-path", directory, "--output-name", "results",
                "--report-formats", "json", "--log-path", directory,
                "--payload-path", "", "--no-color", "--no-progress",
                "--silent", "--verbose=false", "--ci=false",
                "--disable-full-descriptions", "--parallel", "1",
                "--ignore-on-exit", "results"]
        for key, flag in (("config", "--config"), ("queries", "--queries-path"),
                          ("libraries", "--libraries-path")):
            if options.get(key):
                value = options[key]
                if key == "queries":
                    stream = io.StringIO()
                    csv.writer(stream, lineterminator="").writerow([value])
                    value = stream.getvalue()
                args.extend([flag, value])
        completed = subprocess.run(args, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   env=env, timeout=110, check=False)
        report = pathlib.Path(directory) / "results.json"
        if not report.is_file():
            fail("missing-report")
        else:
            with report.open("rb") as handle:
                raw = handle.read(LIMIT + 1)
            if len(raw) > LIMIT:
                fail("output-limit")
            else:
                data = json.loads(raw)
                if not isinstance(data, dict):
                    fail("invalid-report")
                else:
                    data["editor_exit_code"] = completed.returncode
                    sys.stdout.write(json.dumps(data, ensure_ascii=False))
except subprocess.TimeoutExpired:
    fail("scan-timeout")
except FileNotFoundError:
    fail("executable-or-file-missing")
except (OSError, ValueError, KeyError, TypeError):
    fail("bridge-failure")
]=]

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

  -- Prefer the nearest KICS configuration, even inside a larger repository.
  if filename ~= nil then
    local configured = fs.root(filename, 'kics.config')

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

---@param value any
---@return boolean
local function positive(value)
  return type(value) == 'number' and value > 0
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(type(context) == 'table', 'kics parser requires LintContext')
  assert(type(context.bufnr) == 'number', 'kics parser requires context.bufnr')
  if context.modified then
    return { status_diagnostic(context, 'save-required', 'Save this buffer before scanning with KICS.') }
  end
  if #output > MAX_OUTPUT_BYTES then
    return { status_diagnostic(context, 'output-limit', 'KICS report exceeded the 16 MiB parser limit.') }
  end
  local ok, report = pcall(json.decode, output)
  if not ok or type(report) ~= 'table' then
    return { status_diagnostic(context, 'invalid-report', 'KICS returned no valid report. Check python3, kics, configuration and the timeout.') }
  end
  local bridge_error = string_value(report.bridge_error)
  if bridge_error ~= nil then
    return { status_diagnostic(context, 'scan-failed', 'KICS scan unavailable (' .. clean_message(bridge_error) .. '). Check the saved file, executable, query assets and configuration.') }
  end
  local queries = report.queries
  if type(queries) ~= 'table' or not vim.islist(queries) then
    return { status_diagnostic(context, 'invalid-report', 'KICS report contains no query list.') }
  end
  local filename = string_value(context.filename)
  if filename == nil then
    return { status_diagnostic(context, 'filename-required', 'KICS requires a saved filename.') }
  end
  local cwd = project_root(context)
  local target = canonical_path(filename, string_value(context.cwd) or cwd)
  ---@type vim.Diagnostic[]
  local diagnostics = {}
  local malformed = false
  local limited = #queries > MAX_QUERIES
  local inspected = 0
  for query_index = 1, math.min(#queries, MAX_QUERIES) do
    local query = queries[query_index]
    if type(query) ~= 'table' or type(query.files) ~= 'table' or not vim.islist(query.files) then
      malformed = true
    else
      local name = string_value(query.query_name) or 'Infrastructure security finding'
      local description = string_value(query.description)
      local message = name .. (description ~= nil and ': ' .. description or '')
      local level = type(query.severity) == 'string' and query.severity:upper() or 'MEDIUM'
      for file_index = 1, #query.files do
        inspected = inspected + 1
        if inspected > MAX_FINDINGS or #diagnostics >= MAX_DIAGNOSTICS then
          limited = true
          break
        end
        local finding = query.files[file_index]
        if type(finding) ~= 'table' or string_value(finding.file_name) == nil then
          malformed = true
        elseif canonical_path(finding.file_name, cwd) == target then
          local line = finding.line
          local lnum = 0
          if type(line) == 'number' and line >= 1 and line <= 2147483647 then
            lnum = math.floor(line) - 1
          end
          local code = string_value(query.query_id)
          diagnostics[#diagnostics + 1] = {
            bufnr = context.bufnr,
            code = code and clean_message(code) or nil,
            col = 0,
            lnum = lnum,
            message = clean_message(message),
            severity = SEVERITIES[level] or diagnostic.severity.WARN,
            source = SOURCE,
            user_data = {
              severity = level,
              cwe = type(query.cwe) == 'string' and clean_message(query.cwe) or nil,
              platform = type(query.platform) == 'string' and clean_message(query.platform) or nil,
              query_url = type(query.query_url) == 'string' and clean_message(query.query_url) or nil,
            },
          }
        end
      end
    end
    if inspected > MAX_FINDINGS or #diagnostics >= MAX_DIAGNOSTICS then
      break
    end
  end
  if malformed then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'malformed-results', 'Some KICS findings could not be decoded; results are incomplete.')
  end
  if positive(report.files_failed_to_scan) or positive(report.queries_failed_to_execute)
    or positive(report.queries_failed_to_compute_similarity_id)
    or (type(report.editor_exit_code) == 'number' and report.editor_exit_code ~= 0)
  then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'partial-scan', 'KICS reported scan or query failures; these results are incomplete.')
  end
  if report.files_scanned == 0 or report.files_parsed == 0 or report.queries_total == 0 then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'empty-scan', 'KICS scanned no files, parsed no files, or ran no queries. Check supported platforms, exclusions and query assets.')
  end
  if limited then
    diagnostics[#diagnostics + 1] = status_diagnostic(context, 'result-limit', 'KICS reached the editor report limit; run a separate scan for complete results.')
  end
  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(type(context) == 'table', 'kics arguments require LintContext')
  local filename = string_value(context.filename)
  assert(filename ~= nil, 'KICS requires a saved filename')
  local root = project_root(context)
  local config = string_value(vim.env.NVIM_KICS_CONFIG)
  if config == nil and string_value(vim.env.KICS_CONFIG) == nil then
    local candidate = fs.joinpath(root, 'kics.config')
    local stat = uv.fs_stat(candidate)
    if stat ~= nil and stat.type == 'file' then
      config = candidate
    end
  end
  return {
    '-I', '-c', BRIDGE,
    json.encode({
      filename = absolute_path(filename, string_value(context.cwd) or root),
      modified = context.modified == true,
      config = config,
      queries = string_value(vim.env.NVIM_KICS_QUERIES_PATH),
      libraries = string_value(vim.env.NVIM_KICS_LIBRARIES_PATH),
    }),
  }
end

---@type Linter
return {
  args = arguments,
  append_fname = false,
  automatic = true,
  cmd = 'python3',
  cwd = project_root,
  ignore_exitcode = true,
  parser = parse,
  root_markers = ROOT_MARKERS,
  stdin = false,
  stream = 'stdout',
  timeout = 120000,
}