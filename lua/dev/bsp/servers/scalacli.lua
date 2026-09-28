-- #################################################################
-- /qompassai/Diver/lua/bsp/servers/scalacli.lua
-- Qompass AI Scalacli
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
--- scala-cli resolver for the native BSP client.
---
--- Plain-language version: scala-cli is the friendly way to run Scala (and
--- Java) scripts and small projects. It acts as its own BSP server for ad
--- hoc `.sc`/`.scala` files, and as a BSP *client* toward Bloop for bigger
--- setups. Its connection card is regenerated on every server start.
---
--- Upstream: https://github.com/VirtusLab/scala-cli
---@module 'dev.bsp.servers.scalacli'

local util = require('dev.bsp.servers.util')

local M = {}

local ROOT_MARKERS = {
    'project.scala',
    '.bsp',
}

---@return string[]
function M.markers()
    return vim.deepcopy(ROOT_MARKERS)
end

---@param bufnr? integer
---@return string|nil
function M.root(bufnr)
    return util.root_from_markers(bufnr, ROOT_MARKERS)
end

---@param root string
---@param preferred_name? string
---@return QompassBspConnection|nil, string|nil
function M.connection(root, preferred_name)
    return util.find_connection(root, preferred_name)
end

---@param connection QompassBspConnection
---@return boolean, string|nil
function M.executable(connection)
    if type(connection) ~= 'table' or type(connection.argv) ~= 'table' then
        return false, 'The BSP connection is malformed'
    end

    return util.executable_from_argv(connection.argv)
end

return M
