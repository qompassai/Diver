-- /qompassai/Diver/lua/bsp/servers/bloop.lua
-- Qompass AI Bloop
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
---@module 'dev.bsp.servers.bloop'

local util = require('dev.bsp.servers.util')

local M = {}

local ROOT_MARKERS = {
    '.bloop',
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

return M
