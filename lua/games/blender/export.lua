-- #################################################################
-- /qompassai/Diver/lua/games/blender/export.lua
-- Qompass AI Blender Export
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
-- glTF (.glb) and FBX export through `blender -b <blend> --python`.
-- The exporter scripts are static text: the output path travels via
-- the BLENDER_EXPORT_OUTPUT environment variable and the argv list,
-- never interpolated into Python code, so hostile paths cannot break
-- out. Exported files are validated to exist with nonzero size.
local versions = require('games.blender.versions')

local M = {}

local EXPORT_TIMEOUT_MS = 600000
local EXPORT_SCRIPT_TIMEOUT_MS = 15000

---@alias BlenderExportKind 'glb'|'fbx'

---@param kind BlenderExportKind
---@return string? script Static exporter script, or nil for an unknown kind
function M.build_script(kind)
    if kind == 'glb' then
        return table.concat({
            'import bpy, os',
            'out = os.environ["BLENDER_EXPORT_OUTPUT"]',
            'bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")',
            'print("DIVER_EXPORT_OK " + out)',
        }, '\n') .. '\n'
    end

    if kind == 'fbx' then
        return table.concat({
            'import bpy, os',
            'out = os.environ["BLENDER_EXPORT_OUTPUT"]',
            'bpy.ops.export_scene.fbx(filepath=out)',
            'print("DIVER_EXPORT_OK " + out)',
        }, '\n') .. '\n'
    end

    return nil
end

---Build the export argv. Pure: no binary needed.
---@param bin string Blender binary path
---@param blend string .blend file path
---@param script_path string Generated exporter script path
---@return string[]? argv
---@return string? err
function M.build_argv(bin, blend, script_path)
    if type(bin) ~= 'string' or bin == '' then
        return nil, 'blender: bin must be a non-empty path'
    end

    if type(blend) ~= 'string' or blend == '' then
        return nil, 'blender: blend must be a non-empty path'
    end

    if type(script_path) ~= 'string' or script_path == '' then
        return nil, 'blender: script_path must be a non-empty path'
    end

    return {
        bin,
        '-b',
        blend,
        '--python',
        script_path,
    }, nil
end

---Confirm the export landed: file exists and is nonzero.
---@param path string Expected output path
---@return boolean ok
---@return string? err
function M.validate_output(path)
    if type(path) ~= 'string' or path == '' then
        return false, 'blender: output path must be a non-empty string'
    end

    local stat = vim.uv.fs_stat(path)

    if stat == nil then
        return false, 'blender: export produced no file at ' .. path
    end

    if stat.size == 0 then
        return false, 'blender: export produced an empty file at ' .. path
    end

    return true, nil
end

---Write the export script for a kind to a temp file.
---@param kind string 'glb' or 'fbx'
---@return string? script_path
---@return string? err
local function write_export_script(kind)
    local script = M.build_script(kind)

    if script == nil then
        return nil, 'blender: unknown export kind: ' .. tostring(kind)
    end

    local script_path = vim.fn.tempname() .. '-blender-export-' .. kind .. '.py'

    if vim.fn.writefile(vim.split(script, '\n', { plain = true }), script_path) ~= 0 then
        return nil, 'blender: could not write export script to ' .. script_path
    end

    return script_path, nil
end

---@param argv string[]
---@param script_path string Scratch exporter script to delete after the run
---@param output string Expected output file
---@return string? output
---@return string? err
local function run_export(argv, script_path, output)
    local result, spawn_err = versions.system_wait(
        argv,
        { text = true, timeout = EXPORT_TIMEOUT_MS, env = { BLENDER_EXPORT_OUTPUT = output } }
    )
    vim.fn.delete(script_path)

    if result == nil then
        return nil, spawn_err
    end

    if result.code ~= 0 then
        local detail = (result.stderr or ''):match('^([^\r\n]*)') or ''
        return nil, ('blender export failed (exit %d): %s'):format(result.code, detail)
    end

    local marker = 'DIVER_EXPORT_OK'

    if not ((result.stdout or ''):find(marker, 1, true) or (result.stderr or ''):find(marker, 1, true)) then
        return nil, 'blender: exporter script did not report success'
    end

    local valid, valid_err = M.validate_output(output)

    if not valid then
        return nil, valid_err
    end

    return output, nil
end

---Export one .blend to glTF (.glb) or FBX (.fbx).
---@param blend string .blend file path
---@param output string Destination path (extension must match kind)
---@param kind string 'glb' or 'fbx'
---@return string? output
---@return string? err
function M.export_blend(blend, output, kind)
    local version_ok, version_err = versions.check_version()

    if not version_ok then
        return nil, version_err
    end

    local bin, bin_err = versions.ensure_installed()

    if bin == nil then
        return nil, bin_err
    end

    if type(output) ~= 'string' or output == '' then
        return nil, 'blender: output must be a non-empty path'
    end

    local expected_ext = kind == 'glb' and '.glb' or '.fbx'

    if output:sub(-#expected_ext):lower() ~= expected_ext then
        return nil, ('blender: %s export requires a %s output path, got %s'):format(kind, expected_ext, output)
    end

    local script_path, script_err = write_export_script(kind)

    if script_path == nil then
        return nil, script_err
    end

    local argv, argv_err = M.build_argv(bin, blend, script_path)

    if argv == nil then
        vim.fn.delete(script_path)
        return nil, argv_err
    end

    return run_export(argv, script_path, output)
end

---Export a .blend to glTF binary (.glb).
---@param blend string .blend file path
---@param output string Destination .glb path
---@return string? path
---@return string? err
function M.export_glb(blend, output)
    return M.export_blend(blend, output, 'glb')
end

---Export a .blend to FBX (.fbx).
---@param blend string .blend file path
---@param output string Destination .fbx path
---@return string? path
---@return string? err
function M.export_fbx(blend, output)
    return M.export_blend(blend, output, 'fbx')
end

---@return integer timeout_ms Exporter script self-check timeout
function M.script_check_timeout_ms()
    return EXPORT_SCRIPT_TIMEOUT_MS
end

---@return BlenderExportKind[] kinds
function M.kinds()
    return { 'glb', 'fbx' }
end

return M
