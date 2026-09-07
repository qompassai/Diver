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

-- TODO (README): "palette/theme sync command".
--
-- WHY TWO SEPARATE STEPS (export, then sync) instead of one action:
-- exporting a palette is a pure, repeatable, read-only operation on
-- the sprite (safe to run anytime); copying a file into Aseprite's
-- own config directory mutates state OUTSIDE this project (closer to
-- `cp` into `/etc/` than into a build/ directory). Tiger Style favors
-- small, single-purpose functions over one action that quietly does
-- both -- if sync ever needs confirmation or a dry-run flag later,
-- only one of the two functions changes.
function M.export_palette()
  local bin = util.require_binary()
  if not bin then
    return
  end
  local sprite = util.current_sprite_or_prompt()
  if not sprite then
    return
  end
  local out = shared_util.trim(
    vim.fn.input('Aseprite palette export path: ', vim.fn.fnamemodify(sprite, ':r') .. '.gpl', 'file')
  )
  if out == '' then
    return
  end

  -- `--save-as *.gpl` makes Aseprite write the sprite's current
  -- palette in GIMP Palette format instead of image data -- the
  -- extension alone selects the export kind, same as `scp file.tar.gz`
  -- vs `file.txt` picking transfer mode by suffix, not by flag.
  output.run_with_progress(
    'AsepriteExportPalette',
    'Exporting palette for ' .. vim.fs.basename(sprite),
    { bin, '-b', sprite, '--save-as', out },
    {
      show_output = true,
      success = 'Palette exported: ' .. out,
      failure = 'Palette export failed.',
    }
  )
end

function M.sync_palette_to_user_config()
  local source = shared_util.trim(vim.fn.input('Palette (.gpl) to sync: ', '', 'file'))
  if source == '' then
    return
  end
  assert(source:sub(-4) == '.gpl', 'Aseprite: sync_palette_to_user_config expects a .gpl file, got: ' .. source)

  local dest_dir = util.user_palette_dir()
  vim.fn.mkdir(dest_dir, 'p')
  local dest = dest_dir .. '/' .. vim.fs.basename(source)

  local ok, err = pcall(vim.uv.fs_copyfile, vim.fn.expand(source), dest)
  if not ok then
    notify('Aseprite: failed to sync palette: ' .. tostring(err), levels.ERROR)
    return
  end
  notify('Aseprite: palette synced to ' .. dest .. ' (restart Aseprite, or reload via Edit > Palette > Load Palette).', levels.INFO)
end

-- TODO (README): "tileset export preset" -- the existing
-- `export_sprite_sheet` action always packs frames with Aseprite's
-- default layout; this preset exposes the `--sheet-type` choice the
-- CLI actually supports, the same way a `tar` wrapper might expose
-- `--format` instead of hardcoding one archive layout for every call.
function M.export_sheet_type_preset()
  vim.ui.select(config.sheet_types, {
    prompt = 'Sheet type for tileset/sprite-sheet export:',
  }, function(sheet_type)
    if sheet_type == nil then
      return
    end
    assert(vim.tbl_contains(config.sheet_types, sheet_type), 'Aseprite: unexpected sheet type: ' .. tostring(sheet_type))

    batch_export('.png', function(out)
      local data = vim.fn.fnamemodify(out, ':r') .. '.json'
      return { '--sheet', out, '--sheet-type', sheet_type, '--data', data, '--format', 'json-array' }
    end, 'tileset (' .. sheet_type .. ')')
  end)
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
    { id = 'export_sheet_type_preset', label = 'Export tileset (choose sheet type)', group = 'Export', run = M.export_sheet_type_preset },
    { id = 'export_palette', label = 'Export palette (.gpl)', group = 'Palette', run = M.export_palette },
    { id = 'sync_palette_to_user_config', label = 'Sync palette into Aseprite user config', group = 'Palette', run = M.sync_palette_to_user_config },
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
