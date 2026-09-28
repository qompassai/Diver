-- #################################################################
-- /qompassai/diver/lua/dev/vulkan/lsp.lua
-- Qompass AI Diver Vulkan Shader LSP Status
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
---@source https://github.com/nolanderc/glsl_analyzer

--- Shader LSP status, in plain language.
---
--- A language server gives you squiggles, hover docs and go-to-definition
--- while you type. For shaders, diver already wires glsl_analyzer
--- (see lsp/glslana_ls.lua — verified upstream at
--- github.com/nolanderc/glsl_analyzer, a real LSP server speaking the
--- standard protocol over stdio). For C++ host code, clangd is already
--- wired too (lsp/clangd_ls.lua). This module does NOT add new LSP
--- configs; it checks the servers are actually installed and reports
--- their versions, so `:VulkanLsp` can tell you "glsl_analyzer is
--- missing" instead of leaving you wondering why there are no
--- diagnostics.
---
--- Honest gap, stated loudly: glsl_analyzer covers GLSL only. There is
--- no verified LSP server for Slang (.slang) wired here — slangd ships
--- inside the Slang release and speaks LSP, but it has not been
--- evaluated against diver's strict config profile, so it is not
--- wired. HLSL gets dxc-based linting (lua/linters/dxc.lua) instead of
--- an LSP.
---@module 'dev.vulkan.lsp'

local fn = vim.fn

local M = {}

local SYSTEM_TIMEOUT_MS = 10000
local VERSION_BYTES_MAX = 128

---@type table<string, { bin: string, version_arg: string, config: string }>
local SERVERS = {
    glsl_analyzer = {
        bin = 'glsl_analyzer',
        version_arg = '--version',
        config = 'lsp/glslana_ls.lua',
    },
    clangd = {
        bin = 'clangd',
        version_arg = '--version',
        config = 'lsp/clangd_ls.lua',
    },
}

---@param name string
---@return boolean
local function known_server(name)
    return SERVERS[name] ~= nil
end

---@param bin string
---@param version_arg string
---@return string?
local function server_version(bin, version_arg)
    local ok, result = pcall(vim.system, { bin, version_arg }, {
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

---@class VulkanLspServerStatus
---@field name string
---@field config string diver LSP config that wires this server
---@field found boolean
---@field path string? absolute path when found
---@field version string? nil when the version flag failed

--- Check one language server. `found` is authoritative; `version`
--- is best-effort and honestly nil when the server won't report it.
---@param name string "glsl_analyzer" or "clangd"
---@return VulkanLspServerStatus?, string?
function M.check_server(name)
    if type(name) ~= 'string' or not known_server(name) then
        return nil, 'unknown language server: ' .. tostring(name)
    end

    local spec = SERVERS[name]

    if fn.executable(spec.bin) ~= 1 then
        return { name = name, config = spec.config, found = false }
    end

    local path = fn.exepath(spec.bin)

    return {
        name = name,
        config = spec.config,
        found = true,
        path = (type(path) == 'string' and path ~= '') and path or nil,
        version = server_version(spec.bin, spec.version_arg),
    }
end

---@return string[]
function M.server_names()
    ---@type string[]
    local names = {}

    for name in pairs(SERVERS) do
        names[#names + 1] = name
    end

    table.sort(names)

    return names
end

---@return table<string, VulkanLspServerStatus>
function M.check()
    ---@type table<string, VulkanLspServerStatus>
    local report = {}

    for _, name in ipairs(M.server_names()) do
        local status = M.check_server(name)

        if status ~= nil then
            report[name] = status
        end
    end

    return report
end

--- Render a check report as human-readable lines.
---@param report table<string, VulkanLspServerStatus>
---@return string[]
function M.format_report(report)
    assert(type(report) == 'table', 'format_report requires a report table')

    ---@type string[]
    local lines = {
        'Vulkan language servers',
        '=======================',
    }

    for _, name in ipairs(M.server_names()) do
        local status = report[name]

        if status == nil then
            lines[#lines + 1] = name .. ': not checked'
        elseif not status.found then
            lines[#lines + 1] = ('%s: MISSING (config %s has nothing to launch)'):format(name, status.config)
        else
            lines[#lines + 1] = ('%s: %s (%s)'):format(
                name,
                status.version or 'installed, version unknown',
                status.config
            )
        end
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Note: no verified Slang LSP is wired; HLSL uses the dxc native linter.'

    return lines
end

return M
