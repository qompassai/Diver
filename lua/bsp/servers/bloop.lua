-- #################################################################
-- /qompassai/Diver/lua/bsp/servers/bloop.lua
-- Qompass AI Bloop
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
--- Bloop compile server resolver for the native BSP client.
---
--- Plain-language version: Bloop is a standalone compile server. sbt,
--- Gradle, Maven, and Mill export their project model *to* Bloop, and Bloop
--- is what actually answers BSP compile requests. Look for a `.bloop/`
--- directory of exported project JSON files. (Maven has no native BSP
--- implementation at all — Bloop's `maven-bloop` plugin is the only
--- supported route for Maven projects.)
---
--- Upstream: https://github.com/scalacenter/bloop
---@module 'bsp.servers.bloop'

local util = require('bsp.servers.util')

local M = {}

local ROOT_MARKERS = {
    '.bloop',
    '.bsp',
}

---@param root string
---@return boolean
function M.is_bloop_project(root)
    if type(root) ~= 'string' or root == '' then
        return false
    end

    local stat = vim.uv.fs_stat(vim.fs.joinpath(root, '.bloop'))
    return stat ~= nil and stat.type == 'directory'
end

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
