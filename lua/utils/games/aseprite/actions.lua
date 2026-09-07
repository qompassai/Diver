-- #################################################################
-- /qompassai/Diver/lua/utils/games/aseprite/actions.lua
-- Qompass AI Aseprite Actions
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
local util = require('utils.games.aseprite.util')
local config = require('utils.games.aseprite.config')
local shared_util = require('utils.games.shared.util')
local output_factory = require('utils.games.shared.output')

local notify = vim.notify
local levels = vim.log.levels
local output = output_factory.new(config.output_filetype)

local M = {}

function M.open_in_editor()
  local bin = util.require_binary()
  if not bin then
    return
  end
  local sprite = vim.api.nvim_buf_get_name(0)
  local cmd = { bin }
  if util.is_sprite_file(sprite) then
    cmd[#cmd + 1] = sprite
  end
  vim.fn.jobstart(cmd, { detach = true })
  notify('Aseprite: editor launching', levels.INFO)
end

function M.new_sprite()
  local bin = util.require_binary()
  if not bin then
    return
  end
  vim.fn.jobstart({ bin }, { detach = true })
  notify('Aseprite: new empty sprite session launching', levels.INFO)
end

local function batch_export(sheet_flag, extra_args, label)
  local bin = util.require_binary()
  if not bin then
    return
  end
  local sprite = util.current_sprite_or_prompt()
  if not sprite then
    return
  end
  local out = shared_util.trim(
    vim.fn.input('Aseprite export path: ', vim.fn.fnamemodify(sprite, ':r') .. sheet_flag, 'file')
  )
  if out == '' then
    return
  end

  local cmd = { bin, '-b', sprite }
  vim.list_extend(cmd, extra_args(out))

  output.run_with_progress(
    'AsepriteExport',
    'Exporting ' .. label .. ' for ' .. vim.fs.basename(sprite),
    cmd,
    {
      show_output = true,
      success = 'Export finished: ' .. out,
      failure = 'Export failed.',
    }
  )
end

function M.export_sprite_sheet()
  batch_export('.png', function(out)
    local data = vim.fn.fnamemodify(out, ':r') .. '.json'
    return { '--sheet', out, '--data', data, '--format', 'json-array' }
  end, 'sprite sheet')
end

function M.export_png_sequence()
  batch_export('.png', function(out)
    return { '--save-as', out }
  end, 'PNG sequence')
end

function M.export_gif()
  batch_export('.gif', function(out)
    return { '--save-as', out }
  end, 'animated GIF')
end

function M.run_script()
  local bin = util.require_binary()
  if not bin then
    return
  end
  local script = shared_util.trim(vim.fn.input('Aseprite Lua script: ', '', 'file'))
  if script == '' then
    return
  end

  local cmd = { bin, '-b' }
  local sprite = vim.api.nvim_buf_get_name(0)
  if util.is_sprite_file(sprite) then
    cmd[#cmd + 1] = sprite
  end
  vim.list_extend(cmd, { '--script', script })

  output.run_with_progress(
    'AsepriteScript',
    'Running script ' .. vim.fs.basename(script),
    cmd,
    {
      show_output = true,
      success = 'Script finished.',
      failure = 'Script failed.',
    }
  )
end

function M.describe_environment()
  notify(
    table.concat({
      'Aseprite binary: ' .. (util.find_binary() or 'not found'),
      'Current buffer sprite: ' .. tostring(util.is_sprite_file(vim.api.nvim_buf_get_name(0))),
    }, '\n'),
    levels.INFO
  )
end

function M.get_actions()
  return {
    { id = 'open_in_editor', label = 'Open in Aseprite', group = 'Editor', run = M.open_in_editor },
    { id = 'new_sprite', label = 'New sprite', group = 'Editor', run = M.new_sprite },
    { id = 'export_sprite_sheet', label = 'Export sprite sheet + JSON', group = 'Export', run = M.export_sprite_sheet },
    { id = 'export_png_sequence', label = 'Export PNG sequence', group = 'Export', run = M.export_png_sequence },
    { id = 'export_gif', label = 'Export animated GIF', group = 'Export', run = M.export_gif },
    { id = 'run_script', label = 'Run Lua script (headless)', group = 'Scripting', run = M.run_script },
    { id = 'describe_environment', label = 'Describe environment', group = 'Scripting', run = M.describe_environment },
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
    notify('Unknown Aseprite action: ' .. id, levels.ERROR)
    return
  end
  M.run_action(action)
end

function M.show_menu()
  require('utils.games.shared.ui').select_root_menu(M.get_actions(), M.run_action, {
    group_order = config.group_order,
    prompt = 'Select Aseprite action:',
  })
end

return M
