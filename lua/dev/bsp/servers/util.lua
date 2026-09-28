-- #################################################################
-- /qompassai/Diver/lua/bsp/servers/util.lua
-- Qompass AI Util
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
--- Shared helpers for `bsp.servers.*` connection resolvers.
--- Plain-language version: every build server leaves a small JSON card under
--- `<project>/.bsp/` saying "here is how to start me". These helpers find the
--- project root, read those cards safely (bounded size and count, JSON
--- validated, no shell strings built), and check the server binary exists.
---@module 'dev.bsp.servers.util'

local M = {}

local CONNECTION_SIZE_BYTES_MAX = 65536
local CONNECTION_FILE_COUNT_MAX = 64
local ARGV_COUNT_MAX = 64
local ARGV_ITEM_LENGTH_MAX = 4096

---@param values unknown
---@return boolean
local function is_string_list(values)
    if type(values) ~= 'table' or #values == 0 or #values > ARGV_COUNT_MAX then
        return false
    end

    for _, value in ipairs(values) do
        if type(value) ~= 'string' or value == '' or #value > ARGV_ITEM_LENGTH_MAX then
            return false
        end
    end

    return true
end

---@param path string
---@return QompassBspConnection|nil, string|nil
function M.read_connection_file(path)
    if type(path) ~= 'string' or path == '' then
        return nil, 'Connection path must be a non-empty string'
    end

    local stat = vim.uv.fs_stat(path)
    if not stat or stat.type ~= 'file' then
        return nil, 'Not a file: ' .. path
    end
    if stat.size > CONNECTION_SIZE_BYTES_MAX then
        return nil, 'Connection file is too large: ' .. path
    end

    local ok_read, lines = pcall(vim.fn.readfile, path)
    if not ok_read or type(lines) ~= 'table' then
        return nil, 'Cannot read ' .. path
    end

    local ok_decode, value = pcall(vim.json.decode, table.concat(lines, '\n'))
    if not ok_decode or type(value) ~= 'table' then
        return nil, 'Invalid BSP JSON in ' .. path
    end

    if not is_string_list(value.argv) then
        return nil, 'Connection has no usable argv in ' .. path
    end

    ---@type QompassBspConnection
    local connection = {
        argv = value.argv,
        bspVersion = value.bspVersion,
        languages = value.languages,
        name = value.name,
        path = path,
        version = value.version,
    }

    return connection, nil
end

---@param root string Project root containing a `.bsp` directory.
---@return QompassBspConnection[] connections
---@return string[] errors
function M.list_connections(root)
    local directory = vim.fs.joinpath(root, '.bsp')
    local stat = vim.uv.fs_stat(directory)
    if not stat or stat.type ~= 'directory' then
        return {}, { 'No .bsp directory exists at ' .. root }
    end

    local paths = vim.fs.find(function(name)
        return name:sub(-5) == '.json'
    end, {
        limit = CONNECTION_FILE_COUNT_MAX,
        path = directory,
        type = 'file',
    })
    table.sort(paths)

    local connections = {}
    local errors = {}
    for _, path in ipairs(paths) do
        local connection, connection_error = M.read_connection_file(path)
        if connection then
            connections[#connections + 1] = connection
        elseif connection_error then
            errors[#errors + 1] = connection_error
        end
    end

    return connections, errors
end

---@param root string Project root containing a `.bsp` directory.
---@param preferred_name? string
---@return QompassBspConnection|nil, string|nil
function M.find_connection(root, preferred_name)
    local directory = vim.fs.joinpath(root, '.bsp')
    local connections, errors = M.list_connections(root)

    if #connections == 0 then
        local detail = #errors > 0 and ': ' .. table.concat(errors, '; ') or ''
        return nil, 'No valid BSP connection file was found in ' .. directory .. detail
    end

    if preferred_name and preferred_name ~= '' then
        for _, connection in ipairs(connections) do
            if connection.name == preferred_name then
                return connection, nil
            end
        end

        return nil, string.format('BSP server %q was not found in %s', preferred_name, directory)
    end

    return connections[1], nil
end

---@param bufnr? integer
---@param markers string[]
---@return string|nil
function M.root_from_markers(bufnr, markers)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local root = vim.fs.root(bufnr, markers)
    return root and vim.fs.normalize(root) or nil
end

---@param argv string[]
---@return boolean, string|nil
function M.executable_from_argv(argv)
    local command = type(argv) == 'table' and argv[1] or nil
    if not command or command == '' then
        return false, 'The BSP connection has an empty command'
    end
    if vim.fn.executable(command) ~= 1 then
        return false, 'BSP server is not executable: ' .. command
    end

    return true, nil
end

return M
