-- #################################################################
-- /qompassai/Diver/lua/utils/games/health.lua
-- Qompass AI Games Doctor (:checkhealth utils.games / :GamesDoctor)
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
local async_util = require('utils.games.shared.async_util')
local shared_util = require('utils.games.shared.util')
local M = {}
local EXPECTED_PROBE_COUNT = 5

---@param bin string?
---@return string?
local function fetch_version(bin)
  if bin == nil then
    return nil
  end
  local ok, completed = vim.async.pawait(async_util.system_task({
    bin,
    '--version',
  }))
  if not ok or completed == nil or completed.code ~= 0 then
    return nil
  end
  return shared_util.trim(completed.stdout or '')
end

---@class GamesDoctorRow
---@field name string
---@field ok boolean
---@field warn boolean
---@field lines string[]

---@return GamesDoctorRow
local function probe_aseprite()
  local ok, aseprite = pcall(require, 'utils.games.aseprite')
  if not ok then
    return {
      name = 'Aseprite',
      ok = false,
      warn = false,
      lines = {
        'module failed to load: ' .. tostring(aseprite),
      },
    }
  end
  local bin = aseprite.util.find_binary()
  return {
    name = 'Aseprite',
    ok = bin ~= nil,
    warn = false,
    lines = {
      'binary: ' .. (bin or 'not found (set NVIM_ASEPRITE_BIN or add aseprite to $PATH)'),
    },
  }
end

---@param module_name 'godot'|'redot'
---@return async fun(): GamesDoctorRow
local function godot_family_probe(module_name)
  return function()
    local ok, engine = pcall(require, 'utils.games.' .. module_name)
    if not ok then
      return {
        name = module_name,
        ok = false,
        warn = false,
        lines = {
          'module failed to load: ' .. tostring(engine),
        },
      }
    end

    local bin = engine.util.find_binary()
    local root = engine.util.find_root()
    local version = fetch_version(bin)

    ---@type string[]
    local lines = {
      'binary: ' .. (bin or 'not found'),
      'project root: ' .. (root or 'not found (no project.godot upward from cwd)'),
    }
    if bin ~= nil then
      lines[#lines + 1] = 'reported version: ' .. (version or 'unavailable (--version did not respond as expected)')
    end

    return {
      name = engine.name or module_name,
      ok = bin ~= nil,
      warn = bin ~= nil and root == nil,
      lines = lines,
    }
  end
end

---@return GamesDoctorRow
local function probe_unity()
  local ok, unity = pcall(require, 'utils.games.unity')
  if not ok then
    return {
      name = 'Unity',
      ok = false,
      warn = false,
      lines = {
        'module failed to load: ' .. tostring(unity),
      },
    }
  end
  local root = unity.util.find_root()
  local version = unity.util.project_editor_version(root)
  local editor = unity.util.find_editor(root)
  return {
    name = 'Unity',
    ok = editor ~= nil,
    warn = editor ~= nil and root == nil,
    lines = {
      'project root: ' .. (root or 'not found (no ProjectSettings/ProjectVersion.txt upward from cwd)'),
      'recorded editor version: ' .. (version or 'unknown'),
      'resolved editor binary: ' .. (editor or 'not found'),
    },
  }
end

---@return GamesDoctorRow
local function probe_unreal()
  local ok, unreal = pcall(require, 'utils.games.unreal')
  if not ok then
    return {
      name = 'Unreal',
      ok = false,
      warn = false,
      lines = {
        'module failed to load: ' .. tostring(unreal),
      },
    }
  end
  local uproject = unreal.util.find_uproject()
  local engine_root = unreal.util.find_engine_root()
  local unreal_config = require('utils.games.unreal.config')
  local editor = engine_root ~= nil and unreal_config.editor_binary(engine_root) or nil
  return {
    name = 'Unreal',
    ok = engine_root ~= nil,
    warn = engine_root ~= nil and uproject == nil,
    lines = {
      '.uproject: ' .. (uproject or 'not found (set NVIM_UNREAL_PROJECT or cd into a project)'),
      'engine root: ' .. (engine_root or 'not found (set NVIM_UNREAL_ENGINE_ROOT)'),
      'editor binary: ' .. (editor or 'not found'),
      'native C++ debugging: see :h DebugUnreal* (lua/dap/unreal.lua) -- not duplicated here',
    },
  }
end

---@return GamesDoctorRow[]
local function collect_rows()
  ---@type (async fun(): GamesDoctorRow)[]
  local jobs = {
    function()
      return probe_aseprite()
    end,
    godot_family_probe('godot'),
    godot_family_probe('redot'),
    function()
      return probe_unity()
    end,
    function()
      return probe_unreal()
    end,
  }
  assert(
    #jobs == EXPECTED_PROBE_COUNT,
    ('games.health.collect_rows: expected %d probes, built %d'):format(EXPECTED_PROBE_COUNT, #jobs)
  )

  local completed = async_util.run_concurrent(jobs, 8000)

  ---@type GamesDoctorRow[]
  local rows = {}
  for _, entry in ipairs(completed) do
    local ok, value, job_index = entry[1], entry[2], entry[3]
    if ok and type(value) == 'table' then
      rows[job_index] = value
    else
      rows[job_index] = {
        name = ('probe #%d'):format(job_index),
        ok = false,
        warn = false,
        lines = {
          tostring(value),
        },
      }
    end
  end

  for index = 1, EXPECTED_PROBE_COUNT do
    if rows[index] == nil then
      rows[index] = {
        name = ('probe #%d'):format(index),
        ok = false,
        warn = false,
        lines = { 'timed out' },
      }
    end
  end

  return rows
end

function M.check()
  local health = vim.health
  health.start('utils.games: engine discovery')

  if vim.fn.has('nvim-0.13') == 0 then
    health.warn(
      'Neovim < 0.13 detected -- vim.async is unavailable; GamesDoctor probes ran sequentially as a fallback would be required.'
    )
  end

  local rows = collect_rows()
  assert(#rows == EXPECTED_PROBE_COUNT, 'games.health.check: collect_rows must always return five rows')

  for _, row in ipairs(rows) do
    health.start(row.name)
    for _, line in ipairs(row.lines) do
      health.info(line)
    end
    if row.ok and not row.warn then
      health.ok(row.name .. ' is fully resolved.')
    elseif row.ok and row.warn then
      health.warn(row.name .. ' binary/engine found, but no project was detected from the current directory.')
    else
      health.error(row.name .. ' could not resolve a usable binary/engine root.')
    end
  end
end

return M
