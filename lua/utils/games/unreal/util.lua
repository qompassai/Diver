-- #################################################################
-- /qompassai/Diver/lua/utils/games/unreal/util.lua
-- Qompass AI Unreal Util
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
local config = require('utils.games.unreal.config')
local shared_util = require('utils.games.shared.util')

local fs = vim.fs

local M = {}

local function uproject_matcher(name)
  return name:match('%.uproject$') ~= nil
end

function M.find_uproject(start_dir)
  local override = vim.env[config.project_env_name]
  if override and override ~= '' and vim.fn.filereadable(vim.fn.expand(override)) == 1 then
    return vim.fn.expand(override)
  end

  local dir = start_dir or vim.fn.getcwd()
  local found = fs.find(uproject_matcher, { upward = true, path = dir, type = 'file' })[1]
  return found
end

function M.require_uproject()
  local uproject = M.find_uproject()
  if not uproject then
    vim.notify('Unreal: no .uproject found upward from cwd.', vim.log.levels.ERROR)
  end
  return uproject
end

function M.project_root(uproject)
  uproject = uproject or M.find_uproject()
  if not uproject then
    return vim.fn.getcwd()
  end
  return fs.dirname(uproject)
end

function M.project_name(uproject)
  uproject = uproject or M.find_uproject()
  if not uproject then
    return nil
  end
  return fs.basename(uproject):gsub('%.uproject$', '')
end

function M.find_engine_root()
  local override = shared_util.env_first(config.engine_env_names)
  if override then
    local expanded = vim.fn.expand(override)
    if vim.fn.filereadable(config.editor_binary(expanded)) == 1 then
      return expanded
    end
    vim.notify('Unreal: configured engine root has no editor binary: ' .. expanded, vim.log.levels.WARN)
  end

  for _, candidate in ipairs(config.engine_root_candidates()) do
    if vim.fn.filereadable(config.editor_binary(candidate)) == 1 then
      return candidate
    end
  end

  return nil
end

function M.require_engine_root()
  local root = M.find_engine_root()
  if not root then
    vim.notify(
      table.concat({
        'Unreal Engine installation not found. Set one of:',
        table.concat(config.engine_env_names, ', '),
      }, ' '),
      vim.log.levels.ERROR
    )
  end
  return root
end

return M
