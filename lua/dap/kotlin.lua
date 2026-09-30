-- #################################################################
-- ~/.config/nvim/lua/dap/kotlin.lua
-- Qompass AI Diver Native Kotlin Debug Adapter Configuration
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################

local api = vim.api
local env = vim.env
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local ADAPTER_NAME = 'kotlin-jvm'

local DEFAULT_DEBUG_PORT = 5005

--- Bound for the Gradle classes build; a full build can take minutes, but it
--- must not block the editor forever.
local GRADLE_BUILD_TIMEOUT_MS = 300000

local NOTIFY_PREFIX = '[kotlin-debug] '

---@type string[]
local ROOT_MARKERS = {
    'build.gradle.kts',
    'build.gradle',
    'settings.gradle.kts',
    'settings.gradle',
    'gradlew',
    'pom.xml',
    '.git',
}

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(NOTIFY_PREFIX .. message, level or levels.INFO)
end

---@param path string
---@return boolean
local function exists(path)
    return uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function is_directory(path)
    local stat = uv.fs_stat(path)

    return stat ~= nil and stat.type == 'directory'
end

---@param command string
---@return boolean
local function executable(command)
    return fn.executable(command) == 1
end

---@param path string
---@return string
local function normalize(path)
    if path == '' then
        return ''
    end

    return fs.normalize(fn.fnamemodify(path, ':p'))
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    return normalize(api.nvim_buf_get_name(bufnr))
end

---@param bufnr? integer
---@return string
local function root(bufnr)
    local current = filename(bufnr)

    if current == '' then
        return normalize(fn.getcwd())
    end

    local detected = fs.root(current, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
        return normalize(detected)
    end

    return normalize(fs.dirname(current) or fn.getcwd())
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return vim.SystemCompleted?, string?
local function system(command, opts)
    opts = vim.tbl_extend('force', {
        text = true,
    }, opts or {})

    -- `timeout_ms` is our own option: it bounds `:wait()`, it is not a
    -- `vim.system` option.
    local timeout_ms = opts.timeout_ms
    opts.timeout_ms = nil

    local ok, result = pcall(function()
        return vim.system(command, opts):wait(timeout_ms)
    end)

    if not ok then
        return nil, tostring(result)
    end

    return result, nil
end

---@param result vim.SystemCompleted
---@param context string
---@return boolean
local function check_result(result, context)
    if result.code == 0 then
        return true
    end

    local detail = result.stderr

    if type(detail) ~= 'string' or detail == '' then
        detail = result.stdout
    end

    detail = type(detail) == 'string' and vim.trim(detail) or ''

    if detail == '' then
        detail = ('exit status %d'):format(result.code)
    end

    notify(('%s failed: %s'):format(context, detail), levels.ERROR)

    return false
end

---@return string?
local function java()
    local configured = env.JAVA

    if type(configured) == 'string' and configured ~= '' and executable(configured) then
        return configured
    end

    if executable('java') then
        return 'java'
    end

    return nil
end

---@return string?
local function java_home()
    local configured = env.JAVA_HOME

    if type(configured) == 'string' and configured ~= '' and is_directory(configured) then
        return normalize(configured)
    end

    local java_executable = java()

    if java_executable == nil then
        return nil
    end

    local resolved = fn.exepath(java_executable)

    if resolved == '' then
        return nil
    end

    local real = uv.fs_realpath(resolved)

    if real == nil then
        return nil
    end

    local bin = fs.dirname(real)

    if bin == nil then
        return nil
    end

    return normalize(fs.dirname(bin) or '')
end

---@return string?
local function kotlin_debug_adapter()
    local configured = env.KOTLIN_DEBUG_ADAPTER

    if type(configured) == 'string' and configured ~= '' and executable(configured) then
        return configured
    end

    local candidates = {
        'kotlin-debug-adapter',
        'kotlin-debug',
    }

    for index = 1, #candidates do
        if executable(candidates[index]) then
            return candidates[index]
        end
    end

    return nil
end

---@return string?
local function gradle()
    if executable('gradle') then
        return 'gradle'
    end

    return nil
end

---@param workspace string
---@return string?
local function gradle_command(workspace)
    local candidates = {
        fs.joinpath(workspace, 'gradlew'),
    }

    for index = 1, #candidates do
        if exists(candidates[index]) then
            return candidates[index]
        end
    end

    return gradle()
end

---@param workspace string
---@return string?
local function gradle_build(workspace)
    local command = gradle_command(workspace)

    if command == nil then
        notify('Gradle is not available', levels.ERROR)

        return nil
    end

    local result, spawn_err = system({
        command,
        'classes',
    }, {
        cwd = workspace,

        timeout_ms = GRADLE_BUILD_TIMEOUT_MS,
    })

    if result == nil then
        notify(
            ('Gradle classes build failed: %s'):format(spawn_err or 'timed out'),
            levels.ERROR
        )

        return nil
    end

    if not check_result(result, 'Gradle classes build') then
        return nil
    end

    return workspace
end

---@param workspace string
---@return string[]
local function classpath_candidates(workspace)
    return {
        fs.joinpath(workspace, 'build', 'classes', 'java', 'main'),

        fs.joinpath(workspace, 'build', 'classes', 'kotlin', 'main'),

        fs.joinpath(workspace, 'build', 'resources', 'main'),

        fs.joinpath(workspace, 'out', 'production'),
    }
end

---@param workspace string
---@return string[]
local function project_classpath(workspace)
    ---@type string[]
    local classpath = {}

    local candidates = classpath_candidates(workspace)

    for index = 1, #candidates do
        if is_directory(candidates[index]) then
            classpath[#classpath + 1] = normalize(candidates[index])
        end
    end

    return classpath
end

---@return string
local function path_separator()
    return package.config:sub(1, 1) == '\\' and ';' or ':'
end

---@param values string[]
---@return string
local function join_classpath(values)
    return table.concat(values, path_separator())
end

---@return string?
local function input_main_class()
    local value = fn.input('Kotlin main class: ')

    if value == '' then
        return nil
    end

    return value
end

---@return string[]
local function program_arguments()
    local input = fn.input('Program arguments: ')

    if input == '' then
        return {}
    end

    ---@type string[]
    local args = {}

    for value in input:gmatch('%S+') do
        args[#args + 1] = value
    end

    return args
end

---@return integer?
local function input_pid()
    local value = fn.input('JVM PID: ')

    if value == '' then
        return nil
    end

    local pid = tonumber(value)

    if pid == nil then
        return nil
    end

    pid = math.floor(pid)

    if pid <= 0 then
        return nil
    end

    return pid
end

---@return integer
local function debug_port()
    local value = tonumber(env.KOTLIN_DEBUG_PORT)

    if value ~= nil and value >= 1 and value <= 65535 then
        return math.floor(value)
    end

    return DEFAULT_DEBUG_PORT
end

---@param value string
---@return boolean
local function valid_ipv4(value)
    local octets = {}

    for octet in value:gmatch('[^%.]+') do
        octets[#octets + 1] = octet
    end

    if #octets ~= 4 then
        return false
    end

    for _, octet in ipairs(octets) do
        if not octet:match('^%d+$') then
            return false
        end

        local number = tonumber(octet)

        if number == nil or number > 255 then
            return false
        end
    end

    return true
end

---@param value string
---@return boolean
local function valid_ipv6(value)
    if not value:match('^[%x:]+$') then
        return false
    end

    local _, colons = value:gsub(':', '')

    return colons >= 2
end

---@param value string
---@return boolean
local function valid_hostname(value)
    if value == '' or #value > 253 then
        return false
    end

    if not value:match('^[%a%d]([%a%d%.%-]*[%a%d])?$') then
        return false
    end

    for label in value:gmatch('[^%.]+') do
        if #label > 63 or label:match('^%-') or label:match('%-$') then
            return false
        end
    end

    return true
end

---@param value string
---@return boolean
local function valid_remote_host(value)
    return valid_ipv4(value) or valid_ipv6(value) or valid_hostname(value)
end

---@return string?
local function debug_host()
    local value = env.KOTLIN_DEBUG_HOST

    if type(value) ~= 'string' or value == '' then
        return '127.0.0.1'
    end

    if not valid_remote_host(value) then
        notify(('invalid KOTLIN_DEBUG_HOST: %s'):format(value), levels.ERROR)

        return nil
    end

    return value
end

---@param workspace string
---@return table<string, string>
local function environment(workspace)
    local result = {
        -- PWD is set explicitly (alongside cwd in the launch config) because
        -- JVM tooling and wrapper scripts often read the PWD environment
        -- variable instead of the process working directory.
        PWD = workspace,
    }

    local home = java_home()

    if home ~= nil then
        result.JAVA_HOME = home
    end

    return result
end

---@return string?
local function launch_program()
    local workspace = root()

    if gradle_build(workspace) == nil then
        return nil
    end

    return input_main_class()
end

---@return string
local function workspace()
    return root()
end

---@return string
local function launch_classpath()
    local workspace_root = root()

    return join_classpath(project_classpath(workspace_root))
end

---@return string[]
local function java_exec_args()
    return {
        '-ea',
    }
end

M.adapter = {
    -- Declarative placeholder: M.setup() resolves the real path and records
    -- a deferred warning when the adapter is absent; no PATH probing happens
    -- at require time, and nothing is notified until a session starts.
    command = 'kotlin-debug-adapter',

    name = ADAPTER_NAME,

    type = 'executable',
}

M.configurations = {
    kotlin = {
        {
            args = program_arguments,

            classPaths = {
                launch_classpath,
            },

            cwd = workspace,

            env = function()
                local current = root()

                return environment(current)
            end,

            javaExec = java,

            javaExecArgs = java_exec_args,

            mainClass = launch_program,

            name = 'Kotlin: Gradle build + launch',

            request = 'launch',

            type = ADAPTER_NAME,
        },

        {
            args = program_arguments,

            classPaths = {
                launch_classpath,
            },

            cwd = workspace,

            env = function()
                local current = root()

                return environment(current)
            end,

            javaExec = java,

            mainClass = input_main_class,

            name = 'Kotlin: Launch main class',

            request = 'launch',

            type = ADAPTER_NAME,
        },

        {
            hostName = debug_host,

            name = 'Kotlin: Attach JDWP',

            port = debug_port,

            request = 'attach',

            type = ADAPTER_NAME,
        },

        {
            name = 'Kotlin: Attach JVM PID',

            processId = input_pid,

            request = 'attach',

            type = ADAPTER_NAME,
        },
    },
}

M.filetypes = {
    'kotlin',
}

M.commands = {
    KotlinDebugBuild = {
        callback = function()
            local workspace_root = root()

            if gradle_build(workspace_root) ~= nil then
                notify('Gradle classes build completed')
            end
        end,

        desc = 'Build Kotlin classes with Gradle',
    },

    KotlinDebugClasspath = {
        callback = function()
            local workspace_root = root()

            local value = join_classpath(project_classpath(workspace_root))

            if value == '' then
                notify('No Kotlin classpath directories found', levels.WARN)

                return
            end

            notify(value)
        end,

        desc = 'Show Kotlin debug classpath',
    },

    KotlinDebugJavaHome = {
        callback = function()
            local value = java_home()

            if value == nil then
                notify('JAVA_HOME could not be resolved', levels.WARN)

                return
            end

            notify(value)
        end,

        desc = 'Show resolved Java home',
    },
}

---@param _opts? table
function M.setup(_opts)
    local adapter = kotlin_debug_adapter()

    if adapter == nil then
        -- Defer the nag: surfaced by Session.spawn when a session starts.
        -- The java runtime is validated per session by the build steps.
        M.adapter.missing_message = NOTIFY_PREFIX .. 'kotlin-debug-adapter is not available'
    else
        M.adapter.command = adapter
        M.adapter.missing_message = nil
    end
end

return M
