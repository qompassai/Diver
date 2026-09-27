-- #################################################################
-- /qompassai/lua/dev/android/init.lua
-- Qompass AI Init
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
M.actions = require('dev.android.actions')
M.commands = require('dev.android.commands')
M.config = require('dev.android.config')
M.devices = require('dev.android.devices')
M.gradle = require('dev.android.gradle')
M.output = require('dev.android.output')
M.recent = require('dev.android.recent')
M.ui = require('dev.android.ui')
M.util = require('dev.android.util')
function M.setup()
    M.commands.setup()
end
M.show_menu = M.actions.show_menu
M.run_action_by_id = M.actions.run_action_by_id
return M
