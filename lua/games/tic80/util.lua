-- #################################################################
-- /qompassai/Diver/lua/games/tic80/util.lua
-- Qompass AI TIC-80 Util
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
--- Binary discovery and headless `--cli --cmd` plumbing for TIC-80.
---@module 'games.tic80.util'

local config = require('games.tic80.config')
local shared_util = require('games.shared.util')

local M = {}

---@return string? Binary path when executable, nil otherwise.
function M.find_binary()
    local override = shared_util.env_first(config.env_names)
    if override ~= nil and override ~= '' then
        local resolved = shared_util.first_executable({ override })
        if resolved ~= nil then
            return resolved
        end
        vim.notify('TIC-80: configured binary is not executable: ' .. override, vim.log.levels.WARN)
    end
    local configured = shared_util.first_executable({ config.current.bin })
    if configured ~= nil then
        return configured
    end
    return shared_util.first_executable(config.binaries)
end

---@return string? Binary path, notifying on ERROR when missing.
function M.require_binary()
    local bin = M.find_binary()
    if bin == nil then
        vim.notify(
            'TIC-80 executable not found. Set NVIM_TIC80_BIN or add tic80 to $PATH.',
            vim.log.levels.ERROR
        )
    end
    return bin
end

---@return string? Trimmed `tic80 --version` output, nil when unavailable.
function M.version()
    local bin = M.find_binary()
    if bin == nil then
        return nil
    end
    local completed = vim.system({ bin, '--version' }, { text = true }):wait()
    if completed.code ~= 0 then
        return nil
    end
    return shared_util.trim(completed.stdout or '')
end

---@param workdir string Storage directory passed as `--fs`.
---@param chain string Console commands joined with ' & ' for `--cmd`.
---@return string[]? argv, or nil when no binary is available.
function M.console_argv(workdir, chain)
    local bin = M.require_binary()
    if bin == nil then
        return nil
    end
    return { bin, '--cli', '--skip', '--fs', workdir, '--cmd', chain }
end

---@param path string Absolute, normalized file path.
---@return boolean
function M.is_under_watched_dir(path)
    for _, dir in ipairs(config.current.dirs) do
        if path == dir or vim.startswith(path, dir .. '/') then
            return true
        end
    end
    return false
end

return M
