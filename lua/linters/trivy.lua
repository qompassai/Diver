-- #################################################################
-- /qompassai/Diver/lua/linters/trivy.lua
-- Qompass AI Diver Native Trivy Tiger Linter
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
---@source https://github.com/aquasecurity/trivy
---@source https://trivy.dev/docs/latest/scanner/misconfiguration/
---@source https://trivy.dev/docs/latest/scanner/secret/

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 32 * 1024 * 1024

local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local type = type

local SOURCE = 'trivy'

---@type table<string, integer>
local SEVERITIES = {
  CRITICAL = ERROR,
  HIGH = ERROR,
  LOW = INFO,
  MEDIUM = WARN,
  UNKNOWN = WARN,
}

---@type string[]
local CONFIG_CANDIDATES = {
  'trivy.yaml',
  'trivy.yml',

  '.trivy.yaml',
  '.trivy.yml',

  'config/trivy.yaml',
  'config/trivy.yml',

  '.config/trivy.yaml',
  '.config/trivy.yml',
}

---@type string[]
local SECRET_CONFIG_CANDIDATES = {
  'trivy-secret.yaml',
  'trivy-secret.yml',

  '.trivy-secret.yaml',
  '.trivy-secret.yml',

  'config/trivy-secret.yaml',
  'config/trivy-secret.yml',

  '.config/trivy-secret.yaml',
  '.config/trivy-secret.yml',
}

---@class TrivyPosition
---@field Number? integer
---@field Content? string

---@class TrivyCode
---@field Lines? TrivyPosition[]

---@class TrivyCauseMetadata
---@field StartLine? integer
---@field EndLine? integer

---@class TrivyMisconfiguration
---@field ID? string
---@field AVDID? string
---@field Type? string
---@field Title? string
---@field Description? string
---@field Message? string
---@field Namespace? string
---@field Query? string
---@field Resolution? string
---@field PrimaryURL? string
---@field References? string[]
---@field Severity? string
---@field Status? string
---@field CauseMetadata? TrivyCauseMetadata

---@class TrivySecret
---@field RuleID? string
---@field Category? string
---@field Severity? string
---@field Title? string
---@field StartLine? integer
---@field EndLine? integer
---@field Match? string
---@field Code? TrivyCode

---@class TrivyResult
---@field Target? string
---@field Class? string
---@field Type? string
---@field Misconfigurations? TrivyMisconfiguration[]
---@field Secrets? TrivySecret[]

---@class TrivyReport
---@field SchemaVersion? integer
---@field ArtifactName? string
---@field ArtifactType? string
---@field Results? TrivyResult[]

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0, 'fallback must be non-negative')

  local parsed = tonumber(value)

  if parsed == nil then
    return fallback
  end

  return floor(parsed)
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param value string
---@return string
local function trim(value)
  assert(type(value) == 'string', 'value must be a string')

  return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function normalize_message(value)
  assert(type(value) == 'string', 'value must be a string')

  value = value:gsub('\r\n', '\n')

  value = value:gsub('\r', '\n')

  value = trim(value)

  if #value > MESSAGE_LENGTH_MAX then
    value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
  end

  return value
end

---@param root string
---@param candidates string[]
---@return string?
local function find_candidate(root, candidates)
  assert(root ~= '', 'root must not be empty')

  for index = 1, #candidates do
    local candidate = fs.joinpath(root, candidates[index])

    if exists(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
  assert(path ~= '', 'path must not be empty')

  assert(root ~= '', 'root must not be empty')

  if path:sub(1, 7) == 'file://' then
    local ok, filename = pcall(vim.uri_to_fname, path)

    if ok and type(filename) == 'string' and filename ~= '' then
      return fs.normalize(filename)
    end
  end

  if path:sub(1, 1) == '/' then
    return fs.normalize(path)
  end

  return fs.normalize(fs.joinpath(root, path))
end

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(candidate, filename, root)
  if candidate == '' or filename == '' or root == '' then
    return false
  end

  return normalize_path(candidate, root) == normalize_path(filename, root)
end

---@param value string|nil
---@return integer
local function severity(value)
  if type(value) ~= 'string' then
    return WARN
  end

  return SEVERITIES[value:upper()] or WARN
end

---@param value unknown
---@param fallback string
---@return string
local function string_or(value, fallback)
  if type(value) ~= 'string' or value == '' then
    return fallback
  end

  return value
end

---@param entry TrivyMisconfiguration
---@param bufnr integer
---@return vim.Diagnostic
local function diagnostic_from_misconfiguration(entry, bufnr)
  local cause = entry.CauseMetadata

  local start_line = 1
  local end_line = 1

  if type(cause) == 'table' then
    start_line = max(integer(cause.StartLine, 1), 1)

    end_line = max(integer(cause.EndLine, start_line), start_line)
  end

  local lnum = start_line - 1

  local end_lnum = end_line - 1

  local title = string_or(entry.Title, 'Trivy misconfiguration')

  local detail = string_or(entry.Message, string_or(entry.Description, title))

  local message

  if detail == title then
    message = title
  else
    message = title .. ': ' .. detail
  end

  message = normalize_message(message)

  local code = entry.ID

  if type(code) ~= 'string' or code == '' then
    code = entry.AVDID
  end

  if type(code) ~= 'string' or code == '' then
    code = 'misconfiguration'
  end

  return {
    bufnr = bufnr,

    lnum = lnum,
    end_lnum = end_lnum,

    col = 0,
    end_col = 1,

    message = message,

    severity = severity(entry.Severity),

    source = SOURCE,
    code = code,

    user_data = {
      category = 'misconfiguration',
      namespace = entry.Namespace,
      primary_url = entry.PrimaryURL,
      resolution = entry.Resolution,
      status = entry.Status,
      trivy_type = entry.Type,
    },
  }
end

---@param entry TrivySecret
---@param bufnr integer
---@return vim.Diagnostic
local function diagnostic_from_secret(entry, bufnr)
  local start_line = max(integer(entry.StartLine, 1), 1)

  local end_line = max(integer(entry.EndLine, start_line), start_line)

  local lnum = start_line - 1

  local end_lnum = end_line - 1

  local title = string_or(entry.Title, 'Potential secret detected')
  local message = normalize_message(title)

  local code = entry.RuleID

  if type(code) ~= 'string' or code == '' then
    code = 'secret'
  end

  return {
    bufnr = bufnr,

    lnum = lnum,
    end_lnum = end_lnum,

    col = 0,
    end_col = 1,

    message = message,

    severity = severity(entry.Severity),

    source = SOURCE,
    code = code,

    user_data = {
      category = 'secret',
      secret_category = entry.Category,
    },
  }
end

---@param result TrivyResult
---@param context LintContext
---@param filename string
---@param root string
---@param diagnostics vim.Diagnostic.Set[]
local function parse_result(result, context, filename, root, diagnostics)
  local target = result.Target

  if type(target) == 'string' and target ~= '' and not belongs_to_buffer(target, filename, root) then
    return
  end

  local misconfigurations = result.Misconfigurations

  if type(misconfigurations) == 'table' then
    local available = DIAGNOSTICS_MAX - #diagnostics

    local count = min(#misconfigurations, available)

    for index = 1, count do
      local raw = misconfigurations[index]

      if type(raw) == 'table' then
        ---@cast raw TrivyMisconfiguration

        diagnostics[#diagnostics + 1] = diagnostic_from_misconfiguration(raw, context.bufnr)
      end
    end
  end

  if #diagnostics >= DIAGNOSTICS_MAX then
    return
  end

  local secrets = result.Secrets

  if type(secrets) ~= 'table' then
    return
  end

  local available = DIAGNOSTICS_MAX - #diagnostics

  local count = min(#secrets, available)

  for index = 1, count do
    local raw = secrets[index]

    if type(raw) == 'table' then
      ---@cast raw TrivySecret

      diagnostics[#diagnostics + 1] = diagnostic_from_secret(raw, context.bufnr)
    end
  end
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
  if output == '' then
    return {}
  end

  assert(type(context) == 'table', 'trivy parser requires a LintContext')

  ---@cast context LintContext

  assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  assert(#output <= OUTPUT_LENGTH_MAX, 'trivy output exceeded maximum size')

  local ok, decoded = pcall(json.decode, output)

  if not ok or type(decoded) ~= 'table' then
    return {}
  end

  ---@cast decoded TrivyReport

  local results = decoded.Results

  if type(results) ~= 'table' then
    return {}
  end

  local filename = normalize_path(context.filename, context.root)

  local root = fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}

  for index = 1, #results do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local raw = results[index]

    if type(raw) == 'table' then
      ---@cast raw TrivyResult

      parse_result(raw, context, filename, root, diagnostics)
    end
  end

  assert(#diagnostics <= DIAGNOSTICS_MAX, 'diagnostic limit exceeded')

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  local argv = {
    'fs',

    --
    -- Editor-facing Trivy should report findings, not terminate as a CI gate.
    --
    '--exit-code',
    '0',

    --
    -- Structured output gives stable rule IDs, severity, target paths, and
    -- source line ranges.
    --
    '--format',
    'json',

    --
    -- Suppress progress and informational noise.
    --
    '--quiet',

    --
    -- Tiger editor scope:
    --
    -- * misconfig catches IaC / deployment / infrastructure policy problems
    -- * secret catches leaked credentials and tokens
    --
    -- Vulnerability and license scanners are intentionally omitted here
    -- because their findings generally describe packages rather than precise
    -- source locations in the active buffer.
    --
    '--scanners',
    'misconfig,secret',

    '--skip-version-check',
  }

  local config = find_candidate(context.root, CONFIG_CANDIDATES)

  if config ~= nil then
    argv[#argv + 1] = '--config'

    argv[#argv + 1] = config
  end

  local secret_config = find_candidate(context.root, SECRET_CONFIG_CANDIDATES)

  if secret_config ~= nil then
    argv[#argv + 1] = '--secret-config'

    argv[#argv + 1] = secret_config
  end
  argv[#argv + 1] = context.filename

  return argv
end

---@param context LintContext
---@return string
local function cwd(context)
  assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

  return fs.normalize(context.root)
end

return ---@type Linter
{
  automatic = false,

  cmd = 'trivy',

  args = args,

  append_fname = false,

  cwd = cwd,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    'trivy.yaml',
    'trivy.yml',

    '.trivy.yaml',
    '.trivy.yml',

    'trivy-secret.yaml',
    'trivy-secret.yml',

    '.trivyignore',
    '.trivyignore.yaml',

    'Dockerfile',

    'compose.yaml',
    'compose.yml',

    'docker-compose.yaml',
    'docker-compose.yml',

    'Chart.yaml',

    'main.tf',
    'terragrunt.hcl',

    '.git',
  },

  stdin = false,

  stream = 'stdout',

  timeout = 120000,
}
