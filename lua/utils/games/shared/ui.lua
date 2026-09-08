-- #################################################################
-- /qompassai/Diver/lua/utils/games/shared/ui.lua
-- Qompass AI Games Shared UI
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
local M = {}

function M.select_root_menu(actions, run_action, opts)
  opts = opts or {}
  local group_order = opts.group_order or {}
  local order_index = {}
  for i, name in ipairs(group_order) do
    order_index[name] = i
  end

  local sorted = vim.deepcopy(actions)
  table.sort(sorted, function(a, b)
    local ga = order_index[a.group] or math.huge
    local gb = order_index[b.group] or math.huge
    if ga ~= gb then
      return ga < gb
    end
    return a.label < b.label
  end)

  vim.ui.select(sorted, {
    prompt = opts.prompt or 'Select action:',
    format_item = function(action)
      if action.group then
        return string.format('[%s] %s', action.group, action.label)
      end
      return action.label
    end,
  }, function(choice)
    if choice then
      run_action(choice)
    end
  end)
end

return M
