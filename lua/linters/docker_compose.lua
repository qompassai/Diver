-- #################################################################
-- /qompassai/Diver/lua/linters/docker_compose.lua
-- Qompass AI Diver Unified Docker Compose Tiger Linter
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
---@source https://docs.docker.com/reference/cli/docker/compose/config/
---@source https://github.com/zavoloklom/docker-compose-linter

local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'compose-tiger'

---@type table<string, integer>
local DCLINT_SEVERITIES = {
  ERROR = ERROR,
  WARNING = WARN,
  INFO = INFO,
  HINT = HINT,

  error = ERROR,
  warning = WARN,
  info = INFO,
  hint = HINT,
}

--
-- One Linter invocation can execute only one command. This coordinator runs
-- Docker Compose and DCLint directly through Python subprocess argument
-- arrays. No shell is involved, so filenames and project paths are never
-- subject to shell expansion or command injection.
--
-- Execution strategy:
--
--   1. docker compose config --quiet
--
--      Docker is authoritative for the effective Compose model.
--
--   2a. Docker rejects the model:
--
--       Report Docker diagnostics and STOP.
--
--       DCLint is deliberately not invoked because its YAML / schema
--       diagnostics would mostly be secondary noise while the effective
--       Compose model is invalid.
--
--   2b. Docker accepts the model:
--
--       Preserve useful Docker warnings, then invoke DCLint using rdjson.
--
--       DCLint becomes responsible for policy, style, maintainability,
--       best-practice rules, and its additional static schema analysis.
--
local COORDINATOR = [=[
import json
import shutil
import subprocess
import sys

MAX_STREAM = 16 * 1024 * 1024
PROCESS_TIMEOUT = 45

filename = sys.argv[1]

result = {
    "version": 1,
    "docker": None,
    "dclint": None,
    "infrastructure": [],
}


def bounded(value):
    if not isinstance(value, str):
        return ""

    if len(value) <= MAX_STREAM:
        return value

    return value[:MAX_STREAM]


def tool_missing(name):
    result["infrastructure"].append({
        "tool": name,
        "message": f"Required executable not found: {name}",
    })


def run(argv):
    try:
        completed = subprocess.run(
            argv,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=PROCESS_TIMEOUT,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        return {
            "status": None,
            "stdout": bounded(error.stdout or ""),
            "stderr": bounded(error.stderr or ""),
            "timeout": True,
        }
    except OSError as error:
        return {
            "status": None,
            "stdout": "",
            "stderr": str(error),
            "os_error": True,
        }

    return {
        "status": completed.returncode,
        "stdout": bounded(completed.stdout),
        "stderr": bounded(completed.stderr),
    }


docker = shutil.which("docker")

if docker is None:
    tool_missing("docker")
else:
    docker_result = run([
        docker,
        "compose",
        "--ansi",
        "never",
        "-f",
        filename,
        "config",
        "--quiet",
    ])

    result["docker"] = docker_result

    #
    # Docker is the semantic gate.
    #
    # Do not run DCLint against a Compose model Docker itself rejects.
    #
    if docker_result.get("status") == 0:
        dclint = shutil.which("dclint")

        if dclint is None:
            tool_missing("dclint")
        else:
            result["dclint"] = run([
                dclint,
                "-f",
                "rdjson",
                filename,
            ])

print(
    json.dumps(
        result,
        ensure_ascii=False,
        separators=(",", ":"),
    )
)
]=]

---@class ComposeCoordinatorProcess
---@field status? integer
---@field stdout? string
---@field stderr? string
---@field timeout? boolean
---@field os_error? boolean

---@class ComposeInfrastructureError
---@field tool? string
---@field message? string

---@class ComposeCoordinatorResult
---@field version? integer
---@field docker? ComposeCoordinatorProcess
---@field dclint? ComposeCoordinatorProcess
---@field infrastructure? ComposeInfrastructureError[]

---@class RdjsonPosition
---@field line? integer
---@field column? integer

---@class RdjsonRange
---@field start? RdjsonPosition
---@field end? RdjsonPosition

---@class RdjsonLocation
---@field path? string
---@field range? RdjsonRange

---@class RdjsonCode
---@field value? string
---@field url? string

---@class RdjsonDiagnostic
---@field message? string
---@field severity? string
---@field location? RdjsonLocation
---@field code? RdjsonCode|string

---@class RdjsonResult
---@field diagnostics? RdjsonDiagnostic[]

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

---@param value string
---@return string
local function trim(value)
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
  value = value:gsub(
    '\27%[[%d;?]*[ -/]*[@-~]',
    ''
  )

  value = value:gsub(
    '\r\n',
    '\n'
  )

  value = value:gsub(
    '\r',
    '\n'
  )

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

---@param value string|nil
---@return integer
local function dclint_severity(value)
  if type(value) ~= 'string' then
    return WARN
  end

  return DCLINT_SEVERITIES[value]
    or DCLINT_SEVERITIES[value:upper()]
    or WARN
end

---@param entry RdjsonDiagnostic
---@return string?
local function dclint_code(entry)
  local code = entry.code

  if type(code) == 'string' then
    if code ~= '' then
      return code
    end

    return nil
  end

  if type(code) ~= 'table' then
    return nil
  end

  local value = code.value

  if
    type(value) ~= 'string'
    or value == ''
  then
    return nil
  end

  return value
end

---@param entry RdjsonDiagnostic
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_dclint(
  entry,
  filename,
  root
)
  local location = entry.location

  if type(location) ~= 'table' then
    return nil
  end

  local path = location.path

  if
    type(path) ~= 'string'
    or path == ''
  then
    return nil
  end

  if
    not belongs_to_buffer(
      path,
      filename,
      root
    )
  then
    return nil
  end

  local range = location.range

  if type(range) ~= 'table' then
    return nil
  end

  local start = range.start

  if type(start) ~= 'table' then
    return nil
  end

  local start_line = max(
    integer(start.line, 1),
    1
  )

  local start_column = max(
    integer(start.column, 1),
    1
  )

  local end_line = start_line
  local end_column = start_column + 1

  local finish = range['end']

  if type(finish) == 'table' then
    end_line = max(
      integer(
        finish.line,
        start_line
      ),
      start_line
    )

    end_column = max(
      integer(
        finish.column,
        start_column + 1
      ),
      1
    )
  end

  local lnum =
    start_line - 1

  local col =
    start_column - 1

  local end_lnum =
    max(
      end_line - 1,
      lnum
    )

  local minimum_end_col =
    end_lnum == lnum
        and col + 1
      or 0

  local neovim_end_col =
    max(
      end_column - 1,
      minimum_end_col
    )

  local message = entry.message

  if
    type(message) ~= 'string'
    or message == ''
  then
    message =
      'DCLint violation'
  end

  message =
    normalize_message(message)

  local code =
    dclint_code(entry)

  return {
    lnum = lnum,
    end_lnum = end_lnum,

    col = col,
    end_col = neovim_end_col,

    message = message,

    severity =
      dclint_severity(
        entry.severity
      ),

    source = 'dclint',
    code = code,

    user_data = {
      engine = 'dclint',
      rule = code,
    },
  }
end

---@param output string
---@param diagnostics vim.Diagnostic.Set[]
---@param filename string
---@param root string
local function parse_dclint(
  output,
  diagnostics,
  filename,
  root
)
  if output == '' then
    return
  end

  local ok, decoded = pcall(
    json.decode,
    output
  )

  if
    not ok
    or type(decoded) ~= 'table'
  then
    return
  end

  ---@cast decoded RdjsonResult

  local entries =
    decoded.diagnostics

  if type(entries) ~= 'table' then
    return
  end

  for index = 1, #entries do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local raw = entries[index]

    if type(raw) == 'table' then
      local entry =
        diagnostic_from_dclint(
          raw,
          filename,
          root
        )

      if entry ~= nil then
        diagnostics[#diagnostics + 1] =
          entry
      end
    end
  end
end

---@param value string
---@return boolean
local function docker_overlap_warning(value)
  local lower =
    value:lower()

  --
  -- DCLint has a dedicated no-version-field rule. Modern Docker Compose also
  -- warns that the legacy top-level version field is obsolete.
  --
  -- Prefer DCLint's precise source location and rule identifier rather than
  -- displaying both diagnostics.
  --
  return
    lower:find(
      'version',
      1,
      true
    ) ~= nil
    and (
      lower:find(
        'obsolete',
        1,
        true
      ) ~= nil
      or lower:find(
        'ignored',
        1,
        true
      ) ~= nil
    )
end

---@param line string
---@return integer
local function docker_line_number(line)
  local value =
    line:match(
      '[Ll]ine%s+(%d+)'
    )
    or line:match(
      ':(%d+):%d+:'
    )

  if value == nil then
    return 1
  end

  return max(
    integer(value, 1),
    1
  )
end

---@param output string
---@param diagnostics vim.Diagnostic.Set[]
---@param severity integer
---@param failed boolean
local function parse_docker(
  output,
  diagnostics,
  severity,
  failed
)
  if output == '' then
    return
  end

  for raw in output:gmatch(
    '[^\r\n]+'
  ) do
    if #diagnostics >= DIAGNOSTICS_MAX then
      break
    end

    local message =
      normalize_message(raw)

    if
      message ~= ''
      and (
        failed
        or not docker_overlap_warning(
          message
        )
      )
    then
      local line =
        docker_line_number(message)

      diagnostics[#diagnostics + 1] = {
        lnum = line - 1,
        end_lnum = line - 1,

        col = 0,
        end_col = 1,

        message = message,

        severity = severity,

        source = 'docker-compose',

        code =
          failed
              and 'config'
            or 'warning',

        user_data = {
          engine = 'docker-compose',
          authoritative = true,
        },
      }
    end
  end
end

---@param entry ComposeInfrastructureError
---@return vim.Diagnostic?
local function infrastructure_diagnostic(entry)
  local message = entry.message

  if
    type(message) ~= 'string'
    or message == ''
  then
    return nil
  end

  local tool = entry.tool

  if
    type(tool) ~= 'string'
    or tool == ''
  then
    tool = 'unknown'
  end

  return {
    lnum = 0,
    end_lnum = 0,

    col = 0,
    end_col = 1,

    message =
      normalize_message(message),

    severity = WARN,

    source = SOURCE,
    code = 'tool-missing',

    user_data = {
      tool = tool,
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
    'docker-compose parser requires a LintContext'
  )

  ---@cast context LintContext

  assert(context.filename ~= '')
  assert(context.root ~= '')

  assert(
    #output <= OUTPUT_LENGTH_MAX,
    'docker-compose output exceeded maximum size'
  )

  local ok, decoded = pcall(
    json.decode,
    output
  )

  if
    not ok
    or type(decoded) ~= 'table'
  then
    return {}
  end

  ---@cast decoded ComposeCoordinatorResult

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

  local infrastructure =
    decoded.infrastructure

  if type(infrastructure) == 'table' then
    for index = 1, #infrastructure do
      if #diagnostics >= DIAGNOSTICS_MAX then
        break
      end

      local raw =
        infrastructure[index]

      if type(raw) == 'table' then
        local entry =
          infrastructure_diagnostic(raw)

        if entry ~= nil then
          diagnostics[#diagnostics + 1] =
            entry
        end
      end
    end
  end

  local docker =
    decoded.docker

  if type(docker) == 'table' then
    if docker.timeout then
      diagnostics[#diagnostics + 1] = {
        lnum = 0,
        end_lnum = 0,
        col = 0,
        end_col = 1,
        message =
          'docker compose config timed out',
        severity = ERROR,
        source = 'docker-compose',
        code = 'timeout',
      }

      return diagnostics
    end

    local docker_status =
      docker.status

    local docker_failed =
      type(docker_status) ~= 'number'
      or docker_status ~= 0

    local docker_stderr =
      type(docker.stderr) == 'string'
          and docker.stderr
        or ''

    if docker_failed then
      --
      -- Stage one failed.
      --
      -- Docker owns the diagnostics and DCLint was intentionally not run.
      --
      parse_docker(
        docker_stderr,
        diagnostics,
        ERROR,
        true
      )

      if
        #diagnostics == 0
        and type(docker.stdout) == 'string'
      then
        parse_docker(
          docker.stdout,
          diagnostics,
          ERROR,
          true
        )
      end

      return diagnostics
    end

    --
    -- Docker accepted the effective model.
    --
    -- Keep Docker-specific warnings such as unresolved environment
    -- interpolation, but suppress warnings whose policy equivalent DCLint
    -- reports more precisely.
    --
    parse_docker(
      docker_stderr,
      diagnostics,
      WARN,
      false
    )
  end

  local dclint =
    decoded.dclint

  if type(dclint) == 'table' then
    if dclint.timeout then
      if #diagnostics < DIAGNOSTICS_MAX then
        diagnostics[#diagnostics + 1] = {
          lnum = 0,
          end_lnum = 0,
          col = 0,
          end_col = 1,

          message =
            'DCLint timed out',

          severity = WARN,

          source = 'dclint',
          code = 'timeout',
        }
      end

      return diagnostics
    end

    local dclint_stdout =
      type(dclint.stdout) == 'string'
          and dclint.stdout
        or ''

    parse_dclint(
      dclint_stdout,
      diagnostics,
      filename,
      root
    )
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
    '-I',
    '-c',
    COORDINATOR,
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

  --
  -- Python is only the process coordinator. It invokes Docker and DCLint with
  -- argument arrays and never invokes a shell.
  --
  cmd = 'python3',

  args = args,

  append_fname = false,

  cwd = cwd,

  ignore_exitcode = true,

  parser = parse,

  root_markers = {
    --
    -- DCLint configuration.
    --
    '.dclintrc',
    '.dclintrc.json',
    '.dclintrc.yaml',
    '.dclintrc.yml',
    '.dclintrc.js',
    '.dclintrc.cjs',

    'dclint.config.js',
    'dclint.config.cjs',
    'dclint.config.mjs',

    --
    -- Compose project files.
    --
    'compose.yaml',
    'compose.yml',

    'docker-compose.yaml',
    'docker-compose.yml',

    --
    -- Environment / project boundaries.
    --
    '.env',

    'package.json',

    '.git',
  },

  stdin = false,

  --
  -- The coordinator emits exactly one JSON envelope to stdout.
  --
  stream = 'stdout',

  timeout = 120000,
}