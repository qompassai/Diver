-- #################################################################
-- /qompassai/diver/lua/dev/init.lua
-- Qompass AI Dev Utils Init
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
local android = require('dev.android')
local apps = require('dev.apps')
local sf = require('dev.sf')
-- dev/vulkan.lua (leaf utilities) shadows dev/vulkan/init.lua (the suite)
-- in the require search order, so name the suite explicitly.
local vulkan = require('dev.vulkan.init')
function M.setup()
    require('dev.git').setup()
    require('dev.jj').setup()
    require('dev.bootdev').setup()
    require('dev.bsp')
    require('dev.scip')
    android.setup()
    apps.setup()
    sf.setup()
    vulkan.setup()
end

return M
