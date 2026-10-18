-- /qompassai/Diver/lua/bsp/servers/swift.lua
-- Qompass AI Swift
--- Swift build server resolver for the native BSP client.
---
--- Plain-language version: there is no single official Swift build server
--- yet. This module targets wvteijlingen/swift-bsp, the most complete
--- community implementation today: it wraps `swift-build`, works with Xcode
--- projects, and feeds SourceKit-LSP. Apple is building toward a first-party
--- server (swiftlang/swift-tools-protocol); revisit the connection card shape
--- once that lands.
---
--- Caveat: swift-bsp is a small community project and moves slowly. Treat
--- failures here as "check upstream" rather than "diver is broken".
---
--- Upstream: https://github.com/wvteijlingen/swift-bsp
---@module 'dev.bsp.servers.swift'

local util = require('dev.bsp.servers.util')

local M = {}

local ROOT_MARKERS = {
    'Package.swift',
    '.bsp',
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
