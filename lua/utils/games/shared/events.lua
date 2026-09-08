-- #################################################################
-- /qompassai/Diver/lua/utils/games/shared/events.lua
-- Qompass AI Games Shared Task-Completion Events
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
local api = vim.api

local M = {}

M.COMPLETED_PATTERN = 'GamesTaskCompleted'
M.FAILED_PATTERN = 'GamesTaskFailed'

---@param engine string  e.g. "godot", "unity"
---@param action string  e.g. "export_release", "build_project"
---@param ok boolean
---@param detail table?  extra fields merged into the autocmd `data` table
function M.fire_task_result(engine, action, ok, detail)
  assert(type(engine) == 'string' and engine ~= '', 'games.shared.events.fire_task_result: engine is required')
  assert(type(action) == 'string' and action ~= '', 'games.shared.events.fire_task_result: action is required')
  assert(type(ok) == 'boolean', 'games.shared.events.fire_task_result: ok must be boolean')

  ---@type table<string, any>
  local data = { engine = engine, action = action, ok = ok }
  if type(detail) == 'table' then
    for key, value in pairs(detail) do
      data[key] = value
    end
  end

  api.nvim_exec_autocmds('User', {
    pattern = ok and M.COMPLETED_PATTERN or M.FAILED_PATTERN,
    data = data,
  })
end

return M
