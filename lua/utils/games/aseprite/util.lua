-- #################################################################
-- /qompassai/Diver/lua/utils/games/aseprite/util.lua
-- Qompass AI Aseprite Util
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
local config = require('utils.games.aseprite.config')
local shared_util = require('utils.games.shared.util')

local M = {}

function M.find_binary()
  local override = shared_util.env_first(config.env_names)
  if override then
    local resolved = shared_util.first_executable({ override })
    if resolved then
      return resolved
    end
    vim.notify('Aseprite: configured binary is not executable: ' .. override, vim.log.levels.WARN)
  end
  return shared_util.first_executable(config.binaries)
end

function M.require_binary()
  local bin = M.find_binary()
  if not bin then
    vim.notify(
      'Aseprite executable not found. Set NVIM_ASEPRITE_BIN or add aseprite to $PATH.',
      vim.log.levels.ERROR
    )
  end
  return bin
end

function M.is_sprite_file(path)
  if not path or path == '' then
    return false
  end
  for _, ext in ipairs(config.sprite_extensions) do
    if path:sub(-#ext) == ext then
      return true
    end
  end
  return false
end

-- Resolves Aseprite's own per-OS user palette directory (see
-- config.user_palette_dir_by_os for why this matters). Returns the
-- path unconditionally -- callers that need it to exist should
-- `vim.fn.mkdir(path, 'p')` themselves right before writing, the same
-- way you'd `mkdir -p` a destination just before an `scp`, not ahead
-- of time on spec.
function M.user_palette_dir()
  if shared_util.is_windows() then
    return config.user_palette_dir_by_os.windows
  elseif shared_util.is_mac() then
    return config.user_palette_dir_by_os.mac
  end
  return config.user_palette_dir_by_os.linux
end

-- Returns the current buffer's file if it looks like an Aseprite
-- sprite, otherwise prompts for one.
function M.current_sprite_or_prompt()
  local current = vim.api.nvim_buf_get_name(0)
  if M.is_sprite_file(current) then
    return current
  end

  local input = shared_util.trim(vim.fn.input('Aseprite sprite file: ', '', 'file'))
  if input == '' then
    return nil
  end
  return vim.fn.expand(input)
end

return M
