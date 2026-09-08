-- #################################################################
-- /qompassai/Diver/lua/linters/checkstyle.lua
-- Qompass AI Checkstyle
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
---@source https://github.com/checkstyle/checkstyle

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

---@class CheckstyleSarifMessage
---@field text? string

---@class CheckstyleSarifRegion
---@field startLine? integer
---@field startColumn? integer
---@field endLine? integer
---@field endColumn? integer

---@class CheckstyleSarifArtifactLocation
---@field index? integer
---@field uri? string
---@field uriBaseId? string

---@class CheckstyleSarifPhysicalLocation
---@field artifactLocation? CheckstyleSarifArtifactLocation
---@field region? CheckstyleSarifRegion

---@class CheckstyleSarifLocation
---@field physicalLocation? CheckstyleSarifPhysicalLocation

---@class CheckstyleSarifResult
---@field level? string
---@field locations? CheckstyleSarifLocation[]
---@field message? CheckstyleSarifMessage
---@field ruleId? string
---@field ruleIndex? integer

---@class CheckstyleSarifArtifact
---@field location? CheckstyleSarifArtifactLocation

---@class CheckstyleSarifRun
---@field artifacts? CheckstyleSarifArtifact[]
---@field results? CheckstyleSarifResult[]

---@class CheckstyleSarifReport
---@field runs? CheckstyleSarifRun[]
---@field version? string

---@type table<string, integer>
local severities = {
  error = ERROR,
  none = HINT,
  note = INFO,
  warning = WARN,
}

---@type string[]
local config_candidates = {
  'checkstyle.xml',
  'checkstyle-checks.xml',
  'config/checkstyle/checkstyle.xml',
  'config/checkstyle/checkstyle-checks.xml',
  'config/checkstyle.xml',
  '.checkstyle/checkstyle.xml',
}

---@type string[]
local properties_candidates = {
  'checkstyle.properties',
  'config/checkstyle/checkstyle.properties',
  'config/checkstyle.properties',
  '.checkstyle/checkstyle.properties',
}

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
  assert(fallback >= 0)

  local parsed = tonumber(value)

  if parsed == nil then
    return fallback
  end

  return floor(parsed)
end

---@param level string|nil
---@return integer
local function severity(level)
  if level == nil then
    return WARN
  end

  return severities[level:lower()] or WARN
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param root string
---@param candidates string[]
---@return string?
local function find_candidate(root, candidates)
  assert(root ~= '')

  for index = 1, #candidates do
    local candidate = fs.joinpath(
      root,
      candidates[index]
    )

    if exists(candidate) then
      return candidate
    end
  end

  return nil
end

---@param root string
---@return string
local function config_file(root)
  local config = find_candidate(
    root,
    config_candidates
  )

  --
  -- Checkstyle accepts built-in configuration resources through -c.
  --
  -- If the repository does not provide its own configuration, use the
  -- bundled Google Java Style configuration rather than silently
  -- disabling linting.
  --
  return config or 'google_checks.xml'
end

---@param root string
---@return string?
local function properties_file(root)
  return find_candidate(
    root,
    properties_candidates
  )
end

---@param uri string
---@param root string
---@return string
local function path_from_uri(uri, root)
  assert(uri ~= '')
  assert(root ~= '')

  if uri:sub(1, 7) == 'file://' then
    local ok, filename = pcall(
      vim.uri_to_fname,
      uri
    )

    if ok and type(filename) == 'string' then
      return fs.normalize(filename)
    end
  end

  if fs.is_absolute(uri) then
    return fs.normalize(uri)
  end

  return fs.normalize(
    fs.joinpath(root, uri)
  )
end

---@param location CheckstyleSarifArtifactLocation
---@param artifacts CheckstyleSarifArtifact[]|nil
---@param root string
---@return string?
local function artifact_path(location, artifacts, root)
  local uri = location.uri

  if type(uri) == 'string' and uri ~= '' then
    return path_from_uri(uri, root)
  end

  local index = location.index

  if
    type(index) ~= 'number'
    or type(artifacts) ~= 'table'
  then
    return nil
  end

  --
  -- SARIF artifact indexes are zero-based.
  --
  local artifact = artifacts[index + 1]

  if type(artifact) ~= 'table' then
    return nil
  end

  local artifact_location = artifact.location

  if type(artifact_location) ~= 'table' then
    return nil
  end

  uri = artifact_location.uri

  if type(uri) ~= 'string' or uri == '' then
    return nil
  end

  return path_from_uri(uri, root)
end

---@param candidate string
---@param filename string
---@return boolean
local function belongs_to_buffer(candidate, filename)
  assert(candidate ~= '')
  assert(filename ~= '')

  return fs.normalize(candidate) == filename
end

---@param result CheckstyleSarifResult
---@param artifacts CheckstyleSarifArtifact[]|nil
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_result(
  result,
  artifacts,
  filename,
  root
)
  local locations = result.locations

  if type(locations) ~= 'table' then
    return nil
  end

  local location = locations[1]

  if type(location) ~= 'table' then
    return nil
  end

  local physical = location.physicalLocation

  if type(physical) ~= 'table' then
    return nil
  end

  local artifact = physical.artifactLocation

  if type(artifact) ~= 'table' then
    return nil
  end

  local path = artifact_path(
    artifact,
    artifacts,
    root
  )

  if
    path == nil
    or not belongs_to_buffer(path, filename)
  then
    return nil
  end

  local region = physical.region

  local start_line = 0
  local start_column = 0
  local end_line = 0
  local end_column = 1

  if type(region) == 'table' then
    start_line = max(
      integer(region.startLine, 1) - 1,
      0
    )

    start_column = max(
      integer(region.startColumn, 1) - 1,
      0
    )

    end_line = max(
      integer(
        region.endLine,
        start_line + 1
      ) - 1,
      start_line
    )

    local minimum_end_column =
      end_line == start_line
        and start_column + 1
        or 0

    --
    -- SARIF columns are one-based while Neovim columns are zero-based.
    --
    -- endColumn represents the first column after the region, so unlike
    -- startColumn it should not receive an additional -1 adjustment when
    -- converted to Neovim's exclusive end_col.
    --
    end_column = max(
      integer(
        region.endColumn,
        minimum_end_column + 1
      ) - 1,
      minimum_end_column
    )
  end

  local message = 'Checkstyle violation'

  if
    type(result.message) == 'table'
    and type(result.message.text) == 'string'
    and result.message.text ~= ''
  then
    message = result.message.text
  end

  local code = result.ruleId

  if type(code) ~= 'string' or code == '' then
    code = nil
  end

  return {
    lnum = start_line,
    end_lnum = end_line,
    col = start_column,
    end_col = end_column,
    message = message,
    severity = severity(result.level),
    source = 'checkstyle',
    code = code,
    user_data = {
      rule_index = result.ruleIndex,
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
    'checkstyle parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'checkstyle output exceeded maximum size'
  )

  local ok, decoded = pcall(
    json.decode,
    output
  )

  if not ok or type(decoded) ~= 'table' then
    return {}
  end

  ---@cast decoded CheckstyleSarifReport

  local runs = decoded.runs

  if type(runs) ~= 'table' then
    return {}
  end

  local filename = fs.normalize(context.filename)
  local root = fs.normalize(context.root)

  ---@type vim.Diagnostic.Set[]
  local diagnostics = {}
  local diagnostics_count = 0

  for run_index = 1, #runs do
    if diagnostics_count >= DIAGNOSTICS_MAX then
      break
    end

    local run = runs[run_index]

    if type(run) == 'table' then
      local results = run.results
      local artifacts = run.artifacts

      if type(results) == 'table' then
        local available =
          DIAGNOSTICS_MAX - diagnostics_count

        local results_count =
          math.min(#results, available)

        for result_index = 1, results_count do
          local result = results[result_index]

          if type(result) == 'table' then
            local entry =
              diagnostic_from_result(
                result,
                artifacts,
                filename,
                root
              )

            if entry ~= nil then
              diagnostics_count =
                diagnostics_count + 1

              diagnostics[diagnostics_count] =
                entry
            end
          end
        end
      end
    end
  end

  assert(diagnostics_count <= DIAGNOSTICS_MAX)
  assert(diagnostics_count == #diagnostics)

  return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
  assert(context.filename ~= '')
  assert(context.root ~= '')

  local root = fs.normalize(context.root)

  local argv = {
    '-c',
    config_file(root),

    '-f',
    'sarif',
  }

  local properties = properties_file(root)

  if properties ~= nil then
    argv[#argv + 1] = '-p'
    argv[#argv + 1] = properties
  end

  argv[#argv + 1] = context.filename

  return argv
end

return ---@type Linter
{
  automatic = false,

  cmd = 'checkstyle',

  args = args,

  append_fname = false,

  cwd = function(context)
    assert(context.root ~= '')

    return context.root
  end,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    'checkstyle.xml',
    'checkstyle-checks.xml',

    'config/checkstyle/checkstyle.xml',
    'config/checkstyle/checkstyle-checks.xml',
    'config/checkstyle.xml',

    '.checkstyle/checkstyle.xml',

    'checkstyle.properties',
    'config/checkstyle/checkstyle.properties',

    'settings.gradle.kts',
    'settings.gradle',
    'build.gradle.kts',
    'build.gradle',

    'pom.xml',

    '.git',
  },

  stdin = false,
  stream = 'stdout',
  timeout = 60000,
}