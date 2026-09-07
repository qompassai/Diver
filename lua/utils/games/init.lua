-- #################################################################
-- /qompassai/Diver/lua/utils/games/init.lua
-- Qompass AI Games Native Tooling Init
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
-- Native game-development tooling for Aseprite, Godot, Redot, Unity,
-- and Unreal -- each engine's CLI/editor is driven directly through
-- vim.system/jobstart, with no external plugin dependency. Every
-- engine module exposes the same shape (config/util/actions/commands
-- with a show_menu()/run_action_by_id()), so this file only wires
-- setup() and a combined `:Games` picker across all five.
local function safe_require(module)
  local ok, result = pcall(require, module)
  if not ok then
    vim.notify('Failed to load ' .. module .. ': ' .. tostring(result), vim.log.levels.WARN)
    return nil
  end
  return result
end

local M = {}

M.aseprite = safe_require('utils.games.aseprite')
M.godot = safe_require('utils.games.godot')
M.redot = safe_require('utils.games.redot')
M.unity = safe_require('utils.games.unity')
M.unreal = safe_require('utils.games.unreal')

local engines = {
  { key = 'aseprite', label = 'Aseprite' },
  { key = 'godot', label = 'Godot' },
  { key = 'redot', label = 'Redot' },
  { key = 'unity', label = 'Unity' },
  { key = 'unreal', label = 'Unreal' },
}

function M.setup()
  for _, engine in ipairs(engines) do
    local mod = M[engine.key]
    if mod and mod.setup then
      mod.setup()
    end
  end

  vim.api.nvim_create_user_command('Games', function()
    M.show_menu()
  end, { desc = 'Open a combined Aseprite/Godot/Redot/Unity/Unreal action menu' })

  -- `:GamesDoctor` is a muscle-memory alias for `:checkhealth
  -- utils.games` -- Nvim's health framework already auto-discovers
  -- `lua/utils/games/health.lua` because it sits at this module's own
  -- path, so this command does nothing but call the standard entry
  -- point (the same relationship `:LspInfo`-style plugin commands
  -- have to their own `:checkhealth <name>` report).
  vim.api.nvim_create_user_command('GamesDoctor', function()
    vim.cmd('checkhealth utils.games')
  end, { desc = 'Report every engine\'s resolved binary/root (Aseprite/Godot/Redot/Unity/Unreal)' })
end

-- Combined picker across every loaded engine, each action prefixed
-- with its engine name so `:Games` works as a single entry point.
function M.show_menu()
  local combined = {}

  for _, engine in ipairs(engines) do
    local mod = M[engine.key]
    if mod and mod.actions and mod.actions.get_actions then
      for _, action in ipairs(mod.actions.get_actions()) do
        combined[#combined + 1] = {
          id = engine.key .. ':' .. action.id,
          label = action.label,
          group = engine.label,
          run = action.run,
        }
      end
    end
  end

  require('utils.games.shared.ui').select_root_menu(combined, function(action)
    action.run()
  end, {
    group_order = { 'Aseprite', 'Godot', 'Redot', 'Unity', 'Unreal' },
    prompt = 'Select a games action:',
  })
end

return M
