-- #################################################################
-- /qompassai/diver/lua/dev/vulkan/prompts.lua
-- Qompass AI Diver Vulkan-Aware Rose Prompt Templates
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

--- Vulkan-aware prompt templates, in plain language.
---
--- Rose (diver's in-editor AI, lua/ai/rose/) is a generalist: it knows
--- code, but it doesn't know that Vulkan has validation layers, or
--- what a VUID error means, or that a black screen usually means a
--- subpass dependency problem. These templates wrap the user's shader
--- or error text in a prompt that teaches Rose the Vulkan-specific
--- context first, so its answers start from the right mental model.
---
--- This module is pure Lua (no vim.* calls): building a prompt is just
--- string work, which also makes it unit-testable. Wiring to Rose
--- lives in dev/vulkan/init.lua, which passes the built prompt to
--- require('ai.rose').ask(). rose.nvim itself (a separate repo) is not
--- touched.
---
--- Safety note: user content is concatenated, never passed through
--- string.format, so a shader containing '%' cannot break template
--- rendering.
---@module 'dev.vulkan.prompts'

local M = {}

-- Bound: a prompt is a chat message, not a file dump. Sources larger
-- than this are truncated with a marker rather than silently dropped.
local CONTEXT_BYTES_MAX = 32 * 1024

---@class VulkanPromptContext
---@field file? string shader or source file name, for reference only
---@field source_text? string shader source to review
---@field error_text? string validation-layer or compiler error to explain
---@field pipeline_desc? string description of the pipeline/render pass setup

---@param text string?
---@return string
local function bounded(text)
    if type(text) ~= 'string' or text == '' then
        return '(none provided)'
    end

    if #text > CONTEXT_BYTES_MAX then
        return text:sub(1, CONTEXT_BYTES_MAX) .. '\n... [truncated]'
    end

    return text
end

---@param context VulkanPromptContext?
---@return VulkanPromptContext
local function normalize_context(context)
    if type(context) ~= 'table' then
        return {}
    end

    return context
end

---@param context VulkanPromptContext
---@return string
local function build_shader_review(context)
    local parts = {
        'You are a Vulkan/SPIR-V shader reviewer. Review the shader below for correctness,',
        'undefined behavior, and Vulkan-specific pitfalls. Be concrete: cite line numbers,',
        'name the exact rule or VUID when you know one, and say "I am not sure" when you are not.',
        '',
        'Check specifically:',
        '1. Uninitialized variables and out-of-bounds indexing (undefined behavior in SPIR-V).',
        '2. Descriptor set / binding numbers matching the pipeline layout the host code creates.',
        '3. Push constant ranges and alignment (16-byte alignment for vec4/mat4).',
        '4. Precision and integer width assumptions that differ between vendors.',
        '5. Barriers and memory dependencies the shader relies on (it cannot assume them).',
        '6. Portability: anything that works on one vendor driver but is not guaranteed.',
        '',
        'File: ' .. (type(context.file) == 'string' and context.file or '(unsaved buffer)'),
        '',
        'Shader source:',
        '```',
        bounded(context.source_text),
        '```',
        '',
        'Reply with: verdict (ship / fix-first / rewrite), then findings ordered by severity,',
        'each with a concrete fix.',
    }

    return table.concat(parts, '\n')
end

---@param context VulkanPromptContext
---@return string
local function build_validation_error(context)
    local parts = {
        'You are a Vulkan validation-layer expert. The user hit the validation error below.',
        'Explain it like they are a competent graphics programmer who has not memorized the spec.',
        '',
        'Validation error:',
        '```',
        bounded(context.error_text),
        '```',
        '',
        'Reply with:',
        '1. What the error means in plain language (one paragraph).',
        '2. The VUID or spec section it comes from, quoted briefly.',
        "3. The most likely root cause in the user's code, with the smallest code change that fixes it.",
        '4. How to confirm the fix (what the validation layers should print afterwards).',
        'Do not invent VUID numbers: if you do not know the exact one, say so and describe',
        'the rule instead.',
    }

    return table.concat(parts, '\n')
end

---@param context VulkanPromptContext
---@return string
local function build_pipeline_debug(context)
    local parts = {
        "You are a Vulkan pipeline debugging assistant. The user's pipeline misbehaves",
        '(black screen, wrong output, or validation errors). Work through the checklist below',
        'against their description and shader, and narrow it to the most likely causes.',
        '',
        'User description of the setup:',
        bounded(context.pipeline_desc),
        '',
        'Related shader source (if provided):',
        '```',
        bounded(context.source_text),
        '```',
        '',
        'Checklist, in the order you should suspect them:',
        '1. Render pass attachments: load/store ops, initial/final layouts, clear values.',
        '2. Subpass dependencies: missing or wrong srcStageMask/dstStageMask and access masks.',
        '3. Descriptor sets actually bound at draw time vs. what the layout declares.',
        '4. Dynamic state (viewport, scissor) set before drawing when declared dynamic.',
        '5. Vertex input bindings and attribute descriptions matching the mesh data.',
        '6. Synchronization: is the image/layout transition the shader needs actually there?',
        '',
        'Reply with the top 3 suspects ranked, what evidence would confirm each, and the',
        'single cheapest experiment to run first (e.g. a RenderDoc capture of one frame).',
    }

    return table.concat(parts, '\n')
end

---@type table<string, { title: string, description: string, build: fun(context: VulkanPromptContext): string }>
local TEMPLATES = {
    shader_review = {
        title = 'Shader review',
        description = 'Review a shader for correctness, UB, and Vulkan pitfalls.',
        build = build_shader_review,
    },
    validation_error = {
        title = 'Validation-layer error explanation',
        description = 'Explain a validation-layer error in plain language with a fix.',
        build = build_validation_error,
    },
    pipeline_debug = {
        title = 'Pipeline debugging',
        description = 'Narrow down a misbehaving pipeline with a ranked suspect list.',
        build = build_pipeline_debug,
    },
}

--- Build a prompt from a template name and context. Context is data:
--- it is concatenated into the template, never interpreted.
---@param name string one of M.names()
---@param context? VulkanPromptContext
---@return string?, string?
function M.build(name, context)
    if type(name) ~= 'string' then
        return nil, 'template name must be a string'
    end

    local template = TEMPLATES[name]

    if template == nil then
        return nil, 'unknown prompt template: ' .. name
    end

    local normalized = normalize_context(context)

    return template.build(normalized)
end

---@return string[]
function M.names()
    ---@type string[]
    local names = {}

    for name in pairs(TEMPLATES) do
        names[#names + 1] = name
    end

    table.sort(names)

    return names
end

---@param name string
---@return string?, string?
function M.describe(name)
    if type(name) ~= 'string' then
        return nil, 'template name must be a string'
    end

    local template = TEMPLATES[name]

    if template == nil then
        return nil, 'unknown prompt template: ' .. name
    end

    return template.title .. ': ' .. template.description
end

return M
