-- /qompassai/Diver/lua/bsp/servers/pants.lua
-- Qompass AI Pants
--- Pants build server resolver for the native BSP client.
---
--- Plain-language version: Pants is a monorepo build tool (Python, Java,
--- Scala, Go, Shell). Its BSP support is an experimental first-party goal:
--- `pants experimental-bsp` writes the connection card. It requires a
--- repo-level `bsp-groups.toml` naming target groups before a connection
--- file will even exist — this module fails informatively when that file is
--- absent instead of guessing.
---
--- Upstream: https://github.com/pantsbuild/pants
---@module 'dev.bsp.servers.pants'

local util = require('dev.bsp.servers.util')

local M = {}

local ROOT_MARKERS = {
    'pants.toml',
    'bsp-groups.toml',
}

---@param root string
---@param preferred_name? string
---@return QompassBspConnection|nil, string|nil
function M.connection(root, preferred_name)
    local ok, groups_error = M.has_bsp_groups(root)
    if not ok then
        return nil, groups_error
    end

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
---@return boolean, string|nil
function M.has_bsp_groups(root)
    if type(root) ~= 'string' or root == '' then
        return false, 'Invalid root'
    end

    local stat = vim.uv.fs_stat(vim.fs.joinpath(root, 'bsp-groups.toml'))
    if not stat or stat.type ~= 'file' then
        return false, 'Pants BSP needs a bsp-groups.toml at the repo root (see pants experimental-bsp docs)'
    end

    return true, nil
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
