-- #################################################################
-- ~/.config/nvim/lua/linters/dxc.lua
-- Qompass AI Diver Native DXC HLSL Linter
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/microsoft/DirectXShaderCompiler
---@source https://github.com/microsoft/DirectXShaderCompiler/blob/main/include/dxc/Support/HLSLOptions.td
---@source https://github.com/microsoft/DirectXShaderCompiler/blob/main/docs/SPIR-V.rst
--
-- Arch Linux:
--
--   paru -S directx-shader-compiler
--
-- Verify:
--
--   dxc --version
--
-- Tiger-style policy:
--
--   * compile the current shader only;
--   * emit no persistent shader binary;
--   * enable all warnings;
--   * explicitly enable deprecated-usage diagnostics;
--   * enable strict HLSL compilation;
--   * use HLSL 2021 unless overridden;
--   * infer common shader profiles from the filename;
--   * allow explicit profile/entry overrides;
--   * preserve include resolution relative to the project;
--   * support optional SPIR-V/Vulkan validation;
--   * cap parser output, message size, and diagnostic count;
--   * never use shell interpolation;
--   * remain compatible with Neovim's Lua 5.1 contract.
--
-- Optional environment overrides:
--
--   NVIM_DXC_PROFILE=ps_6_8
--   NVIM_DXC_ENTRY=main
--   NVIM_DXC_HLSL_VERSION=2021
--   NVIM_DXC_SPIRV=1
--   NVIM_DXC_SPIRV_ENV=vulkan1.3
--
-- Filename profile inference:
--
--   *.vert.hlsl      -> vs_6_8
--   *.vs.hlsl        -> vs_6_8
--   *.frag.hlsl      -> ps_6_8
--   *.pixel.hlsl     -> ps_6_8
--   *.ps.hlsl        -> ps_6_8
--   *.geom.hlsl      -> gs_6_8
--   *.gs.hlsl        -> gs_6_8
--   *.hull.hlsl      -> hs_6_8
--   *.hs.hlsl        -> hs_6_8
--   *.domain.hlsl    -> ds_6_8
--   *.ds.hlsl        -> ds_6_8
--   *.compute.hlsl   -> cs_6_8
--   *.comp.hlsl      -> cs_6_8
--   *.cs.hlsl        -> cs_6_8
--   *.mesh.hlsl      -> ms_6_8
--   *.ms.hlsl        -> ms_6_8
--   *.amplification.hlsl -> as_6_8
--   *.task.hlsl      -> as_6_8
--   *.as.hlsl        -> as_6_8
--   *.lib.hlsl       -> lib_6_8
--   generic *.hlsl   -> lib_6_8
--
-- Generic HLSL defaults to a library target so DXC can type-check and compile
-- reusable shader code without inventing an entry point.

local diagnostic = vim.diagnostic
local fs = vim.fs

local MAX_DIAGNOSTICS = 512
local MAX_LINE_BYTES = 16 * 1024
local MAX_MESSAGE_BYTES = 2048
local MAX_OUTPUT_BYTES = 8 * 1024 * 1024
local SOURCE = 'dxc'

local DEFAULT_ENTRY = 'main'
local DEFAULT_HLSL_VERSION = '2021'
local DEFAULT_PROFILE = 'lib_6_8'

---@type string[]
local ROOT_MARKERS = {
  'CMakeLists.txt',
  'meson.build',
  'premake5.lua',
  'xmake.lua',
  'build.zig',
  'compile_commands.json',
  'shaders',
  'assets',
  '.git',
}

---@type table<string, string>
local PROFILE_SUFFIXES = {
  ['.amplification.hlsl'] = 'as_6_8',
  ['.as.hlsl'] = 'as_6_8',
  ['.comp.hlsl'] = 'cs_6_8',
  ['.compute.hlsl'] = 'cs_6_8',
  ['.cs.hlsl'] = 'cs_6_8',
  ['.domain.hlsl'] = 'ds_6_8',
  ['.ds.hlsl'] = 'ds_6_8',
  ['.frag.hlsl'] = 'ps_6_8',
  ['.geom.hlsl'] = 'gs_6_8',
  ['.gs.hlsl'] = 'gs_6_8',
  ['.hs.hlsl'] = 'hs_6_8',
  ['.hull.hlsl'] = 'hs_6_8',
  ['.lib.hlsl'] = 'lib_6_8',
  ['.mesh.hlsl'] = 'ms_6_8',
  ['.ms.hlsl'] = 'ms_6_8',
  ['.pixel.hlsl'] = 'ps_6_8',
  ['.ps.hlsl'] = 'ps_6_8',
  ['.task.hlsl'] = 'as_6_8',
  ['.vert.hlsl'] = 'vs_6_8',
  ['.vs.hlsl'] = 'vs_6_8',
}

---@param value any
---@return string?
local function string_value(value)
  if type(value) ~= 'string' or value == '' then
    return nil
  end

  return value
end

---@param value string
---@return string
local function compact(value)
  return vim.trim(value:gsub('%s+', ' '))
end

---@param value string
---@param limit integer
---@return string
local function truncate(value, limit)
  if #value <= limit then
    return value
  end

  if limit <= 3 then
    return value:sub(1, limit)
  end

  return value:sub(1, limit - 3) .. '...'
end

---@param value any
---@return integer
local function zero_based(value)
  local number = tonumber(value)

  if number == nil then
    return 0
  end

  local integer = math.floor(number)

  if integer <= 1 then
    return 0
  end

  return integer - 1
end

---@param output string
---@return string
local function strip_ansi(output)
  return output:gsub('\27%[[%d;]*[mK]', '')
end

---@param context LintContext
---@return string
local function project_root(context)
  local context_root = string_value(context.root)

  if context_root ~= nil then
    return fs.normalize(context_root)
  end

  local filename = string_value(context.filename)

  if filename ~= nil then
    local detected = fs.root(
      filename,
      ROOT_MARKERS
    )

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  local cwd = string_value(context.cwd)

  if cwd ~= nil then
    return fs.normalize(cwd)
  end

  return fs.normalize(
    vim.fn.getcwd()
  )
end

---@param context LintContext
---@return string
local function include_root(context)
  local filename = string_value(
    context.filename
  )

  if filename ~= nil then
    local parent = fs.dirname(filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return project_root(context)
end

---@param value string?
---@return boolean
local function truthy(value)
  if value == nil then
    return false
  end

  local normalized = value:lower()

  return normalized == '1'
    or normalized == 'true'
    or normalized == 'yes'
    or normalized == 'on'
end

---@param filename string
---@return string
local function infer_profile(filename)
  local configured = string_value(
    vim.env.NVIM_DXC_PROFILE
  )

  if configured ~= nil then
    return configured
  end

  local lower = filename:lower()

  for suffix, profile in pairs(
    PROFILE_SUFFIXES
  ) do
    if
      #lower >= #suffix
      and lower:sub(-#suffix) == suffix
    then
      return profile
    end
  end

  return DEFAULT_PROFILE
end

---@param profile string
---@return boolean
local function library_profile(profile)
  return profile:match('^lib_') ~= nil
end

---@param context LintContext
---@return string
local function profile(context)
  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return DEFAULT_PROFILE
  end

  return infer_profile(filename)
end

---@return string
local function entry_point()
  return string_value(
    vim.env.NVIM_DXC_ENTRY
  ) or DEFAULT_ENTRY
end

---@return string
local function hlsl_version()
  return string_value(
    vim.env.NVIM_DXC_HLSL_VERSION
  ) or DEFAULT_HLSL_VERSION
end

---@param level string?
---@return integer
local function severity(level)
  if level == nil then
    return diagnostic.severity.ERROR
  end

  local normalized = level:lower()

  if
    normalized == 'fatal error'
    or normalized == 'error'
  then
    return diagnostic.severity.ERROR
  end

  if
    normalized == 'warning'
    or normalized == 'warn'
  then
    return diagnostic.severity.WARN
  end

  if
    normalized == 'note'
    or normalized == 'info'
  then
    return diagnostic.severity.INFO
  end

  return diagnostic.severity.ERROR
end

---@class DxcFinding
---@field code string?
---@field column integer
---@field line integer
---@field message string
---@field path string?
---@field severity string

---@param line string
---@return DxcFinding?
local function parse_finding(line)
  if line == '' or #line > MAX_LINE_BYTES then
    return nil
  end

  local path
  local line_number
  local column
  local level
  local message
  local code

  --
  -- Clang/DXC style:
  --
  --   shader.hlsl:12:7: error: ...
  --   shader.hlsl:12:7: warning: ... [-Wfoo]
  --
  path,
    line_number,
    column,
    level,
    message,
    code =
    line:match(
      '^(.+):(%d+):(%d+):%s+(fatal error|error|warning|note):%s+(.+)%s+%[([^%]]+)%]$'
    )

  if
    path ~= nil
    and line_number ~= nil
    and column ~= nil
    and level ~= nil
    and message ~= nil
  then
    return {
      code = code,

      column = tonumber(column) or 1,

      line = tonumber(line_number) or 1,

      message = message,

      path = path,

      severity = level,
    }
  end

  path,
    line_number,
    column,
    level,
    message =
    line:match(
      '^(.+):(%d+):(%d+):%s+(fatal error|error|warning|note):%s+(.+)$'
    )

  if
    path ~= nil
    and line_number ~= nil
    and column ~= nil
    and level ~= nil
    and message ~= nil
  then
    return {
      code = nil,

      column = tonumber(column) or 1,

      line = tonumber(line_number) or 1,

      message = message,

      path = path,

      severity = level,
    }
  end

  --
  -- Some DXC diagnostics omit a column.
  --
  path,
    line_number,
    level,
    message =
    line:match(
      '^(.+):(%d+):%s+(fatal error|error|warning|note):%s+(.+)$'
    )

  if
    path == nil
    or line_number == nil
    or level == nil
    or message == nil
  then
    return nil
  end

  return {
    code = nil,

    column = 1,

    line = tonumber(line_number) or 1,

    message = message,

    path = path,

    severity = level,
  }
end

---@param path string
---@param context LintContext
---@return boolean
local function same_file(path, context)
  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return false
  end

  local candidate = path

  if not fs.isabs(candidate) then
    candidate = fs.joinpath(
      project_root(context),
      candidate
    )
  end

  return fs.normalize(candidate)
    == fs.normalize(filename)
end

---@param finding DxcFinding
---@param context LintContext
---@return vim.Diagnostic
local function finding_diagnostic(
  finding,
  context
)
  local lnum = zero_based(
    finding.line
  )

  local col = zero_based(
    finding.column
  )

  local message = compact(
    finding.message
  )

  if
    finding.path ~= nil
    and finding.path ~= '<stdin>'
    and not same_file(
      finding.path,
      context
    )
  then
    message = string.format(
      '%s: %s',
      finding.path,
      message
    )

    lnum = 0
    col = 0
  end

  return {
    bufnr = context.bufnr,

    code = string_value(
      finding.code
    ),

    col = col,

    end_col = col,

    end_lnum = lnum,

    lnum = lnum,

    message = truncate(
      message,
      MAX_MESSAGE_BYTES
    ),

    severity = severity(
      finding.severity
    ),

    source = SOURCE,

    user_data = {
      path = finding.path,

      profile = profile(context),

      warning = finding.code,
    },
  }
end

---@param line string
---@return boolean
local function operational_error(line)
  local lower = line:lower()

  return lower:find(
    'error:',
    1,
    true
  ) ~= nil
    or lower:find(
      'fatal error:',
      1,
      true
    ) ~= nil
    or lower:find(
      'failed',
      1,
      true
    ) ~= nil
    or lower:find(
      'invalid',
      1,
      true
    ) ~= nil
    or lower:find(
      'unknown argument',
      1,
      true
    ) ~= nil
    or lower:find(
      'unable to',
      1,
      true
    ) ~= nil
end

---@param output string
---@return string?
local function error_message(output)
  local text = strip_ansi(
    vim.trim(output)
  )

  if text == '' then
    return nil
  end

  for raw_line in text:gmatch('[^\r\n]+') do
    local line = compact(raw_line)

    if operational_error(line) then
      return truncate(
        line,
        MAX_MESSAGE_BYTES
      )
    end
  end

  return nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_failure(
  output,
  context
)
  local message = error_message(output)

  if message == nil then
    return {}
  end

  return {
    {
      bufnr = context.bufnr,

      code = 'dxc-error',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = message,

      severity = diagnostic.severity.ERROR,

      source = SOURCE,
    },
  }
end

---@param context LintContext
---@return vim.Diagnostic[]
local function oversized_output(context)
  return {
    {
      bufnr = context.bufnr,

      code = 'output-limit',

      col = 0,

      end_col = 0,

      end_lnum = 0,

      lnum = 0,

      message = string.format(
        'DXC output exceeded the %d-byte parser limit',
        MAX_OUTPUT_BYTES
      ),

      severity = diagnostic.severity.WARN,

      source = SOURCE,
    },
  }
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
  assert(
    type(context) == 'table',
    'dxc parser requires LintContext'
  )

  assert(
    type(context.bufnr) == 'number',
    'dxc parser requires context.bufnr'
  )

  if output == '' then
    return {}
  end

  if #output > MAX_OUTPUT_BYTES then
    return oversized_output(context)
  end

  local text = strip_ansi(output)

  ---@type vim.Diagnostic[]
  local diagnostics = {}

  ---@type string[]
  local unparsed = {}

  for raw_line in text:gmatch('[^\r\n]+') do
    if #diagnostics >= MAX_DIAGNOSTICS then
      break
    end

    local line = vim.trim(raw_line)

    if line ~= '' then
      local finding = parse_finding(line)

      if finding ~= nil then
        diagnostics[#diagnostics + 1] =
          finding_diagnostic(
            finding,
            context
          )
      elseif operational_error(line) then
        unparsed[#unparsed + 1] = line
      end
    end
  end

  if
    #diagnostics == 0
    and #unparsed > 0
  then
    return parse_failure(
      table.concat(
        unparsed,
        '\n'
      ),
      context
    )
  end

  return diagnostics
end

---@param context LintContext
---@return string[]
local function arguments(context)
  assert(
    type(context) == 'table',
    'dxc arguments require LintContext'
  )

  local filename = string_value(
    context.filename
  )

  if filename == nil then
    return {}
  end

  local target = profile(context)

  ---@type string[]
  local args = {
    --
    -- Tiger correctness policy.
    --
    '-Wall',

    '-Wdeprecated',

    '-Ges',

    --
    -- Keep warning identifiers such as [-Wfoo] in diagnostics.
    --
    '-fdiagnostics-show-option',

    --
    -- Avoid ANSI escape sequences in Neovim parser input.
    --
    '-fdiagnostics-color=never',

    --
    -- Current DXC default is HLSL 2021, but making it explicit prevents
    -- behavior changing silently when compiler defaults evolve.
    --
    '-HV',
    hlsl_version(),

    --
    -- Target profile.
    --
    '-T',
    target,

    --
    -- Search the shader's own directory first.
    --
    '-I',
    include_root(context),

    --
    -- Search the project root as well.
    --
    '-I',
    project_root(context),

    --
    -- Linting does not need optimized code generation.
    --
    '-Od',

    --
    -- The real file path is intentional. DXC include resolution and
    -- diagnostics are considerably more useful with a filename than stdin.
    --
    filename,
  }

  --
  -- Library profiles intentionally have no entry point.
  --
  if not library_profile(target) then
    table.insert(
      args,
      #args,
      entry_point()
    )

    table.insert(
      args,
      #args,
      '-E'
    )
  end

  --
  -- Optional Vulkan/SPIR-V validation path.
  --
  if truthy(
    vim.env.NVIM_DXC_SPIRV
  ) then
    table.insert(
      args,
      1,
      '-spirv'
    )

    local environment = string_value(
      vim.env.NVIM_DXC_SPIRV_ENV
    )

    if environment ~= nil then
      table.insert(
        args,
        2,
        '-fspv-target-env='
          .. environment
      )
    end
  end

  return args
end

---@type Linter
return {
  args = arguments,

  append_fname = false,

  --
  -- DXC performs actual HLSL compilation, semantic analysis, include
  -- processing, shader-model validation, and optionally SPIR-V validation.
  -- Run on save/on-demand instead of every keystroke.
  --
  automatic = false,

  cmd = 'dxc',

  cwd = project_root,

  --
  -- Compilation diagnostics naturally produce non-zero exits.
  --
  ignore_exitcode = true,

  parser = parse,

  root_markers = ROOT_MARKERS,

  stdin = false,

  stream = 'both',

  timeout = 30000,
}