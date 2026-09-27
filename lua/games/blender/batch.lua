-- #################################################################
-- /qompassai/Diver/lua/games/blender/batch.lua
-- Qompass AI Blender Batch
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
-- Batch operations over a directory of .blend files: one bounded
-- pass, one operation per file, a per-file timeout, and a summary
-- report. The file list is capped (config.batch.blend_max) and
-- sorted so runs are deterministic.
local config = require('games.blender.config')
local versions = require('games.blender.versions')
local render = require('games.blender.render')
local export = require('games.blender.export')
local sprites = require('games.blender.sprites')

local M = {}

---@class BlenderBatchFileResult
---@field blend string
---@field ok boolean
---@field outputs string[]
---@field err? string

---@class BlenderBatchSummary
---@field operation string
---@field total integer
---@field succeeded integer
---@field failed integer
---@field files BlenderBatchFileResult[]

---@class BlenderBatchOpts
---@field output_dir string Directory receiving per-file outputs
---@field timeout_ms? integer Per-file timeout in milliseconds
---@field width? integer
---@field height? integer
---@field samples? integer
---@field engine? string 'cycles' (default) or 'eevee'
---@field frames? integer Sprite/turntable frame count

M.operations = {
    'render_still',
    'export_glb',
    'export_fbx',
    'bake_sprites',
}

---@param dir string
---@param max_count integer
---@return string[]? blends Sorted .blend paths, or nil with an error
---@return string? err
function M.collect_blends(dir, max_count)
    if type(dir) ~= 'string' or dir == '' then
        return nil, 'blender: dir must be a non-empty path'
    end

    if vim.fn.isdirectory(dir) ~= 1 then
        return nil, 'blender: not a directory: ' .. dir
    end

    local entries = vim.fn.readdir(dir)
    local blends = {}

    for _, entry in ipairs(entries) do
        if entry:lower():sub(-6) == '.blend' then
            blends[#blends + 1] = dir .. '/' .. entry
        end
    end

    table.sort(blends)

    if #blends > max_count then
        return nil, ('blender: %d .blend files exceed the batch cap of %d'):format(#blends, max_count)
    end

    return blends, nil
end

---@param blend string
---@param operation string
---@param opts table Normalized batch opts
---@return string[]? outputs
---@return string? err
local function run_one(blend, operation, opts)
    local stem = vim.fn.fnamemodify(blend, ':t:r')
    local output_dir = opts.output_dir
    local render_opts = {
        width = opts.width,
        height = opts.height,
        samples = opts.samples,
        engine = opts.engine,
        timeout_ms = opts.timeout_ms,
    }

    if operation == 'render_still' then
        local info, err = render.render_still(blend, output_dir .. '/' .. stem .. '_still', render_opts)

        if info == nil then
            return nil, err
        end

        return info.saved, nil
    end

    if operation == 'export_glb' then
        local path, err = export.export_glb(blend, output_dir .. '/' .. stem .. '.glb')

        if path == nil then
            return nil, err
        end

        return { path }, nil
    end

    if operation == 'export_fbx' then
        local path, err = export.export_fbx(blend, output_dir .. '/' .. stem .. '.fbx')

        if path == nil then
            return nil, err
        end

        return { path }, nil
    end

    -- operation == 'bake_sprites'
    local sprite_opts = {
        frames = opts.frames,
        width = opts.width,
        height = opts.height,
        samples = opts.samples,
        engine = opts.engine,
        timeout_ms = opts.timeout_ms,
    }
    local png_out = output_dir .. '/' .. stem .. '.png'
    local json_out = output_dir .. '/' .. stem .. '.json'
    local manifest, err = sprites.bake(blend, png_out, json_out, sprite_opts)

    if manifest == nil then
        return nil, err
    end

    return { png_out, json_out }, nil
end

---Check whether a batch operation name is one of the supported operations.
---@param operation string Batch operation name
---@return boolean known
local function is_known_operation(operation)
    for _, candidate in ipairs(M.operations) do
        if candidate == operation then
            return true
        end
    end

    return false
end

---@param o table Raw batch options
---@return table? normalized
---@return string? err
local function normalize_run_opts(o)
    if type(o.output_dir) ~= 'string' or o.output_dir == '' then
        return nil, 'blender: opts.output_dir must be a non-empty path'
    end

    local timeout_ms = o.timeout_ms or config.batch.timeout_ms_default

    if type(timeout_ms) ~= 'number' or timeout_ms < 1000 or timeout_ms > config.batch.timeout_ms_max then
        return nil, 'blender: timeout_ms out of range'
    end

    return {
        output_dir = o.output_dir,
        timeout_ms = timeout_ms,
        width = o.width,
        height = o.height,
        samples = o.samples,
        engine = o.engine,
        frames = o.frames,
    },
        nil
end

---@param blends string[] Sorted .blend paths
---@param operation string Batch operation name
---@param normalized table Normalized batch options
---@return BlenderBatchSummary summary
local function run_all(blends, operation, normalized)
    ---@type BlenderBatchSummary
    local summary = {
        operation = operation,
        total = #blends,
        succeeded = 0,
        failed = 0,
        files = {},
    }

    for _, blend in ipairs(blends) do
        local outputs, err = run_one(blend, operation, normalized)

        ---@type BlenderBatchFileResult
        local file_result = {
            blend = blend,
            ok = outputs ~= nil,
            outputs = outputs or {},
            err = err,
        }

        summary.files[#summary.files + 1] = file_result

        if outputs ~= nil then
            summary.succeeded = summary.succeeded + 1
        else
            summary.failed = summary.failed + 1
        end
    end

    return summary
end

---Run one operation over every .blend in a directory.
---Version-guarded once up front; each file gets its own timeout.
---@param dir string Directory to scan for .blend files
---@param operation string One of M.operations
---@param opts? BlenderBatchOpts
---@return BlenderBatchSummary? summary
---@return string? err
function M.run(dir, operation, opts)
    local version_ok, version_err = versions.check_version()

    if not version_ok then
        return nil, version_err
    end

    if not is_known_operation(operation) then
        return nil, 'blender: unknown batch operation: ' .. tostring(operation)
    end

    local o = opts or {}
    local normalized, norm_err = normalize_run_opts(o)

    if normalized == nil then
        return nil, norm_err
    end

    vim.fn.mkdir(normalized.output_dir, 'p')

    local blends, collect_err = M.collect_blends(dir, config.batch.blend_max)

    if blends == nil then
        return nil, collect_err
    end

    return run_all(blends, operation, normalized), nil
end

return M
