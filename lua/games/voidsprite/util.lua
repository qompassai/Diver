-- #################################################################
-- /qompassai/Diver/lua/games/voidsprite/util.lua
-- Qompass AI Voidsprite Util
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
--- Binary discovery for voidsprite, mirroring the games.aseprite.util shape.
---@module 'games.voidsprite.util'

local config = require('games.voidsprite.config')
local shared_util = require('games.shared.util')

local M = {}

---@type string?
local configured_bin = nil

---@param opts games.voidsprite.Options?
function M.configure(opts)
    configured_bin = config.resolve(opts)
end

---@return string? Binary path when executable, nil otherwise.
function M.find_binary()
    local override = shared_util.env_first(config.env_names)
    if override ~= nil and override ~= '' then
        local resolved = shared_util.first_executable({ override })
        if resolved ~= nil then
            return resolved
        end
        vim.notify(
            'Voidsprite: configured binary is not executable: ' .. override,
            vim.log.levels.WARN
        )
    end
    local candidates = {}
    local seen = {}
    local function add(name)
        if name ~= nil and name ~= '' and not seen[name] then
            seen[name] = true
            candidates[#candidates + 1] = name
        end
    end
    add(configured_bin)
    for _, name in ipairs(config.binaries) do
        add(name)
    end
    return shared_util.first_executable(candidates)
end

---@return string? Binary path, notifying on ERROR when missing.
function M.require_binary()
    local bin = M.find_binary()
    if bin == nil then
        vim.notify(
            'Voidsprite executable not found. Set NVIM_VOIDSPRITE_BIN or add voidsprite to $PATH.',
            vim.log.levels.ERROR
        )
    end
    return bin
end

---@param path string?
---@return boolean
function M.is_sprite_file(path)
    if path == nil or path == '' then
        return false
    end
    for _, ext in ipairs(config.sprite_extensions) do
        if path:sub(-#ext) == ext then
            return true
        end
    end
    return false
end

---@return string? Current buffer sprite path, else a prompted path, else nil.
function M.current_sprite_or_prompt()
    local current = vim.api.nvim_buf_get_name(0)
    if M.is_sprite_file(current) then
        return current
    end
    local input = shared_util.trim(vim.fn.input('Voidsprite sprite file: ', '', 'file'))
    if input == '' then
        return nil
    end
    return vim.fn.expand(input)
end

return M
