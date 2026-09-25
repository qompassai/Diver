-- #################################################################
-- /qompassai/Diver/lua/bsp/bazel.lua
-- Qompass AI Bazel BSP (Hirschgarten)
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
--
-- Neovim 0.13+ companion for lua/bsp/init.lua.
-- Reads a BSP connection file written by JetBrains Hirschgarten
-- (typically .bsp/bazelbsp.json) and returns the same connection
-- shape the native client already uses: argv, bspVersion, languages.
-- This module never downloads binaries and never builds a shell string.

local api = vim.api
local fs = vim.fs
local uv = vim.uv

local M = {}

local ARGV_COUNT_MAX = 64
local ARGV_ITEM_LENGTH_MAX = 4096
local CONNECTION_SIZE_BYTES_MAX = 65536
local DIRECTORY_ENTRY_COUNT_MAX = 64
local ROOT_MARKER_COUNT_MAX = 8

local ROOT_MARKERS = {
    '.bsp',
    '.bazelbsp',
    'MODULE.bazel',
    'WORKSPACE.bazel',
    'WORKSPACE',
    'REPO.bazel',
}

local WORKSPACE_FILES = {
    'MODULE.bazel',
    'WORKSPACE.bazel',
    'WORKSPACE',
    'REPO.bazel',
}

-- Prefer Hirschgarten's connection name, then other Bazel BSP filenames.
local CONNECTION_FILES = {
    'bazelbsp.json',
    'bazel-bsp.json',
    'org.jetbrains.bsp.bazel.json',
}

---@class BspConnection
---@field name string
---@field version string|nil
---@field bspVersion string
---@field languages string[]
---@field argv string[]

---@class BspBazelConfig
---@field notify boolean|nil
---@field connection_name string|nil

local function is_integer(value)
    if type(value) ~= 'number' then
        return false
    end

    if value ~= value then
        return false
    end

    if value == math.huge or value == -math.huge then
        return false
    end

    return value % 1 == 0
end

local function notify(message, level)
    assert(type(message) == 'string')
    vim.notify('[BSP bazel] ' .. message, level or vim.log.levels.WARN)
end

---@param path string
---@return boolean
local function path_is_safe(path)
    if type(path) ~= 'string' then
        return false
    end

    if path == '' then
        return false
    end

    if path:find('%z') ~= nil then
        return false
    end

    return true
end

---@param path string
---@return boolean
local function file_exists(path)
    assert(path_is_safe(path))

    local stat = uv.fs_stat(path)

    return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function dir_exists(path)
    assert(path_is_safe(path))

    local stat = uv.fs_stat(path)

    return stat ~= nil and stat.type == 'directory'
end

---@param root string
---@param name string
---@return string
local function join_root(root, name)
    assert(path_is_safe(root))
    assert(type(name) == 'string')
    assert(name ~= '')
    assert(not name:find('[/\\]'))
    assert(name ~= '.')
    assert(name ~= '..')

    return fs.joinpath(root, name)
end

---@param bufnr integer
---@return boolean
local function buffer_is_usable(bufnr)
    assert(is_integer(bufnr))

    if bufnr < 0 then
        return false
    end

    return api.nvim_buf_is_valid(bufnr)
end

---@param root string
---@return boolean
function M.is_bazel_project(root)
    if not path_is_safe(root) then
        return false
    end

    if dir_exists(join_root(root, '.bazelbsp')) then
        return true
    end

    for index = 1, #WORKSPACE_FILES do
        local name = WORKSPACE_FILES[index]
        assert(type(name) == 'string')

        if file_exists(join_root(root, name)) then
            return true
        end
    end

    return false
end

---@param bufnr? integer
---@return string|nil
function M.root(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    if not buffer_is_usable(bufnr) then
        return nil
    end

    assert(#ROOT_MARKERS <= ROOT_MARKER_COUNT_MAX)

    local root = fs.root(bufnr, ROOT_MARKERS)

    if root == nil then
        return nil
    end

    if not M.is_bazel_project(root) then
        return nil
    end

    return root
end

---@param name string
---@return boolean
local function connection_name_is_safe(name)
    if type(name) ~= 'string' then
        return false
    end

    if name == '' then
        return false
    end

    if name:find('[/\\]') ~= nil then
        return false
    end

    if name == '.' or name == '..' then
        return false
    end

    if not name:find('%.json$') then
        return false
    end

    return true
end

---@param root string
---@param name string
---@return string
local function connection_path(root, name)
    assert(M.is_bazel_project(root) or dir_exists(join_root(root, '.bsp')))
    assert(connection_name_is_safe(name))

    return fs.joinpath(root, '.bsp', name)
end

---@param root string
---@return string[]
local function list_connection_candidates(root)
    assert(path_is_safe(root))

    local names = {}
    local seen = {}

    local function add_name(name)
        if not connection_name_is_safe(name) then
            return
        end

        if seen[name] then
            return
        end

        seen[name] = true
        names[#names + 1] = name
    end

    for index = 1, #CONNECTION_FILES do
        add_name(CONNECTION_FILES[index])
    end

    local bsp_dir = join_root(root, '.bsp')

    if not dir_exists(bsp_dir) then
        return names
    end

    local handle, glob_error = uv.fs_scandir(bsp_dir)

    if handle == nil then
        notify('could not scan .bsp: ' .. tostring(glob_error), vim.log.levels.ERROR)
        return names
    end

    local entry_count = 0

    while entry_count < DIRECTORY_ENTRY_COUNT_MAX do
        local name, kind = uv.fs_scandir_next(handle)

        if name == nil then
            break
        end

        entry_count = entry_count + 1

        if kind == 'file' then
            add_name(name)
        end
    end

    return names
end

---@param path string
---@return string|nil
---@return string|nil
local function read_bounded_file(path)
    assert(path_is_safe(path))

    local stat = uv.fs_stat(path)

    if stat == nil or stat.type ~= 'file' then
        return nil, 'connection file is missing: ' .. path
    end

    if not is_integer(stat.size) or stat.size < 0 then
        return nil, 'connection file size is invalid: ' .. path
    end

    if stat.size > CONNECTION_SIZE_BYTES_MAX then
        return nil, 'connection file exceeds size bound: ' .. path
    end

    local file, open_error = io.open(path, 'rb')

    if file == nil then
        return nil, 'failed to open connection file: ' .. tostring(open_error)
    end

    local data, read_error = file:read(stat.size)
    file:close()

    if data == nil then
        return nil, 'failed to read connection file: ' .. tostring(read_error)
    end

    if #data > CONNECTION_SIZE_BYTES_MAX then
        return nil, 'connection file exceeded size bound after read'
    end

    return data, nil
end

---@param argv table
---@return string[]|nil
---@return string|nil
local function validate_argv(argv)
    if type(argv) ~= 'table' then
        return nil, 'connection argv must be an array'
    end

    local count = #argv

    if count < 1 then
        return nil, 'connection argv must not be empty'
    end

    if count > ARGV_COUNT_MAX then
        return nil, 'connection argv exceeds argument bound'
    end

    local normalized = {}

    for index = 1, count do
        local item = argv[index]

        if type(item) ~= 'string' then
            return nil, 'connection argv items must be strings'
        end

        if item == '' then
            return nil, 'connection argv items must not be empty'
        end

        if item:find('%z') ~= nil then
            return nil, 'connection argv contains NUL'
        end

        if #item > ARGV_ITEM_LENGTH_MAX then
            return nil, 'connection argv item exceeds length bound'
        end

        normalized[index] = item
    end

    assert(#normalized == count)

    return normalized, nil
end

---@param languages table
---@return string[]
local function validate_languages(languages)
    if type(languages) ~= 'table' then
        return {}
    end

    local count = #languages

    if count > ARGV_COUNT_MAX then
        count = ARGV_COUNT_MAX
    end

    local normalized = {}

    for index = 1, count do
        local language = languages[index]

        if type(language) == 'string' and language ~= '' then
            normalized[#normalized + 1] = language
        end
    end

    return normalized
end

---@param decoded table
---@return BspConnection|nil
---@return string|nil
local function validate_connection(decoded)
    if type(decoded) ~= 'table' then
        return nil, 'connection JSON must be an object'
    end

    if type(decoded.bspVersion) ~= 'string' or decoded.bspVersion == '' then
        return nil, 'connection bspVersion must be a non-empty string'
    end

    local argv, argv_error = validate_argv(decoded.argv)

    if argv == nil then
        return nil, argv_error
    end

    local name = decoded.name

    if type(name) ~= 'string' or name == '' then
        name = 'bazelbsp'
    end

    local version = decoded.version

    if type(version) ~= 'string' then
        version = nil
    end

    ---@type BspConnection
    local connection = {
        name = name,
        version = version,
        bspVersion = decoded.bspVersion,
        languages = validate_languages(decoded.languages),
        argv = argv,
    }

    assert(type(connection.argv) == 'table')
    assert(#connection.argv >= 1)

    return connection, nil
end

---@param root string
---@param preferred_name? string
---@return BspConnection|nil
---@return string|nil
function M.connection(root, preferred_name)
    if not path_is_safe(root) then
        return nil, 'root path is invalid'
    end

    if not M.is_bazel_project(root) then
        return nil, 'not a Bazel workspace: ' .. root
    end

    local names = list_connection_candidates(root)

    if preferred_name ~= nil then
        if not connection_name_is_safe(preferred_name) then
            return nil, 'connection_name must be a json filename'
        end

        table.insert(names, 1, preferred_name)
    end

    ---@type string|nil
    local last_error = 'no Bazel BSP connection file under .bsp/'

    for index = 1, #names do
        local name = names[index]
        local path = connection_path(root, name)

        if file_exists(path) then
            local raw, read_error = read_bounded_file(path)

            if raw == nil then
                last_error = read_error
            else
                local ok, decoded = pcall(vim.json.decode, raw)

                if not ok then
                    last_error = 'invalid JSON in ' .. path
                else
                    local connection, connection_error = validate_connection(decoded)

                    if connection ~= nil then
                        return connection, nil
                    end

                    last_error = connection_error
                end
            end
        end
    end

    return nil, last_error
end

---@param connection BspConnection
---@return string[]
function M.argv(connection)
    assert(type(connection) == 'table')
    assert(type(connection.argv) == 'table')
    assert(#connection.argv >= 1)

    return connection.argv
end

---@param bufnr? integer
---@return string|nil
---@return BspConnection|nil
---@return string|nil
function M.detect(bufnr)
    local root = M.root(bufnr)

    if root == nil then
        return nil, nil, 'no Bazel workspace root'
    end

    local connection, connection_error = M.connection(root)

    if connection == nil then
        return root, nil, connection_error
    end

    return root, connection, nil
end

---@param config? BspBazelConfig
---@return BspConnection|nil
---@return string|nil
function M.setup(config)
    if config == nil then
        config = {}
    end

    if type(config) ~= 'table' then
        return nil, 'config must be a table'
    end

    local should_notify = true

    if config.notify ~= nil then
        if type(config.notify) ~= 'boolean' then
            return nil, 'config.notify must be a boolean'
        end

        should_notify = config.notify
    end

    local root = M.root()

    if root == nil then
        if should_notify then
            notify('no Bazel workspace from current buffer')
        end

        return nil, 'no Bazel workspace from current buffer'
    end

    local connection, connection_error = M.connection(root, config.connection_name)

    if connection == nil then
        if should_notify then
            notify(connection_error .. '; install Hirschgarten Bazel BSP so .bsp/bazelbsp.json exists')
        end

        return nil, connection_error
    end

    return connection, nil
end

return M
