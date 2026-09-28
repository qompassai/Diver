-- #################################################################
-- ~/.config/nvim/lua/dap/dart.lua
-- Qompass AI Diver Native Dart/Flutter Debug Adapter Configuration
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
---@source https://dart.dev/tools/dart-tool
---@source https://github.com/dart-code/dart-code/blob/HEAD/AGENTS.md
---@source https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/debug_adapters/README.md

--- Dart and Flutter debugging through the SDKs' own DAP servers.
---
--- Plain-language version: the Dart SDK ships a debug adapter you start
--- with `dart debug_adapter`, and the Flutter SDK ships one you start with
--- `flutter debug_adapter`. Both speak the Debug Adapter Protocol over
--- their standard input/output, so no VS Code extension or separate
--- download is needed. This module finds the `dart` and `flutter` programs,
--- starts the matching adapter, and hands out ready-made debug recipes:
--- launch a Dart script, debug Dart tests, attach to a running VM service,
--- and the same three for Flutter apps.
---
--- Verified against upstream (2026-09-28):
--- * `dart debug_adapter` and `dart debug_adapter --test` are documented in
---   the Dart SDK's own DAP docs (pkg/dds/tool/dap in the SDK source tree).
---   The standard adapter runs scripts with `dart`; `--test` runs them with
---   `dart test` and emits `dart.testNotification` events. Launch takes
---   `program`/`args`/`toolArgs`/`cwd`; attach takes exactly one of
---   `vmServiceUri` / `vmServiceInfoFile`. The command is intentionally
---   absent from the public dart.dev command table (dart 3.13 docs list no
---   `debug_adapter`), but it ships in the SDK and Dart-Code confirms the
---   adapters "live in the Dart and Flutter SDKs".
--- * Flutter apps use the debug adapter in the `flutter` tool
---   (flutter/flutter packages/flutter_tools debug_adapters README):
---   `flutter debug_adapter [--test]` runs apps via `flutter run` (or
---   `flutter test`); attach takes at most one of `vmServiceUri` /
---   `vmServiceInfoFile`, and with neither Flutter discovers the service
---   from the device. The README's prose says `flutter debug-adapter`
---   (hyphen) while its own bullet list and three independent working
---   setups use `flutter debug_adapter` (underscore); this module uses the
---   underscore spelling, matching `dart debug_adapter`.
---@module 'dap.dart'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'dart'
local FLUTTER_SOURCE = 'flutter'
local PROBE_TIMEOUT_MS = 5000

---@type string[]
local ROOT_MARKERS = {
    'pubspec.yaml',
    '.git',
}

---@type string[]
local FILETYPES = {
    'dart',
}

---@type string[]
local DART_WELL_KNOWN_PATHS = {
    '/usr/lib/dart/bin/dart',
    '/opt/dart-sdk/bin/dart',
    '/usr/local/bin/dart',
}

---@type string[]
local FLUTTER_WELL_KNOWN_PATHS = {
    '/opt/flutter/bin/flutter',
    '/usr/local/bin/flutter',
    '~/flutter/bin/flutter',
    '~/sdk/flutter/bin/flutter',
}

--
-- `dart debug_adapter` / `flutter debug_adapter` start a DAP server on
-- stdio. `--test` switches the adapter to run scripts via the test runner.
-- Verified against the SDK DAP docs; see the module docstring.
--
---@type string[]
local DEBUG_ADAPTER_ARGS = {
    'debug_adapter',
}

local TEST_ARG = '--test'

---@class DartState
---@field dart_path string?
---@field flutter_path string?
local state = {
    dart_path = nil,
    flutter_path = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@param path string
---@return boolean
local function executable(path)
    return nonempty_string(path) and fn.executable(path) == 1
end

---@param path string
---@return string
local function normalize(path)
    if path == '' then
        return ''
    end

    return fs.normalize(fn.fnamemodify(path, ':p'))
end

---@param value string?
---@return string
local function trim(value)
    return type(value) == 'string' and vim.trim(value) or ''
end

---@param bufnr? integer
---@return string
local function buffer_filename(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    if not api.nvim_buf_is_valid(bufnr) then
        return ''
    end

    local name = api.nvim_buf_get_name(bufnr)

    if name == '' then
        return ''
    end

    return normalize(name)
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    local filename = buffer_filename(bufnr)

    if filename ~= '' then
        local detected = fs.root(filename, ROOT_MARKERS)

        if type(detected) == 'string' and detected ~= '' then
            return fs.normalize(detected)
        end

        local parent = fs.dirname(filename)

        if type(parent) == 'string' and parent ~= '' then
            return fs.normalize(parent)
        end
    end

    return fs.normalize(fn.getcwd())
end

---@param command string[]
---@return vim.SystemCompleted?
local function system(command)
    local ok, result = pcall(function()
        return vim.system(command, {
            text = true,
        }):wait(PROBE_TIMEOUT_MS)
    end)

    if not ok then
        return nil
    end

    return result
end

---@param result vim.SystemCompleted?
---@return string
local function first_line(result)
    if result == nil then
        return ''
    end

    for _, stream in ipairs({ result.stdout, result.stderr }) do
        if type(stream) == 'string' then
            local line = trim(stream:match('[^\r\n]*') or '')

            if line ~= '' then
                return line
            end
        end
    end

    return ''
end

---@param env_name string
---@param global_name string
---@param binary string
---@param well_known string[]
---@return string?
local function find_binary(env_name, global_name, binary, well_known)
    local candidates = {}

    local configured = vim.env[env_name]

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g[global_name]

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath(binary)

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    for _, path in ipairs(well_known) do
        candidates[#candidates + 1] = normalize(fn.expand(path))
    end

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            return fs.normalize(candidate)
        end
    end

    return nil
end

---@return string?
local function find_dart()
    if state.dart_path ~= nil then
        return state.dart_path
    end

    state.dart_path = find_binary('NVIM_DART_PATH', 'dart_path', 'dart', DART_WELL_KNOWN_PATHS)

    return state.dart_path
end

---@return string?
local function find_flutter()
    if state.flutter_path ~= nil then
        return state.flutter_path
    end

    state.flutter_path = find_binary('NVIM_FLUTTER_PATH', 'flutter_path', 'flutter', FLUTTER_WELL_KNOWN_PATHS)

    return state.flutter_path
end

---@param flutter boolean
---@param test boolean
---@return string
local function adapter_name(flutter, test)
    if flutter then
        return test and 'flutter-test' or FLUTTER_SOURCE
    end

    return test and 'dart-test' or SOURCE
end

---@param test boolean
---@return string[]
local function adapter_args(test)
    local args = { DEBUG_ADAPTER_ARGS[1] }

    if test then
        args[#args + 1] = TEST_ARG
    end

    return args
end

---@param opts? {flutter?: boolean, test?: boolean}
---@return table?
function M.resolve_adapter(opts)
    opts = opts or {}

    local flutter = opts.flutter == true
    local test = opts.test == true
    local path = flutter and find_flutter() or find_dart()

    if path == nil then
        return nil
    end

    return {
        name = adapter_name(flutter, test),
        type = 'executable',
        command = path,
        args = adapter_args(test),
    }
end

---@param flutter boolean
---@return string
local function tool_command(flutter)
    local path = flutter and find_flutter() or find_dart()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when the SDK is missing.
    -- setup() warns before any session is attempted.
    --
    return flutter and 'flutter' or 'dart'
end

---@param path string
---@return string
local function tool_version_line(path)
    return first_line(system({ path, '--version' }))
end

---@param default string
---@return string?
local function prompt_program(default)
    local input = fn.input('Program: ', default, 'file')

    if input == '' then
        return nil
    end

    local path = normalize(fn.expand(input))
    local stat = uv.fs_stat(path)

    if stat == nil or stat.type ~= 'file' then
        notify(('not a file: %s'):format(path), levels.ERROR)

        return nil
    end

    return path
end

---@return string[]
local function prompt_args()
    local input = fn.input('Program arguments: ')

    if input == '' then
        return {}
    end

    --
    -- shellsplit handles quoted arguments but never runs a shell.
    --
    return fn.shellsplit(input)
end

---@return string?
local function prompt_vm_service_uri()
    local input = fn.input('VM service URI: ')

    if input == '' then
        return nil
    end

    return trim(input)
end

---@param args unknown
---@return boolean
local function valid_args(args)
    if type(args) ~= 'table' then
        return false
    end

    for _, value in ipairs(args) do
        if type(value) ~= 'string' then
            return false
        end
    end

    return true
end

---@param opts table
---@return table?, string?
function M.build_launch(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_launch requires opts.program'
    end

    if opts.args ~= nil and not valid_args(opts.args) then
        return nil, 'build_launch requires opts.args to be a list of strings'
    end

    if opts.cwd ~= nil and not nonempty_string(opts.cwd) then
        return nil, 'build_launch requires opts.cwd to be a non-empty string'
    end

    local flutter = opts.flutter == true
    local test = opts.test == true
    local tool = flutter and 'Flutter' or 'Dart'
    local kind = test and 'Debug Tests' or 'Launch'

    return {
        name = opts.name or (tool .. ': ' .. kind),
        type = adapter_name(flutter, test),
        request = 'launch',
        program = opts.program,
        args = opts.args or {},
        cwd = opts.cwd or project_root(),
    }
end

---@param opts table
---@return table?, string?
function M.build_attach(opts)
    opts = opts or {}

    if opts.vm_service_uri ~= nil and not nonempty_string(opts.vm_service_uri) then
        return nil, 'build_attach requires opts.vm_service_uri to be a non-empty string'
    end

    if opts.vm_service_info_file ~= nil and not nonempty_string(opts.vm_service_info_file) then
        return nil, 'build_attach requires opts.vm_service_info_file to be a non-empty string'
    end

    local has_uri = nonempty_string(opts.vm_service_uri)
    local has_file = nonempty_string(opts.vm_service_info_file)
    local flutter = opts.flutter == true

    if has_uri and has_file then
        return nil, 'build_attach accepts only one of vm_service_uri / vm_service_info_file'
    end

    if not flutter and not has_uri and not has_file then
        --
        -- Pure Dart attach requires exactly one source; Flutter may
        -- discover the service from the device when neither is given.
        --
        return nil, 'build_attach requires opts.vm_service_uri or opts.vm_service_info_file'
    end

    local tool = flutter and 'Flutter' or 'Dart'

    return {
        name = opts.name or (tool .. ': Attach'),
        type = adapter_name(flutter, false),
        request = 'attach',
        vmServiceUri = has_uri and opts.vm_service_uri or nil,
        vmServiceInfoFile = has_file and opts.vm_service_info_file or nil,
    }
end

---@return table[]
local function dart_configurations()
    return {
        {
            name = 'Dart: Launch File',
            type = SOURCE,
            request = 'launch',
            program = function()
                local filename = buffer_filename()

                if filename:match('%.dart$') ~= nil then
                    return filename
                end

                return prompt_program(project_root() .. '/')
            end,
            args = {},
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Dart: Launch with Arguments',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = prompt_args,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Dart: Debug Tests',
            type = 'dart-test',
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = {},
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Dart: Attach to VM Service',
            type = SOURCE,
            request = 'attach',
            vmServiceUri = prompt_vm_service_uri,
            cwd = function()
                return project_root()
            end,
        },
    }
end

---@return table[]
local function flutter_configurations()
    return {
        {
            name = 'Flutter: Launch App',
            type = FLUTTER_SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/lib/main.dart')
            end,
            args = {},
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Flutter: Debug Tests',
            type = 'flutter-test',
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            args = {},
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'Flutter: Attach to VM Service',
            type = FLUTTER_SOURCE,
            request = 'attach',
            vmServiceUri = prompt_vm_service_uri,
            cwd = function()
                return project_root()
            end,
        },
    }
end

---@return table[]
local function base_configurations()
    local configs = dart_configurations()

    for _, config in ipairs(flutter_configurations()) do
        configs[#configs + 1] = config
    end

    return configs
end

---@param opts {flutter?: boolean, test?: boolean}
---@return table
local function static_adapter(opts)
    local resolved = M.resolve_adapter(opts)

    if resolved ~= nil then
        return resolved
    end

    local flutter = opts.flutter == true
    local test = opts.test == true

    return {
        name = adapter_name(flutter, test),
        type = 'executable',
        command = flutter and 'flutter' or 'dart',
        args = adapter_args(test),
    }
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = tool_command(false),
    args = adapter_args(false),
}

---@type table<string, table>
M.adapters = {
    ['dart-test'] = static_adapter({ test = true }),
    flutter = static_adapter({ flutter = true }),
    ['flutter-test'] = static_adapter({ flutter = true, test = true }),
}

---@type table<string, table[]>
M.configurations = {}

for _, filetype in ipairs(FILETYPES) do
    M.configurations[filetype] = base_configurations()
end

local function check_health()
    local dart = find_dart()
    local flutter = find_flutter()
    local dart_version = dart ~= nil and tool_version_line(dart) or ''
    local flutter_version = flutter ~= nil and tool_version_line(flutter) or ''

    local messages = {
        'Dart/Flutter DAP (SDK debug adapters)',
        '',
        'dart: ' .. (dart or 'not found'),
        'dart version: ' .. (dart_version ~= '' and dart_version or 'unknown'),
        ('dart adapter: %s %s'):format(dart or 'dart', table.concat(adapter_args(false), ' ')),
        '',
        'flutter: ' .. (flutter or 'not found'),
        'flutter version: ' .. (flutter_version ~= '' and flutter_version or 'unknown'),
        ('flutter adapter: %s %s'):format(flutter or 'flutter', table.concat(adapter_args(false), ' ')),
        '',
        'note: the flutter tool also accepts `debug-adapter` (hyphen);',
        'this module uses `debug_adapter` (underscore), matching `dart`.',
    }

    if dart == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install the Dart SDK or set NVIM_DART_PATH=/path/to/dart'
    end

    if flutter == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install the Flutter SDK for Flutter targets'
        messages[#messages + 1] = 'or set NVIM_FLUTTER_PATH=/path/to/flutter'
    end

    notify(table.concat(messages, '\n'), (dart ~= nil or flutter ~= nil) and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    DartDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Dart/Flutter DAP configuration',
    },

    DartDebugVersion = {
        callback = function()
            local dart = find_dart()
            local flutter = find_flutter()

            notify(
                ('dart: %s\nflutter: %s'):format(
                    (dart ~= nil and tool_version_line(dart) or 'not found'),
                    (flutter ~= nil and tool_version_line(flutter) or 'not found')
                )
            )
        end,
        desc = 'Show Dart and Flutter SDK versions',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    dart_debug_check = {
        lhs = '<leader>dDc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Dart DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.dart_path` and `opts.flutter_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.dart_path) then
        state.dart_path = normalize(fn.expand(opts.dart_path))
    end

    if nonempty_string(opts.flutter_path) then
        state.flutter_path = normalize(fn.expand(opts.flutter_path))
    end

    local dart = find_dart()

    if dart == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'dart was not found.',
                    '',
                    'Install the Dart SDK, or set:',
                    'NVIM_DART_PATH=/path/to/dart',
                }, '\n'),
                levels.WARN
            )
        end)
    else
        --
        -- Keep the adapter commands synchronized with discovery.
        --
        M.adapter.command = dart
        M.adapters['dart-test'].command = dart
    end

    local flutter = find_flutter()

    if flutter ~= nil then
        M.adapters.flutter.command = flutter
        M.adapters['flutter-test'].command = flutter
    end
end

---@return string?
function M.dart_path()
    return find_dart()
end

---@return string?
function M.flutter_path()
    return find_flutter()
end

return M
