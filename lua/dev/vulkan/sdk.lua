-- #################################################################
-- /qompassai/diver/lua/dev/vulkan/sdk.lua
-- Qompass AI Diver Vulkan SDK Detection
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
---@source https://vulkan.lunarg.com/doc/sdk/latest/linux/loader_layer_configuration.html
---@source https://docs.vulkan.org/spec/latest/chapters/extensions.html

--- Vulkan SDK detection, in plain language.
---
--- Think of the Vulkan SDK as the toolbox that teaches your computer to
--- talk to the graphics card. This module answers, honestly: is the
--- toolbox installed? Where is it? Which version? Are the "validation
--- layers" (the safety-net tools that catch API mistakes while you
--- develop) present?
---
--- Detection order: the VULKAN_SDK environment variable wins first
--- (that is the official SDK installer's own marker). If it is empty,
--- well-known system paths are probed. Nothing is invented: every
--- answer comes from a real directory check, a real binary, or the real
--- `vulkaninfo` output. A missing tool is reported as missing, never
--- as a guessed version.
---@module 'dev.vulkan.sdk'

local env = vim.env
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local M = {}

-- Bounds: vulkaninfo --summary is tens of KB; cap well above that so a
-- pathological pipe cannot grow the parse buffer without limit.
local SYSTEM_TIMEOUT_MS = 15000
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local LAYERS_MAX = 256
local VERSION_BYTES_MAX = 64

local VALIDATION_LAYER = 'VK_LAYER_KHRONOS_validation'

---@param value unknown
---@return boolean
local function nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@param value string
---@return boolean
local function has_nul(value)
    return value:find('%z') ~= nil
end

---@param path string
---@return boolean
local function is_dir(path)
    local stat = uv.fs_stat(path)
    return stat ~= nil and stat.type == 'directory'
end

---@param argv string[]
---@return string?, string?
local function system_text(argv)
    assert(type(argv) == 'table' and #argv > 0, 'argv must be a non-empty table')

    local ok, result = pcall(vim.system, argv, {
        text = true,
        timeout = SYSTEM_TIMEOUT_MS,
    }, nil)

    if not ok then
        return nil, 'failed to run ' .. argv[1] .. ': ' .. tostring(result)
    end

    if type(result) ~= 'table' then
        return nil, argv[1] .. ' returned no result'
    end

    if result.code ~= 0 then
        return nil, ('%s exited with code %d'):format(argv[1], result.code)
    end

    local stdout = result.stdout

    if type(stdout) ~= 'string' then
        return nil, argv[1] .. ' produced no stdout'
    end

    if #stdout > OUTPUT_BYTES_MAX then
        return nil, ('%s output exceeded %d bytes'):format(argv[1], OUTPUT_BYTES_MAX)
    end

    return stdout
end

--- Well-known Vulkan SDK install locations, checked in order after
--- VULKAN_SDK. These are the paths the LunarG SDK installer and the
--- Linux distro packages actually use; the list is intentionally
--- short rather than speculative.
---@return string[]
function M.well_known_roots()
    local home = env.HOME or ''

    ---@type string[]
    local roots = {
        '/usr/share/vulkan',
        '/usr/local/share/vulkan',
        '/etc/vulkan',
        '/opt/vulkan',
    }

    if home ~= '' then
        roots[#roots + 1] = fs.joinpath(home, '.local', 'share', 'vulkan')
    end

    return roots
end

--- Locate the Vulkan SDK root. VULKAN_SDK wins when it names an
--- existing directory; otherwise well-known paths are probed.
---@return string?, string?
function M.sdk_root()
    local configured = env.VULKAN_SDK

    if nonempty_string(configured) and not has_nul(configured) then
        ---@cast configured string
        local normalized = fs.normalize(configured)

        if is_dir(normalized) then
            return normalized
        end
        -- A stale VULKAN_SDK is not fatal: fall through to probing.
    end

    for _, root in ipairs(M.well_known_roots()) do
        if is_dir(root) then
            return root
        end
    end

    return nil, 'no Vulkan SDK root found (VULKAN_SDK unset and no well-known path exists)'
end

---@return boolean
function M.vulkaninfo_available()
    return fn.executable('vulkaninfo') == 1
end

---@return boolean
function M.vkconfig_available()
    return fn.executable('vkconfig') == 1
end

--- Parse the "Vulkan Instance Version: 1.4.357" line out of
--- `vulkaninfo --summary` output. Returns nil on anything else.
---@param text string
---@return string?
function M.parse_instance_version(text)
    if type(text) ~= 'string' or text == '' then
        return nil
    end

    local version = text:match('Vulkan Instance Version:%s*(%S+)')

    if version == nil or #version > VERSION_BYTES_MAX then
        return nil
    end

    return version
end

---@return string?, string?
function M.instance_version()
    if not M.vulkaninfo_available() then
        return nil, 'vulkaninfo is not installed or not in PATH'
    end

    local output, output_err = system_text({ 'vulkaninfo', '--summary' })

    if output == nil then
        return nil, output_err
    end

    local version = M.parse_instance_version(output)

    if version == nil then
        return nil, 'could not parse Vulkan instance version from vulkaninfo output'
    end

    return version
end

--- Parse the "Instance Layers" section of `vulkaninfo --summary`.
--- Each layer contributes its VK_LAYER_* name; descriptions and
--- versions are dropped. Bounded: at most LAYERS_MAX names.
---@param text string
---@return string[]
function M.parse_layers(text)
    ---@type string[]
    local layers = {}

    if type(text) ~= 'string' or text == '' then
        return layers
    end

    local in_section = false

    for line in text:gmatch('[^\r\n]+') do
        if not in_section then
            if line:match('^Instance Layers:') ~= nil then
                in_section = true
            end
        else
            if line:match('^%s*$') ~= nil or line:match('^[A-Z][%a ]+:') ~= nil then
                break
            end

            local name = line:match('^%s*(VK_LAYER_[%w_]+)')

            if name ~= nil and #layers < LAYERS_MAX then
                layers[#layers + 1] = name
            end
        end
    end

    return layers
end

---@return string[]?, string?
function M.layers()
    if not M.vulkaninfo_available() then
        return nil, 'vulkaninfo is not installed or not in PATH'
    end

    local output, output_err = system_text({ 'vulkaninfo', '--summary' })

    if output == nil then
        return nil, output_err
    end

    return M.parse_layers(output)
end

--- Directories the Vulkan loader searches for layer manifests,
--- from VK_LAYER_PATH (colon-separated). Empty entries are dropped.
---@return string[]
function M.vk_layer_path_dirs()
    ---@type string[]
    local dirs = {}
    local raw = env.VK_LAYER_PATH

    if not nonempty_string(raw) or has_nul(raw) then
        return dirs
    end

    ---@cast raw string
    for entry in raw:gmatch('[^:]+') do
        local trimmed = vim.trim(entry)

        if trimmed ~= '' then
            dirs[#dirs + 1] = trimmed
        end
    end

    return dirs
end

---@param layers string[]
---@return boolean
function M.validation_layer_available(layers)
    if type(layers) ~= 'table' then
        return false
    end

    for _, name in ipairs(layers) do
        if name == VALIDATION_LAYER then
            return true
        end
    end

    return false
end

---@class VulkanSdkStatus
---@field sdk_root string? detected SDK root, nil when none found
---@field sdk_error string? why no root was found
---@field vulkaninfo boolean vulkaninfo binary present
---@field instance_version string? e.g. "1.4.357"
---@field instance_error string? why the version is unknown
---@field layer_count integer
---@field validation_layer boolean VK_LAYER_KHRONOS_validation present
---@field vkconfig boolean vkconfig binary present
---@field vk_layer_path string[] VK_LAYER_PATH entries

--- Probe everything and return one honest report. Missing pieces are
--- reported as missing, never guessed.
---@return VulkanSdkStatus
function M.status()
    local root, root_err = M.sdk_root()
    local version, version_err = M.instance_version()
    local layer_list = {}

    if M.vulkaninfo_available() then
        local found = M.layers()
        if found ~= nil then
            layer_list = found
        end
    end

    return {
        sdk_root = root,
        sdk_error = root_err,
        vulkaninfo = M.vulkaninfo_available(),
        instance_version = version,
        instance_error = version_err,
        layer_count = #layer_list,
        validation_layer = M.validation_layer_available(layer_list),
        vkconfig = M.vkconfig_available(),
        vk_layer_path = M.vk_layer_path_dirs(),
    }
end

--- Render a status report as human-readable lines for a scratch
--- buffer or :messages.
---@param report VulkanSdkStatus
---@return string[]
function M.format_status(report)
    assert(type(report) == 'table', 'format_status requires a status table')

    ---@type string[]
    local lines = {
        'Vulkan SDK status',
        '=================',
        'SDK root: ' .. (report.sdk_root or ('not found (' .. (report.sdk_error or '?') .. ')')),
        'vulkaninfo: ' .. (report.vulkaninfo and 'present' or 'MISSING'),
        'Instance version: ' .. (report.instance_version or ('unknown (' .. (report.instance_error or '?') .. ')')),
        ('Instance layers: %d (validation layer %s)'):format(
            report.layer_count,
            report.validation_layer and 'present' or 'MISSING'
        ),
        'vkconfig: ' .. (report.vkconfig and 'present' or 'not installed'),
    }

    if #report.vk_layer_path > 0 then
        lines[#lines + 1] = 'VK_LAYER_PATH:'

        for _, dir in ipairs(report.vk_layer_path) do
            lines[#lines + 1] = '  ' .. dir
        end
    else
        lines[#lines + 1] = 'VK_LAYER_PATH: (unset)'
    end

    return lines
end

return M
