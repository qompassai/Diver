-- #################################################################
-- /qompassai/diver/lua/dev/vulkan/toolchain.lua
-- Qompass AI Diver Vulkan Shader Toolchain Probing
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
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
---@source https://github.com/google/shaderc
---@source https://github.com/KhronosGroup/glslang
---@source https://github.com/microsoft/DirectXShaderCompiler
---@source https://github.com/shader-slang/slang

--- Shader compiler probing and argv building, in plain language.
---
--- Four compilers can turn shader source into GPU-ready SPIR-V:
--- glslangValidator (the reference GLSL compiler), glslc (Google's
--- wrapper around the same core), dxc (Microsoft's HLSL compiler, with
--- a SPIR-V backend for Vulkan), and slangc (the Slang language
--- compiler). This module asks "which of these are installed, and what
--- version?" and builds the exact command lines to compile a shader.
--- It never runs a compiler by itself — building the argv is kept
--- separate from executing it so tests can verify every flag without
--- needing a real GPU toolchain.
---
--- Every flag below was verified: glslangValidator's `-V`/`-S`/`--target-env`
--- from `glslangValidator --help` on the machine, dxc's `-spirv` from a
--- real end-to-end compile on primo, slangc's `-target`/`-stage`/`-entry`
--- from `slangc --help`, glslc's `--target-env=`/`-fshader-stage=` from
--- the shaderc docs. Nothing is invented.
---@module 'dev.vulkan.toolchain'

local fn = vim.fn

local M = {}

local SYSTEM_TIMEOUT_MS = 10000
local VERSION_BYTES_MAX = 128
local PATH_BYTES_MAX = 4096
local DEFAULT_TARGET_ENV = 'vulkan1.3'
local DEFAULT_ENTRY = 'main'

---@class VulkanToolSpec
---@field bin string executable name
---@field version_arg string flag that prints the version (verified per tool)

--- version_arg is per-tool because the tools disagree: dxc and glslc
--- use --version, slangc only understands -v (verified on primo:
--- `slangc --version` errors with E00017).
---@type table<string, VulkanToolSpec>
local TOOLS = {
    glslangValidator = { bin = 'glslangValidator', version_arg = '--version' },
    glslc = { bin = 'glslc', version_arg = '--version' },
    dxc = { bin = 'dxc', version_arg = '--version' },
    slangc = { bin = 'slangc', version_arg = '-v' },
}

---@type table<string, string>
local STAGE_FOR_EXT = {
    ['.vert'] = 'vert',
    ['.tesc'] = 'tesc',
    ['.tese'] = 'tese',
    ['.geom'] = 'geom',
    ['.frag'] = 'frag',
    ['.comp'] = 'comp',
    ['.mesh'] = 'mesh',
    ['.task'] = 'task',
    ['.rgen'] = 'rgen',
    ['.rint'] = 'rint',
    ['.rahit'] = 'rahit',
    ['.rchit'] = 'rchit',
    ['.rmiss'] = 'rmiss',
    ['.rcall'] = 'rcall',
}

---@param value unknown
---@param what string
---@return string?, string?
local function nonempty_text(value, what)
    if type(value) ~= 'string' or value == '' then
        return nil, what .. ' must be a non-empty string'
    end

    if value:find('%z') ~= nil then
        return nil, what .. ' contains a NUL byte'
    end

    if #value > PATH_BYTES_MAX then
        return nil, what .. ' exceeds ' .. PATH_BYTES_MAX .. ' bytes'
    end

    return value
end

---@param name string
---@return VulkanToolSpec?, string?
local function tool_spec(name)
    local spec = TOOLS[name]

    if spec == nil then
        return nil, 'unknown shader tool: ' .. tostring(name)
    end

    return spec
end

--- Map a shader file extension to its pipeline stage. `.glsl` and
--- `.hlsl` are ambiguous on their own (they need an explicit stage or
--- a compound suffix like `.vert.glsl`), so they return nil + error
--- instead of a guess.
---@param ext string file extension including the dot, e.g. ".vert"
---@return string?, string?
function M.stage_for_ext(ext)
    if type(ext) ~= 'string' or ext == '' then
        return nil, 'extension must be a non-empty string'
    end

    local stage = STAGE_FOR_EXT[ext:lower()]

    if stage ~= nil then
        return stage
    end

    if ext:lower() == '.glsl' or ext:lower() == '.hlsl' then
        return nil, ext .. ' is ambiguous without an explicit stage'
    end

    return nil, 'unknown shader extension: ' .. ext
end

---@param spec VulkanToolSpec
---@return string?
local function tool_version(spec)
    if fn.executable(spec.bin) ~= 1 then
        return nil
    end

    local ok, result = pcall(vim.system, { spec.bin, spec.version_arg }, {
        text = true,
        timeout = SYSTEM_TIMEOUT_MS,
    }, nil)

    if not ok or type(result) ~= 'table' or result.code ~= 0 then
        return nil
    end

    local stdout = result.stdout

    if type(stdout) ~= 'string' then
        return nil
    end

    local first = vim.trim(stdout):match('^([^\r\n]+)')

    if first == nil or first == '' then
        return nil
    end

    if #first > VERSION_BYTES_MAX then
        first = first:sub(1, VERSION_BYTES_MAX) .. '...'
    end

    return first
end

---@class VulkanToolProbe
---@field name string
---@field found boolean
---@field path string? absolute path when found
---@field version string? first line of the version output, nil when it could not be read

--- Probe one shader compiler. `found` is authoritative; `version`
--- is best-effort and honestly nil when the version flag fails.
---@param name string one of: glslangValidator, glslc, dxc, slangc
---@return VulkanToolProbe?, string?
function M.probe(name)
    local spec, spec_err = tool_spec(name)

    if spec == nil then
        return nil, spec_err
    end

    ---@cast spec VulkanToolSpec
    if fn.executable(spec.bin) ~= 1 then
        return { name = name, found = false }
    end

    local path = fn.exepath(spec.bin)

    return {
        name = name,
        found = true,
        path = (type(path) == 'string' and path ~= '') and path or nil,
        version = tool_version(spec),
    }
end

---@return string[]
function M.tool_names()
    ---@type string[]
    local names = {}

    for name in pairs(TOOLS) do
        names[#names + 1] = name
    end

    table.sort(names)

    return names
end

---@class VulkanCompileArgs
---@field stage? string pipeline stage, e.g. "vert" (glslangValidator, glslc, slangc)
---@field source string shader source file
---@field output string SPIR-V output file
---@field entry? string entry point, default "main" (dxc, slangc)
---@field profile? string HLSL profile, e.g. "vs_6_8" (dxc, required)
---@field target_env? string e.g. "vulkan1.3" (glslangValidator, glslc)
---@field target? string slangc codegen target, default "spirv"
---@field spirv? boolean dxc emits SPIR-V when true (default), DXIL when false

---@param tool string
---@param opts VulkanCompileArgs
---@return string[]?, string?
local function glslang_argv(tool, opts)
    local stage, stage_err = nonempty_text(opts.stage, 'stage')

    if stage == nil then
        return nil, stage_err
    end

    local source, source_err = nonempty_text(opts.source, 'source')

    if source == nil then
        return nil, source_err
    end

    local output, output_err = nonempty_text(opts.output, 'output')

    if output == nil then
        return nil, output_err
    end

    local target_env = opts.target_env

    if type(target_env) ~= 'string' or target_env == '' then
        target_env = DEFAULT_TARGET_ENV
    end

    if tool == 'glslangValidator' then
        return {
            'glslangValidator',
            '-V',
            '-S',
            stage,
            '--target-env',
            target_env,
            '-o',
            output,
            source,
        }
    end

    return {
        'glslc',
        '--target-env=' .. target_env,
        '-fshader-stage=' .. stage,
        '-o',
        output,
        source,
    }
end

---@param opts VulkanCompileArgs
---@return string[]?, string?
local function dxc_argv(opts)
    local profile, profile_err = nonempty_text(opts.profile, 'profile')

    if profile == nil then
        return nil, profile_err
    end

    local source, source_err = nonempty_text(opts.source, 'source')

    if source == nil then
        return nil, source_err
    end

    local output, output_err = nonempty_text(opts.output, 'output')

    if output == nil then
        return nil, output_err
    end

    local entry = opts.entry

    if type(entry) ~= 'string' or entry == '' then
        entry = DEFAULT_ENTRY
    end

    ---@type string[]
    local argv = { 'dxc' }

    if opts.spirv ~= false then
        argv[#argv + 1] = '-spirv'
    end

    argv[#argv + 1] = '-T'
    argv[#argv + 1] = profile
    argv[#argv + 1] = '-E'
    argv[#argv + 1] = entry
    argv[#argv + 1] = '-Fo'
    argv[#argv + 1] = output
    argv[#argv + 1] = source

    return argv
end

---@param opts VulkanCompileArgs
---@return string[]?, string?
local function slangc_argv(opts)
    local stage, stage_err = nonempty_text(opts.stage, 'stage')

    if stage == nil then
        return nil, stage_err
    end

    local source, source_err = nonempty_text(opts.source, 'source')

    if source == nil then
        return nil, source_err
    end

    local output, output_err = nonempty_text(opts.output, 'output')

    if output == nil then
        return nil, output_err
    end

    local entry = opts.entry

    if type(entry) ~= 'string' or entry == '' then
        entry = DEFAULT_ENTRY
    end

    local target = opts.target

    if type(target) ~= 'string' or target == '' then
        target = 'spirv'
    end

    return {
        'slangc',
        '-target',
        target,
        '-stage',
        stage,
        '-entry',
        entry,
        '-o',
        output,
        source,
    }
end

--- Build the compile argv for a shader tool. Pure: no process is
--- spawned, so tests can verify every flag. `opts.target` is only
--- read for slangc (the other tools always emit SPIR-V here).
---@param tool string one of the M.tool_names() entries
---@param opts VulkanCompileArgs
---@return string[]?, string?
function M.build_argv(tool, opts)
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end

    local _, spec_err = tool_spec(tool)

    if spec_err ~= nil then
        return nil, spec_err
    end

    if tool == 'dxc' then
        return dxc_argv(opts)
    end

    if tool == 'slangc' then
        return slangc_argv(opts)
    end

    return glslang_argv(tool, opts)
end

---@param argv string[]
---@return string
function M.describe_argv(argv)
    assert(type(argv) == 'table', 'describe_argv requires an argv table')
    return table.concat(argv, ' ')
end

return M
