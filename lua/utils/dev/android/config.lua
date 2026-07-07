-- #################################################################
-- /qompassai/lua/utils/dev/android/config.lua
-- Qompass AI Config
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
M.output_filetype = 'android-output'
M.recent_path = vim.fn.stdpath('data') .. '/android-nvim/recent.json'
M.max_recent = 3
M.search_ns = vim.api.nvim_create_namespace('android-nvim-search')
M.stderr_ns = vim.api.nvim_create_namespace('android-nvim-stderr')
M.group_order = {
  'Build & deploy',
  'Emulator',
  'Android Studio',
  'Device',
  'Project',
}

return M
