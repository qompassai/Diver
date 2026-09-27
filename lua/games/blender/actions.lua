-- #################################################################
-- /qompassai/Diver/lua/games/blender/actions.lua
-- Qompass AI Blender Actions
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
-- Interactive Blender actions: prompt for a .blend and an output,
-- then run the operation through the shared output window with
-- progress. Pure orchestration lives in render/export/sprites/
-- batch; this module only wires prompts to those functions.
local config = require('games.blender.config')
local versions = require('games.blender.versions')
local render = require('games.blender.render')
local export = require('games.blender.export')
local sprites = require('games.blender.sprites')
local batch = require('games.blender.batch')
local shared_util = require('games.shared.util')

local notify = vim.notify
local levels = vim.log.levels
local M = {}

---@return string? blend
local function current_blend_or_prompt()
    local current = vim.api.nvim_buf_get_name(0)

    if current:lower():sub(-6) == '.blend' then
        return current
    end

    local picked = shared_util.trim(vim.fn.input('Blender file (.blend): ', '', 'file'))

    if picked == '' then
        return nil
    end

    return picked
end

---@param prompt string
---@param default string
---@return string? path
local function prompt_path(prompt, default)
    local picked = shared_util.trim(vim.fn.input(prompt, default, 'file'))

    if picked == '' then
        return nil
    end

    return picked
end

---@param title string
---@param blend string
---@param label string
---@param runner fun(): any?, string?
local function run_blocking(title, blend, label, runner)
    local bin = versions.ensure_installed()

    if bin == nil then
        notify('Blender: binary not found -- install it or set BLENDER_BIN', levels.ERROR)
        return
    end

    -- Renders are synchronous: the editor blocks until blender exits
    -- (bounded by the per-operation timeout). The runner is deferred
    -- with vim.schedule so the prompt echo above paints first.
    notify(('Blender: %s started for %s'):format(title, vim.fs.basename(blend)), levels.INFO)

    vim.schedule(function()
        local _, err = runner()

        if err ~= nil then
            notify('Blender: ' .. err, levels.ERROR)
        else
            notify(('Blender: %s finished.'):format(label), levels.INFO)
        end
    end)
end

function M.render_still()
    local blend = current_blend_or_prompt()

    if blend == nil then
        return
    end

    local out = prompt_path('Blender still output prefix: ', vim.fn.fnamemodify(blend, ':r') .. '_still')

    if out == nil then
        return
    end

    run_blocking('BlenderRenderStill', blend, 'Rendering still for', function()
        return render.render_still(blend, out, {})
    end)
end

function M.render_turntable()
    local blend = current_blend_or_prompt()

    if blend == nil then
        return
    end

    local outdir = prompt_path('Blender turntable output dir: ', vim.fn.fnamemodify(blend, ':r') .. '_turntable')

    if outdir == nil then
        return
    end

    run_blocking('BlenderTurntable', blend, 'Rendering turntable for', function()
        return render.render_turntable(blend, outdir, {})
    end)
end

function M.export_glb()
    local blend = current_blend_or_prompt()

    if blend == nil then
        return
    end

    local out = prompt_path('Blender glTF output (.glb): ', vim.fn.fnamemodify(blend, ':r') .. '.glb')

    if out == nil then
        return
    end

    run_blocking('BlenderExportGlb', blend, 'Exporting glTF for', function()
        return export.export_glb(blend, out)
    end)
end

function M.export_fbx()
    local blend = current_blend_or_prompt()

    if blend == nil then
        return
    end

    local out = prompt_path('Blender FBX output (.fbx): ', vim.fn.fnamemodify(blend, ':r') .. '.fbx')

    if out == nil then
        return
    end

    run_blocking('BlenderExportFbx', blend, 'Exporting FBX for', function()
        return export.export_fbx(blend, out)
    end)
end

function M.bake_sprites()
    local blend = current_blend_or_prompt()

    if blend == nil then
        return
    end

    local stem = vim.fn.fnamemodify(blend, ':r')
    local out_png = prompt_path('Blender sprite strip (.png): ', stem .. '_sprites.png')

    if out_png == nil then
        return
    end

    local out_json = prompt_path('Blender sprite manifest (.json): ', stem .. '_sprites.json')

    if out_json == nil then
        return
    end

    run_blocking('BlenderSprites', blend, 'Baking sprites for', function()
        return sprites.bake(blend, out_png, out_json, {})
    end)
end

function M.batch_render()
    local dir = prompt_path('Blender batch directory: ', vim.fn.getcwd())

    if dir == nil then
        return
    end

    local outdir = prompt_path('Blender batch output dir: ', dir .. '/blender_out')

    if outdir == nil then
        return
    end

    vim.ui.select(batch.operations, {
        prompt = 'Batch operation:',
    }, function(operation)
        if operation == nil then
            return
        end

        run_blocking('BlenderBatch', dir, 'Batch ' .. operation .. ' in', function()
            local summary, err = batch.run(dir, operation, { output_dir = outdir })

            if summary == nil then
                return nil, err
            end

            notify(
                ('Blender batch %s: %d/%d succeeded'):format(operation, summary.succeeded, summary.total),
                summary.failed == 0 and levels.INFO or levels.WARN
            )

            return summary, nil
        end)
    end)
end

function M.describe_environment()
    local bin = versions.binary_path()
    local version = bin and versions.installed_version(bin) or nil

    notify(
        table.concat({
            'Blender binary: ' .. (bin or 'not found'),
            'Blender version: ' .. (version or 'unknown'),
            'Pinned release: ' .. config.pinned_version,
            'Minimum release: ' .. config.min_version,
            'Managed install root: ' .. config.tools_dir,
        }, '\n'),
        levels.INFO
    )
end

function M.get_actions()
    return {
        {
            id = 'render_still',
            label = 'Render still (headless)',
            group = 'Render',
            run = M.render_still,
        },
        {
            id = 'render_turntable',
            label = 'Render turntable',
            group = 'Render',
            run = M.render_turntable,
        },
        {
            id = 'export_glb',
            label = 'Export glTF (.glb)',
            group = 'Export',
            run = M.export_glb,
        },
        {
            id = 'export_fbx',
            label = 'Export FBX (.fbx)',
            group = 'Export',
            run = M.export_fbx,
        },
        {
            id = 'bake_sprites',
            label = 'Bake sprite sheet + manifest',
            group = 'Sprites',
            run = M.bake_sprites,
        },
        {
            id = 'batch_render',
            label = 'Batch over .blend directory',
            group = 'Batch',
            run = M.batch_render,
        },
        {
            id = 'describe_environment',
            label = 'Describe environment',
            group = 'Scripting',
            run = M.describe_environment,
        },
    }
end

function M.run_action(action)
    action.run()
end

function M.run_action_by_id(id)
    local list = M.get_actions()
    local map = shared_util.build_action_map(list)
    local action = map[id]

    if not action then
        notify('Unknown Blender action: ' .. id, levels.ERROR)
        return
    end

    M.run_action(action)
end

function M.show_menu()
    require('games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
        group_order = config.group_order,
        prompt = 'Select Blender action:',
    })
end

return M
