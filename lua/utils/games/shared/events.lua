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
--
-- WHY THIS FILE EXISTS (and why it is NOT built on `CmdAtom`):
--
--   Nvim 0.13 added a `CmdAtom` autocommand event (:h CmdAtom) that
--   fires after each atomic *editor* action -- a motion, a mapping,
--   an operator, an Ex command, a whole Insert session -- so plugins
--   can hook into "the user just did A Thing" for repeat (`.`)
--   purposes. It is scoped to interactive editing, not to background
--   jobs. Firing it ourselves when a build finishes would be like
--   reusing SIGWINCH to announce "the backup job finished": the
--   *shape* looks similar (both are "a notification fired"), but the
--   semantics are wrong and anything else listening for the real
--   thing gets confused. We do not use CmdAtom here.
--
--   What we DO use is the long-standing, purpose-built mechanism for
--   this: a custom `User` autocommand (:h User), the same pattern
--   plugins have used since long before 0.13 (e.g. `User
--   FugitiveChanged`). Firing `User GamesTaskCompleted` /
--   `User GamesTaskFailed` after every tracked action is the
--   equivalent of a systemd unit emitting a journal entry other
--   units can `WantedBy=`/watch for -- any other part of your config
--   (or a future plugin) can `nvim_create_autocmd('User', { pattern
--   = 'GamesTask*', ... })` without this module knowing it exists.
--   That decoupling is the whole point of an event bus vs. a direct
--   function call.
local api = vim.api

local M = {}

M.COMPLETED_PATTERN = 'GamesTaskCompleted'
M.FAILED_PATTERN = 'GamesTaskFailed'

-- Precondition: `engine` and `action` are non-empty strings identifying
-- which engine/action produced this result -- callers must not fire a
-- blank event, since a listener keyed on `data.engine` would silently
-- no-op forever on bad input instead of failing loudly at the source.
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
