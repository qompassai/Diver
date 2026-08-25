-- #################################################################
-- /qompassai/lua/utils/dev/android/recent.lua
-- Qompass AI Recent
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

local config = require('utils.dev.android.config')

function M.load_recent_action_ids()
  local file = io.open(config.recent_path, 'r')
  if not file then
    return {}
  end

  local content = file:read('*a')
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= 'table' then
    return {}
  end

  local recent = {}
  for i = 1, #decoded do
    local id = decoded[i]
    if type(id) == 'string' and id ~= '' then
      recent[#recent + 1] = id
    end
  end

  return recent
end

function M.record_recent_action(id)
  local recent = M.load_recent_action_ids()
  local next_recent = { id }

  for i = 1, #recent do
    local existing = recent[i]
    if existing ~= id and #next_recent < config.max_recent then
      next_recent[#next_recent + 1] = existing
    end
  end

  vim.fn.mkdir(vim.fn.fnamemodify(config.recent_path, ':h'), 'p')

  local file = io.open(config.recent_path, 'w')
  if not file then
    return
  end

  file:write(vim.json.encode(next_recent))
  file:close()
end

return M
