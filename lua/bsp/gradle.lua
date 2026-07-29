-- #################################################################
-- ~/.config/nvim/lua/bsp/gradle.lua
-- Qompass AI Gradle BSP
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
--[[
mkdir -p "$HOME/.local/share"

git clone \
    --depth 1 \
    --branch develop \
    https://github.com/microsoft/build-server-for-gradle.git \
    "$HOME/.local/share/build-server-for-gradle"

cd "$HOME/.local/share/build-server-for-gradle"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export PATH="$JAVA_HOME/bin:$PATH"

./gradlew clean build

test -f \
    "$HOME/.local/share/build-server-for-gradle/server/build/libs/server.jar"

test -f \
    "$HOME/.local/share/build-server-for-gradle/server/build/libs/plugins/init.gradle"

find \
    "$HOME/.local/share/build-server-for-gradle/server/build/libs/plugins" \
    -maxdepth 1 \
    -type f \
    -name 'plugin-*.jar'

find \
    "$HOME/.local/share/build-server-for-gradle/server/build/libs/runtime" \
    -maxdepth 1 \
    -type f \
    -name '*.jar'

--]]
local api = vim.api
local fn = vim.fn
local uv = vim.uv

local M = {}

---@class QompassBspConnection
---@field argv string[]
---@field bspVersion string
---@field languages string[]
---@field name string
---@field path string
---@field version string

---@class QompassGradleBspConfig
---@field bsp_version string
---@field disable_telemetry boolean
---@field java_command string
---@field languages string[]
---@field server_dir string
---@field server_name string
---@field server_version string

---@class QompassGradleBspConfigOpts
---@field bsp_version? string
---@field disable_telemetry? boolean
---@field java_command? string
---@field languages? string[]
---@field server_dir? string
---@field server_name? string
---@field server_version? string

local defaults = {
        bsp_version = '2.1.0',
        disable_telemetry = true,
        java_command = 'java',
        languages = {
                'groovy',
                'java',
                'kotlin',
                'scala',
        },
        server_dir = '~/.local/share/build-server-for-gradle',
        server_name = 'gradle-bsp',
        server_version = '0.4.0',
}

---@type QompassGradleBspConfig
M.config = vim.deepcopy(defaults)

local root_markers = {
        '.bsp',
        '.git',
        'gradle.properties',
        'gradlew',
        'gradlew.bat',
        'settings.gradle',
        'settings.gradle.kts',
        'build.gradle',
        'build.gradle.kts',
}

local gradle_filenames = {
        ['build.gradle'] = true,
        ['build.gradle.kts'] = true,
        ['gradle.properties'] = true,
        ['settings.gradle'] = true,
        ['settings.gradle.kts'] = true,
}

local gradle_filetypes = {
        groovy = true,
        java = true,
        kotlin = true,
        scala = true,
}

---@param path string
---@return string
local function normalize(path)
        return vim.fs.normalize(fn.expand(path))
end

---@param path string
---@return boolean
local function is_file(path)
        local stat = uv.fs_stat(path)
        return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function is_directory(path)
        local stat = uv.fs_stat(path)
        return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return string|nil
local function canonical(path)
        path = normalize(path)
        return uv.fs_realpath(path) or path
end

---@param path string
---@return boolean
local function executable_file(path)
        return is_file(path) and fn.executable(path) == 1
end

---@param command string
---@return string|nil
local function executable_path(command)
        command = fn.expand(command)

        if command:find('/', 1, true) then
                local path = normalize(command)
                return executable_file(path) and path or nil
        end

        local path = fn.exepath(command)
        if path == '' then
                return nil
        end

        path = normalize(path)
        return executable_file(path) and path or nil
end

---@param directory string
---@return string[]
local function directory_files(directory)
        if not is_directory(directory) then
                return {}
        end

        local handle = uv.fs_scandir(directory)
        if not handle then
                return {}
        end

        ---@type string[]
        local files = {}

        while true do
                local name, entry_type = uv.fs_scandir_next(handle)
                if not name then
                        break
                end

                if entry_type == 'file' then
                        files[#files + 1] = normalize(directory .. '/' .. name)
                end
        end

        table.sort(files)
        return files
end

---@param directory string
---@param pattern string
---@return string[]
local function matching_files(directory, pattern)
        local matches = {}

        for _, path in ipairs(directory_files(directory)) do
                if vim.fs.basename(path):match(pattern) then
                        matches[#matches + 1] = path
                end
        end

        return matches
end

---@param bufnr integer
---@return string|nil
local function buffer_path(bufnr)
        if not api.nvim_buf_is_valid(bufnr) then
                return nil
        end

        local name = api.nvim_buf_get_name(bufnr)
        if name == '' then
                return nil
        end

        return normalize(name)
end

---@param start string
---@return string|nil
local function find_root(start)
        local stat = uv.fs_stat(start)
        if stat and stat.type == 'file' then
                start = vim.fs.dirname(start)
        end

        local matches = vim.fs.find(root_markers, {
                path = start,
                upward = true,
                type = function(path)
                        local marker_stat = uv.fs_stat(path)
                        return marker_stat ~= nil
                end,
        })

        if #matches == 0 then
                return nil
        end

        for _, marker in ipairs(matches) do
                local candidate = vim.fs.dirname(marker)

                if
                        is_file(candidate .. '/settings.gradle')
                        or is_file(candidate .. '/settings.gradle.kts')
                        or is_file(candidate .. '/build.gradle')
                        or is_file(candidate .. '/build.gradle.kts')
                        or is_file(candidate .. '/gradlew')
                then
                        return canonical(candidate)
                end
        end

        return nil
end

---@param bufnr_or_path? integer|string
---@return string|nil
function M.root(bufnr_or_path)
        local start

        if type(bufnr_or_path) == 'number' then
                start = buffer_path(math.floor(bufnr_or_path))
        elseif type(bufnr_or_path) == 'string' and bufnr_or_path ~= '' then
                start = normalize(bufnr_or_path)
        else
                start = buffer_path(api.nvim_get_current_buf())
        end

        if not start then
                start = uv.cwd()
        end

        if not start or start == '' then
                return nil
        end

        return find_root(normalize(start))
end

---@return string
local function server_root()
        return normalize(M.config.server_dir)
end

---@return string
local function server_jar()
        return normalize(server_root() .. '/server/build/libs/server.jar')
end

---@return string
local function runtime_directory()
        return normalize(server_root() .. '/server/build/libs/runtime')
end

---@return string
local function plugin_directory()
        return normalize(server_root() .. '/server/build/libs/plugins')
end

---@return string|nil, string|nil
local function validate_java()
        local java = executable_path(M.config.java_command)
        if not java then
                return nil, string.format(
                        'Java executable was not found: %s',
                        M.config.java_command
                )
        end

        return java, nil
end

---@return boolean, string|nil
local function validate_server()
        local root = server_root()
        if not is_directory(root) then
                return false, string.format(
                        'Gradle BSP repository was not found: %s',
                        root
                )
        end

        local jar = server_jar()
        if not is_file(jar) then
                return false, string.format(
                        'Gradle BSP server JAR was not found: %s\n'
                                .. 'Build the server with: ./gradlew build',
                        jar
                )
        end

        local runtime = runtime_directory()
        if not is_directory(runtime) then
                return false, string.format(
                        'Gradle BSP runtime directory was not found: %s',
                        runtime
                )
        end

        local runtime_jars = matching_files(runtime, '%.jar$')
        if #runtime_jars == 0 then
                return false, string.format(
                        'Gradle BSP runtime directory contains no JAR files: %s',
                        runtime
                )
        end

        local plugins = plugin_directory()
        if not is_directory(plugins) then
                return false, string.format(
                        'Gradle BSP plugin directory was not found: %s',
                        plugins
                )
        end

        local plugin_jars = matching_files(plugins, '^plugin%-.+%.jar$')
        if #plugin_jars == 0 then
                return false, string.format(
                        'Gradle BSP plugin JAR was not found in: %s',
                        plugins
                )
        end

        local init_script = normalize(plugins .. '/init.gradle')
        if not is_file(init_script) then
                return false, string.format(
                        'Gradle BSP init script was not found: %s',
                        init_script
                )
        end

        return true, nil
end

---@return string
local function classpath()
        local separator = package.config:sub(1, 1) == '\\' and ';' or ':'

        return table.concat({
                server_jar(),
                runtime_directory() .. '/*',
        }, separator)
end

---@param root string
---@param requested_name? string
---@return QompassBspConnection|nil, string|nil
function M.connection(root, requested_name)
        root = canonical(root)

        if not root or not is_directory(root) then
                return nil, 'Invalid Gradle project root'
        end

        local detected_root = M.root(root)
        if not detected_root then
                return nil, 'The selected directory is not a Gradle project: ' .. root
        end

        local configured_name = M.config.server_name

        if
                requested_name
                and requested_name ~= ''
                and requested_name ~= configured_name
                and requested_name ~= 'build-server-for-gradle'
                and requested_name ~= 'gradle'
        then
                return nil, string.format(
                        'Requested BSP server %q does not match Gradle BSP server %q',
                        requested_name,
                        configured_name
                )
        end

        local java, java_error = validate_java()
        if not java then
                return nil, java_error
        end

        local valid, validation_error = validate_server()
        if not valid then
                return nil, validation_error
        end

        local argv = {
                java,
        }

        if M.config.disable_telemetry then
                argv[#argv + 1] = '-DdisableServerTelemetry=true'
        end

        argv[#argv + 1] = '-Dplugin.dir=' .. plugin_directory()
        argv[#argv + 1] = '-cp'
        argv[#argv + 1] = classpath()
        argv[#argv + 1] = 'com.microsoft.java.bs.core.Launcher'

        ---@type QompassBspConnection
        local connection = {
                argv = argv,
                bspVersion = M.config.bsp_version,
                languages = vim.deepcopy(M.config.languages),
                name = configured_name,
                path = server_jar(),
                version = M.config.server_version,
        }

        return connection, nil
end

---@param connection QompassBspConnection
---@return string|nil, string|nil
function M.executable(connection)
        if type(connection) ~= 'table' then
                return nil, 'Invalid Gradle BSP connection'
        end

        if type(connection.argv) ~= 'table' or #connection.argv == 0 then
                return nil, 'Gradle BSP connection has no argv command'
        end

        if type(connection.argv[1]) ~= 'string' or connection.argv[1] == '' then
                return nil, 'Gradle BSP connection has no executable'
        end

        local executable = executable_path(connection.argv[1])
        if not executable then
                return nil, 'Gradle BSP Java executable is unavailable: ' .. connection.argv[1]
        end

        local valid, validation_error = validate_server()
        if not valid then
                return nil, validation_error
        end

        connection.argv[1] = executable
        return executable, nil
end

---@param bufnr? integer
---@return boolean
function M.matches(bufnr)
        bufnr = bufnr or api.nvim_get_current_buf()

        if not api.nvim_buf_is_valid(bufnr) then
                return false
        end

        local path = buffer_path(bufnr)
        if not path then
                return false
        end

        if gradle_filenames[vim.fs.basename(path)] then
                return M.root(bufnr) ~= nil
        end

        local filetype = vim.bo[bufnr].filetype
        return gradle_filetypes[filetype] == true and M.root(bufnr) ~= nil
end

---@param opts? QompassGradleBspConfigOpts
---@return table
function M.setup(opts)
        M.config = vim.tbl_deep_extend(
                'force',
                vim.deepcopy(defaults),
                opts or {}
        )

        M.config.server_dir = normalize(M.config.server_dir)

        return M
end

return M