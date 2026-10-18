-- /qompassai/Diver/lua/bsp/servers/sbt.lua
-- Qompass AI Sbt
--- sbt build server resolver for the native BSP client.
---
--- Plain-language version: sbt is the classic Scala build tool, and since
--- version 1.4.0 it speaks BSP itself — no separate server to install.
--- Running `sbt bspConfig` (or launching sbt with `-bsp`) writes the
--- `.bsp/sbt.json` connection card this module reads.
---
--- Upstream: https://github.com/sbt/sbt
---@module 'dev.bsp.servers.sbt'

local util = require('dev.bsp.servers.util')

local M = {}

local ROOT_MARKERS = {
    'build.sbt',
    'project/build.properties',
}

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

---@return string[]
function M.markers()
    return vim.deepcopy(ROOT_MARKERS)
end

---@param bufnr? integer
---@return string|nil
function M.root(bufnr)
    return util.root_from_markers(bufnr, ROOT_MARKERS)
end

return M
