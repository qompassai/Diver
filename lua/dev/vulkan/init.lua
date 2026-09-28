-- #################################################################
-- /qompassai/diver/lua/dev/vulkan/init.lua
-- Qompass AI Diver Vulkan Utils Init
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

--- Vulkan workflow hub, in plain language.
---
--- One place that wires the whole Vulkan story together: SDK detection
--- (dev.vulkan.sdk), shader compiler probing (dev.vulkan.toolchain),
--- compile-on-save to SPIR-V (dev.vulkan.compile), language-server
--- status (dev.vulkan.lsp), and Vulkan-aware Rose prompts
--- (dev.vulkan.prompts). Frame capture itself lives in
--- dap/renderdoc.lua (:VulkanCapture) because RenderDoc is capture
--- tooling, not a Vulkan-SDK concern.
---
--- Commands registered by setup():
---   :VulkanStatus     SDK / vulkaninfo / layers / vkconfig report
---   :VulkanToolchain  shader compiler probe report
---   :VulkanLayers     instance layer list
---   :VulkanLsp        glsl_analyzer + clangd status
---   :VulkanCompile    compile the current shader buffer now
---   :VulkanRoseReview ask Rose to review the current shader buffer
---   :VulkanRoseExplain ask Rose to explain a validation-layer error
---   :VulkanRosePipeline ask Rose to debug a pipeline setup
---@module 'dev.vulkan'

local api = vim.api
local levels = vim.log.levels

local M = {}

M.sdk = require('dev.vulkan.sdk')
M.toolchain = require('dev.vulkan.toolchain')
M.compile = require('dev.vulkan.compile')
M.lsp = require('dev.vulkan.lsp')
M.prompts = require('dev.vulkan.prompts')

local setup_done = false

---@param title string
---@param lines string[]
local function show_scratch(title, lines)
    local bufnr = api.nvim_create_buf(false, true)

    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')

    local width = math.min(100, math.max(60, api.nvim_get_option_value('columns', {}) - 20))
    local height = math.min(30, #lines + 2)

    api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((api.nvim_get_option_value('columns', {}) - width) / 2),
        row = math.floor((api.nvim_get_option_value('lines', {}) - height) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' ' .. title .. ' ',
    })
end

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(('[vulkan] %s'):format(message), level or levels.INFO)
end

---@param command string
---@param callback fun(args: vim.api.keyset.create_user_command.command_args)
---@param desc string
---@param opts? vim.api.keyset.user_command
local function add_command(command, callback, desc, opts)
    local spec = vim.tbl_extend('force', { desc = desc }, opts or {})

    api.nvim_create_user_command(command, callback, spec)
end

---@param template string
local function rose_ask_template(template)
    local ok, rose = pcall(require, 'ai.rose')

    if not ok or type(rose) ~= 'table' or type(rose.ask) ~= 'function' then
        notify('ai.rose is not available', levels.ERROR)

        return
    end

    rose.ask(template)
end

local function rose_review()
    local bufnr = api.nvim_get_current_buf()
    local file = api.nvim_buf_get_name(bufnr)
    local text = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')

    local prompt, prompt_err = M.prompts.build('shader_review', {
        file = file ~= '' and file or nil,
        source_text = text,
    })

    if prompt == nil then
        notify(prompt_err or 'could not build prompt', levels.ERROR)

        return
    end

    rose_ask_template(prompt)
end

local function rose_explain()
    local error_text = vim.fn.input('Validation-layer error> ')

    if error_text == '' then
        return
    end

    local prompt, prompt_err = M.prompts.build('validation_error', { error_text = error_text })

    if prompt == nil then
        notify(prompt_err or 'could not build prompt', levels.ERROR)

        return
    end

    rose_ask_template(prompt)
end

local function rose_pipeline()
    local pipeline_desc = vim.fn.input('Pipeline/render-pass description> ')

    if pipeline_desc == '' then
        return
    end

    local prompt, prompt_err = M.prompts.build('pipeline_debug', { pipeline_desc = pipeline_desc })

    if prompt == nil then
        notify(prompt_err or 'could not build prompt', levels.ERROR)

        return
    end

    rose_ask_template(prompt)
end

---@class VulkanSetupOptions
---@field compile? VulkanCompileOptions options forwarded to dev.vulkan.compile.setup

---@param opts? VulkanSetupOptions
function M.setup(opts)
    opts = opts or {}

    if setup_done then
        return
    end

    setup_done = true

    M.compile.setup(opts.compile)

    add_command('VulkanStatus', function()
        show_scratch('Vulkan SDK status', M.sdk.format_status(M.sdk.status()))
    end, 'Show Vulkan SDK / vulkaninfo / layer status')

    add_command('VulkanToolchain', function()
        ---@type string[]
        local lines = { 'Vulkan shader toolchain', '=======================', '' }

        for _, name in ipairs(M.toolchain.tool_names()) do
            local probe, probe_err = M.toolchain.probe(name)

            if probe == nil then
                lines[#lines + 1] = name .. ': error: ' .. (probe_err or '?')
            elseif not probe.found then
                lines[#lines + 1] = name .. ': MISSING (not in PATH)'
            else
                lines[#lines + 1] = ('%s: %s%s'):format(
                    name,
                    probe.version or 'installed, version unknown',
                    probe.path and ('\n    ' .. probe.path) or ''
                )
            end
        end

        show_scratch('Vulkan toolchain', lines)
    end, 'Show shader compiler probe report')

    add_command('VulkanLayers', function()
        local layers, layers_err = M.sdk.layers()

        if layers == nil then
            notify(layers_err or 'could not list layers', levels.ERROR)

            return
        end

        ---@type string[]
        local lines = { ('Vulkan instance layers (%d)'):format(#layers), '' }

        for _, name in ipairs(layers) do
            lines[#lines + 1] = (name == 'VK_LAYER_KHRONOS_validation' and '* ' or '  ') .. name
        end

        lines[#lines + 1] = ''
        lines[#lines + 1] = '* = validation layer'

        show_scratch('Vulkan layers', lines)
    end, 'List Vulkan instance layers')

    add_command('VulkanLsp', function()
        show_scratch('Vulkan language servers', M.lsp.format_report(M.lsp.check()))
    end, 'Show glsl_analyzer / clangd status')

    add_command('VulkanCompile', function()
        local ok, compile_err = M.compile.compile_buffer(api.nvim_get_current_buf())

        if not ok then
            notify(compile_err or 'compile failed', levels.ERROR)
        end
    end, 'Compile the current shader buffer to SPIR-V now')

    add_command('VulkanRoseReview', rose_review, 'Ask Rose to review the current shader')
    add_command('VulkanRoseExplain', rose_explain, 'Ask Rose to explain a validation-layer error')
    add_command('VulkanRosePipeline', rose_pipeline, 'Ask Rose to debug a pipeline setup')
end

return M
