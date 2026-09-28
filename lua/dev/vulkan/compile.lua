-- #################################################################
-- /qompassai/diver/lua/dev/vulkan/compile.lua
-- Qompass AI Diver Vulkan Compile-on-Save
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

--- Compile-on-save for shaders, in plain language.
---
--- When you save a shader file, this module compiles it to SPIR-V
--- (the binary format Vulkan drivers actually consume) and shows any
--- compiler errors right in the buffer via vim.diagnostic — the same
--- diagnostic system the native linters (see lua/linters/dxc.lua) use.
--- It is deliberately separate from the linter framework: linters
--- check code, this module produces the artifact your renderer loads.
---
--- Default tool per extension: .hlsl -> dxc, .slang -> slangc,
--- everything else -> glslangValidator. Diagnostics from an async
--- compile are dropped if the buffer was closed or edited since, so
--- stale errors never stick around.
---@module 'dev.vulkan.compile'

local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local toolchain = require('dev.vulkan.toolchain')

local M = {}

local SOURCE = 'vulkan-compile'
local NAMESPACE = api.nvim_create_namespace('diver_vulkan')
local AUGROUP = 'diver-vulkan-compile'

-- Bounds: one compile per save, 30s cap; compiler output is small
-- text, capped well above any real diagnostic dump.
local COMPILE_TIMEOUT_MS = 30000
local OUTPUT_BYTES_MAX = 1024 * 1024
local FINDINGS_MAX = 512
local MESSAGE_BYTES_MAX = 2048
local LINE_BYTES_MAX = 16 * 1024

---@type string[]
local SHADER_PATTERNS = {
    '*.vert',
    '*.frag',
    '*.tesc',
    '*.tese',
    '*.geom',
    '*.comp',
    '*.mesh',
    '*.task',
    '*.rgen',
    '*.rint',
    '*.rahit',
    '*.rchit',
    '*.rmiss',
    '*.rcall',
    '*.glsl',
    '*.hlsl',
    '*.slang',
}

---@type table<string, string>
local TOOL_FOR_EXT = {
    ['.hlsl'] = 'dxc',
    ['.slang'] = 'slangc',
}

---@return string[]
function M.shader_patterns()
    local copy = {}

    for _, pattern in ipairs(SHADER_PATTERNS) do
        copy[#copy + 1] = pattern
    end

    return copy
end

--- Pick the default compiler for a file extension. Returns nil for
--- extensions this module does not compile.
---@param ext string file extension including the dot
---@return string?
function M.tool_for_ext(ext)
    if type(ext) ~= 'string' or ext == '' then
        return nil
    end

    local forced = TOOL_FOR_EXT[ext:lower()]

    if forced ~= nil then
        return forced
    end

    local stage, _ = toolchain.stage_for_ext(ext)

    if stage ~= nil then
        return 'glslangValidator'
    end

    return nil
end

---@class VulkanFinding
---@field file string
---@field line integer 1-based
---@field col integer 1-based
---@field severity string "error" | "warning" | "info"
---@field message string

---@param line string
---@return VulkanFinding?
local function parse_finding(line)
    if line == '' or #line > LINE_BYTES_MAX or line:find('%z') ~= nil then
        return nil
    end

    -- glslang/glslc/dxc style: file:line:col: error: message
    local file, line_number, column, level, message = line:match('^(.+):(%d+):(%d+):%s*(%a+)%s*:%s*(.+)$')

    if file == nil then
        -- Column-less variant: file:line: error: message
        file, line_number, level, message = line:match('^(.+):(%d+):%s*(%a+)%s*:%s*(.+)$')
        column = '1'
    end

    if file == nil or line_number == nil or level == nil or message == nil then
        return nil
    end

    local normalized = level:lower()
    local severity = 'info'

    if normalized == 'error' or normalized == 'fatal error' then
        severity = 'error'
    elseif normalized == 'warning' or normalized == 'warn' then
        severity = 'warning'
    end

    if #message > MESSAGE_BYTES_MAX then
        message = message:sub(1, MESSAGE_BYTES_MAX - 3) .. '...'
    end

    return {
        file = vim.trim(file),
        line = math.max(1, math.floor(tonumber(line_number) or 1)),
        col = math.max(1, math.floor(tonumber(column) or 1)),
        severity = severity,
        message = vim.trim(message),
    }
end

--- Parse compiler stderr/stdout into findings. Pure: no vim calls
--- beyond vim.trim, so it is unit-testable.
---@param text string combined compiler output
---@return VulkanFinding[]
function M.parse_findings(text)
    ---@type VulkanFinding[]
    local findings = {}

    if type(text) ~= 'string' or text == '' then
        return findings
    end

    if #text > OUTPUT_BYTES_MAX then
        text = text:sub(1, OUTPUT_BYTES_MAX)
    end

    for raw_line in text:gmatch('[^\r\n]+') do
        if #findings >= FINDINGS_MAX then
            break
        end

        local finding = parse_finding(vim.trim(raw_line))

        if finding ~= nil then
            findings[#findings + 1] = finding
        end
    end

    return findings
end

---@param severity string
---@return integer
local function diagnostic_severity(severity)
    if severity == 'error' then
        return diagnostic.severity.ERROR
    end

    if severity == 'warning' then
        return diagnostic.severity.WARN
    end

    return diagnostic.severity.INFO
end

--- Convert findings to vim.Diagnostic entries for a buffer. A finding
--- that names a different file becomes a line-1 diagnostic whose
--- message is prefixed with that file, so cross-file errors stay
--- visible instead of vanishing.
---@param findings VulkanFinding[]
---@param bufnr integer
---@param source_file string normalized path of the compiled file
---@return vim.Diagnostic[]
function M.to_diagnostics(findings, bufnr, source_file)
    assert(type(findings) == 'table', 'findings must be a table')
    assert(type(bufnr) == 'number', 'bufnr must be a number')

    ---@type vim.Diagnostic[]
    local diagnostics = {}

    for _, finding in ipairs(findings) do
        local lnum = finding.line - 1
        local col = finding.col - 1
        local message = finding.message

        if finding.file ~= '' and fs.normalize(finding.file) ~= fs.normalize(source_file) then
            message = finding.file .. ': ' .. message
            lnum = 0
            col = 0
        end

        diagnostics[#diagnostics + 1] = {
            bufnr = bufnr,
            col = col,
            end_col = col,
            end_lnum = lnum,
            lnum = lnum,
            message = message,
            severity = diagnostic_severity(finding.severity),
            source = SOURCE,
        }
    end

    return diagnostics
end

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@class VulkanCompileOptions
---@field tool? string override the default compiler for the extension
---@field output_dir? string directory for the .spv file (default: next to the source)
---@field stage? string pipeline stage override (needed for bare .glsl)
---@field entry? string entry point override (dxc/slangc, default "main")
---@field profile? string HLSL profile override (dxc; inferred from the filename otherwise)

---@param ext string
---@return string?, string?
local function dxc_profile_for_ext(ext)
    -- Reuse the same suffix table the native dxc linter uses; a bare
    -- .hlsl falls back to a library profile.
    local suffix_map = {
        ['.vert.hlsl'] = 'vs_6_8',
        ['.frag.hlsl'] = 'ps_6_8',
        ['.comp.hlsl'] = 'cs_6_8',
    }

    return suffix_map[ext:lower()], 'cannot infer an HLSL profile for ' .. ext
end

---@param bufnr integer
---@param opts VulkanCompileOptions?
---@return boolean, string?
function M.compile_buffer(bufnr, opts)
    opts = opts or {}

    if not api.nvim_buf_is_valid(bufnr) then
        return false, 'buffer is not valid'
    end

    local file = api.nvim_buf_get_name(bufnr)

    if file == '' then
        return false, 'buffer has no file name'
    end

    local ext = fs.normalize(file):match('(%.[^%.%/\\]+)$')

    if ext == nil then
        return false, 'cannot determine a shader extension for ' .. file
    end

    local tool = opts.tool or M.tool_for_ext(ext)

    if tool == nil then
        return false, 'no shader compiler mapped for extension ' .. ext
    end

    local probe = toolchain.probe(tool)

    if probe == nil or not probe.found then
        return false, tool .. ' is not installed or not in PATH'
    end

    local stage = opts.stage

    if tool ~= 'dxc' then
        if type(stage) ~= 'string' or stage == '' then
            local inferred, infer_err = toolchain.stage_for_ext(ext)

            if inferred == nil then
                return false, infer_err
            end

            stage = inferred
        end
    end

    local output_dir = opts.output_dir

    if type(output_dir) ~= 'string' or output_dir == '' then
        output_dir = fs.dirname(file)
    end

    local output = fs.joinpath(output_dir, fn.fnamemodify(file, ':t') .. '.spv')
    local changedtick = api.nvim_buf_get_changedtick(bufnr)

    ---@type VulkanCompileArgs
    local compile_opts = {
        stage = stage,
        source = file,
        output = output,
        entry = opts.entry,
    }

    if tool == 'dxc' then
        if type(opts.profile) == 'string' and opts.profile ~= '' then
            compile_opts.profile = opts.profile
        else
            local profile, profile_err = dxc_profile_for_ext(ext)

            if profile == nil then
                return false, profile_err
            end

            compile_opts.profile = profile
        end
    end

    local argv, argv_err = toolchain.build_argv(tool, compile_opts)

    if argv == nil then
        return false, argv_err
    end

    local ok, spawn_err = pcall(vim.system, argv, {
        text = true,
        timeout = COMPILE_TIMEOUT_MS,
    }, function(result)
        vim.schedule(function()
            -- Stale-result guard: the buffer may have been closed or
            -- edited while the compiler ran.
            if not api.nvim_buf_is_valid(bufnr) then
                return
            end

            if api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
                return
            end

            local text = (type(result.stdout) == 'string' and result.stdout or '')
                .. (type(result.stderr) == 'string' and result.stderr or '')
            local findings = M.parse_findings(text)
            local diagnostics = M.to_diagnostics(findings, bufnr, file)

            diagnostic.set(NAMESPACE, bufnr, diagnostics)

            if result.code == 0 then
                local errors = 0

                for _, finding in ipairs(findings) do
                    if finding.severity == 'error' then
                        errors = errors + 1
                    end
                end

                if errors == 0 then
                    notify(('compiled %s -> %s'):format(fn.fnamemodify(file, ':t'), output))
                else
                    notify(('compiled with %d error(s); see diagnostics'):format(errors), levels.WARN)
                end
            else
                if #diagnostics == 0 then
                    notify(('compile failed (exit %d) with no parseable diagnostics'):format(result.code), levels.ERROR)
                else
                    notify(
                        ('compile failed (exit %d): %d diagnostic(s)'):format(result.code, #diagnostics),
                        levels.ERROR
                    )
                end
            end
        end)
    end)

    if not ok then
        return false, 'failed to start ' .. tool .. ': ' .. tostring(spawn_err)
    end

    return true
end

local setup_done = false

---@param opts? VulkanCompileOptions options applied to every save-compile
function M.setup(opts)
    opts = opts or {}

    if setup_done then
        return
    end

    setup_done = true

    local group = api.nvim_create_augroup(AUGROUP, { clear = true })

    api.nvim_create_autocmd('BufWritePost', {
        group = group,
        pattern = SHADER_PATTERNS,
        desc = 'Compile shader to SPIR-V on save and surface diagnostics',
        callback = function(event)
            local ok, compile_err = M.compile_buffer(event.buf, opts)

            if not ok then
                notify(compile_err or 'compile failed', levels.WARN)
            end
        end,
    })
end

return M
