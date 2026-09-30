-- #################################################################
-- ~/.config/nvim/lua/dap/godot.lua
-- Qompass AI Diver Native Godot/GDScript Debug Adapter Configuration
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
---@source https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html
---@source https://github.com/godotengine/godot
---@source https://github.com/godotengine/godot/pull/109637
---@source https://github.com/transitionmatrix/godot-dap-mcp-server

--- Godot/GDScript debugging through the editor's built-in DAP server.
---
--- Plain-language version: the Godot editor itself is the debug adapter.
--- While the editor is open on your project it serves the Debug Adapter
--- Protocol over TCP (default 127.0.0.1:6006). This module connects Neovim
--- to that server; a "launch" request tells the editor to run a scene, and
--- breakpoints you set in GDScript files stop the game.
---
--- Prerequisites (all required before a session can start):
---
--- 1. A Godot 4.2+ editor instance open with your project. The official
---    docs state: "a Godot instance must be running on your current
---    project".
--- 2. The debug adapter enabled under Editor -> Editor Settings ->
---    Network -> Debug Adapter. The port there
---    (`network/debug_adapter/remote_port`, default 6006) must match the
---    port this module connects to. This is NOT Network -> Debug ->
---    Remote Port (6007): that is the legacy remote debugger, a different
---    protocol.
---
--- Honest limitations:
---
--- - Godot's DAP server implements the `launch` request only; it drives the
---   editor's run bar (main scene, current scene, or a `res://` scene path
---   on the `host`/`android`/`web` platform). There is no DAP `attach`
---   request. `M.build_attach` therefore attaches the DAP *client* (this
---   TCP connection) to the already-listening editor, then issues `launch`.
--- - `stepOut` is not implemented in Godot's DAP server upstream.
--- - A headless editor cannot run a game (no display driver); launching
---   against one hangs until the request times out.
--- - The `godot` binary is only used for version reporting and health
---   checks; it is not the DAP server, so debugging works even when the
---   binary is not on PATH (e.g. flatpak installs).
---@module 'dap.godot'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'godot'
local LOOPBACK = '127.0.0.1'
local DEFAULT_DAP_PORT = 6006
local PROBE_TIMEOUT_MS = 5000

---@type string[]
local ROOT_MARKERS = {
    'project.godot',
    '.git',
}

---@type string[]
local WELL_KNOWN_PATHS = {
    '/usr/bin/godot',
    '/usr/local/bin/godot',
    '/opt/homebrew/bin/godot',
}

---@type table<string, boolean>
local SCENES = {
    main = true,
    current = true,
}

---@type table<string, boolean>
local PLATFORMS = {
    host = true,
    android = true,
    web = true,
}

---@type table<string, boolean>
local BUILD_ATTACH_FIELDS = {
    host = true,
    port = true,
    project_path = true,
    name = true,
    scene = true,
    platform = true,
    play_args = true,
    device = true,
}

---@class GodotState
---@field godot string?
---@field dap_port integer?
local state = {
    godot = nil,
    dap_port = nil,
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

---@return string?
local function find_godot()
    if state.godot ~= nil then
        return state.godot
    end

    local candidates = {}

    local configured = vim.env.NVIM_GODOT_PATH

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.godot_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath('godot')

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    for _, path in ipairs(WELL_KNOWN_PATHS) do
        candidates[#candidates + 1] = path
    end

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            state.godot = fs.normalize(candidate)

            return state.godot
        end
    end

    return nil
end

---@param path string
---@return string?
local function godot_version_line(path)
    local result = system({ path, '--version' })

    if result == nil or result.code ~= 0 or type(result.stdout) ~= 'string' then
        return nil
    end

    return trim(result.stdout:match('[^\r\n]*') or '')
end

---@param value unknown
---@return integer?, string?
local function valid_port(value)
    if type(value) ~= 'number' then
        return nil, 'port must be a number'
    end

    if value % 1 ~= 0 or value < 1 or value > 65535 then
        return nil, 'port must be an integer in 1..65535'
    end

    return math.floor(value)
end

---@param opts table
---@return integer?, string?
local function resolve_port(opts)
    if opts.port ~= nil then
        return valid_port(opts.port)
    end

    --
    -- Environment overrides fall back to the default instead of failing:
    -- a stale export should not break every session.
    --
    local raw = tonumber(vim.env.NVIM_GODOT_DAP_PORT or '') or tonumber(vim.g.godot_dap_port or '')

    if raw == nil then
        return DEFAULT_DAP_PORT
    end

    local port = valid_port(raw)

    if port == nil then
        return DEFAULT_DAP_PORT
    end

    return port
end

---@param scene unknown
---@return string?, string?
local function valid_scene(scene)
    if not nonempty_string(scene) then
        return nil, "scene must be 'main', 'current', or a res:// scene path"
    end

    if SCENES[scene] == true then
        return scene
    end

    --
    -- Custom scenes are res:// paths (e.g. "res://levels/level_1.tscn").
    -- UID-based scenes (uid://...) are untested against the DAP server.
    --
    if scene:sub(1, 6) == 'res://' and #scene > 6 then
        return scene
    end

    return nil, ("unknown scene '%s': expected 'main', 'current', or res://..."):format(scene)
end

---@param platform unknown
---@return string?, string?
local function valid_platform(platform)
    if not nonempty_string(platform) then
        return nil, "platform must be one of 'host', 'android', 'web'"
    end

    if PLATFORMS[platform] == true then
        return platform
    end

    return nil, ("unknown platform '%s': expected 'host', 'android', or 'web'"):format(platform)
end

---@param play_args unknown
---@return string[]?, string?
local function valid_play_args(play_args)
    if play_args == nil then
        return {}
    end

    if type(play_args) ~= 'table' then
        return nil, 'play_args must be a list of strings'
    end

    for index, arg in ipairs(play_args) do
        if type(arg) ~= 'string' then
            return nil, ('play_args[%d] must be a string'):format(index)
        end
    end

    return play_args
end

---@param opts? table
---@return table?, string?
function M.resolve_adapter(opts)
    opts = opts or {}

    local port, err = resolve_port(opts)

    if port == nil then
        return nil, err
    end

    local host = opts.host or LOOPBACK

    if not nonempty_string(host) then
        return nil, 'host must be a non-empty string'
    end

    return {
        name = SOURCE,
        type = 'server',
        host = host,
        port = port,
    }
end

---Validate the launch-configuration fields and build the config table.
---@param opts table
---@return table?, string? config or nil+err
local function build_launch_config(opts)
    local scene, scene_err = valid_scene(opts.scene or 'main')

    if scene == nil then
        return nil, 'build_attach: ' .. (scene_err or 'invalid scene')
    end

    local platform, platform_err = valid_platform(opts.platform or 'host')

    if platform == nil then
        return nil, 'build_attach: ' .. (platform_err or 'invalid platform')
    end

    local play_args, args_err = valid_play_args(opts.play_args)

    if play_args == nil then
        return nil, 'build_attach: ' .. (args_err or 'invalid play_args')
    end

    local config = {
        name = opts.name or ('Godot: Launch %s scene'):format(scene),
        type = SOURCE,
        request = 'launch',
        scene = scene,
        platform = platform,
        playArgs = play_args,
    }

    if opts.device ~= nil then
        if type(opts.device) ~= 'number' or opts.device % 1 ~= 0 then
            return nil, 'build_attach requires opts.device to be an integer'
        end

        --
        -- Device index for the android/web platforms (-1 selects the
        -- default device, matching the editor's own default).
        --
        config.device = math.floor(opts.device)
    end

    return config
end

--- Attach the DAP client to the running editor's debug-adapter server.
---
--- "Attach" here is transport-level: it opens the TCP connection to the
--- editor. The debug configuration still uses request='launch' because
--- Godot's DAP server implements launch only (no DAP attach request);
--- launch tells the editor's run bar which scene to play.
---@param opts? table fields: host, port, project_path, name, scene, platform, play_args, device
---@return table?, table|string? adapter and launch config, or nil+err
function M.build_attach(opts)
    opts = opts or {}

    for key in pairs(opts) do
        if BUILD_ATTACH_FIELDS[key] ~= true then
            return nil, ("build_attach: unknown field '%s'"):format(key)
        end
    end

    local host = opts.host or LOOPBACK

    if not nonempty_string(host) then
        return nil, 'build_attach requires opts.host to be a non-empty string'
    end

    local port, port_err = resolve_port(opts)

    if port == nil then
        return nil, 'build_attach: ' .. (port_err or 'invalid port')
    end

    if opts.project_path ~= nil and not nonempty_string(opts.project_path) then
        return nil, 'build_attach requires opts.project_path to be a non-empty string'
    end

    local config, config_err = build_launch_config(opts)

    if config == nil then
        return nil, config_err
    end

    local adapter = {
        type = 'server',
        host = host,
        port = port,
    }

    return adapter, config
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'server',
    host = LOOPBACK,
    port = function()
        return state.dap_port or DEFAULT_DAP_PORT
    end,
}

---@param prompt string
---@return string
local function prompt_scene(prompt)
    local input = fn.input(prompt, 'res://')

    if input == '' then
        return 'main'
    end

    return input
end

---@type table<string, table[]>
M.configurations = {
    gdscript = {
        {
            name = 'Godot: Launch Main Scene',
            type = SOURCE,
            request = 'launch',
            scene = 'main',
            platform = 'host',
            playArgs = {},
        },
        {
            name = 'Godot: Launch Current Scene',
            type = SOURCE,
            request = 'launch',
            scene = 'current',
            platform = 'host',
            playArgs = {},
        },
        {
            name = 'Godot: Launch Scene...',
            type = SOURCE,
            request = 'launch',
            scene = function()
                return prompt_scene('Scene (res://...): ')
            end,
            platform = 'host',
            playArgs = {},
        },
    },
}

local function check_health()
    local path = find_godot()
    local version = path ~= nil and godot_version_line(path) or nil
    local port = state.dap_port or DEFAULT_DAP_PORT

    local messages = {
        'Godot DAP (editor debug-adapter server)',
        '',
        'godot binary: ' .. (path or 'not found (ok: only used for version reporting)'),
        'godot version: ' .. (version or 'unknown'),
        ('DAP server: %s:%d'):format(LOOPBACK, port),
        'project root: ' .. project_root(),
        '',
        'prerequisites: open this project in the Godot 4.2+ editor with',
        'Editor -> Editor Settings -> Network -> Debug Adapter enabled,',
        ('port set to %d (not the 6007 legacy remote debugger).'):format(port),
        '',
        'limits: launch request only (no DAP attach); stepOut unimplemented',
        'upstream; headless editors cannot run games.',
    }

    if path == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install godot or set NVIM_GODOT_PATH=/path/to/godot'
        messages[#messages + 1] = 'for version reporting (debugging itself needs only the editor).'
    end

    notify(table.concat(messages, '\n'), levels.INFO)
end

---@type table<string, DebugCommand>
M.commands = {
    GodotDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Godot DAP configuration',
    },

    GodotDebugVersion = {
        callback = function()
            local path = find_godot()

            if path == nil then
                notify('godot not found', levels.WARN)

                return
            end

            notify(('%s'):format(godot_version_line(path) or 'unknown version'))
        end,
        desc = 'Show godot version',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    godot_check = {
        lhs = '<leader>dGa',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Godot DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.godot_path` and `opts.dap_port`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.godot_path) then
        state.godot = normalize(fn.expand(opts.godot_path))
    end

    if opts.dap_port ~= nil then
        local port, err = valid_port(opts.dap_port)

        if port == nil then
            vim.schedule(function()
                notify(('ignoring invalid dap_port: %s'):format(err or 'invalid'), levels.WARN)
            end)
        else
            state.dap_port = port
        end
    end

    --
    -- Keep the adapter port synchronized with discovery.
    --
    M.adapter.port = function()
        return state.dap_port or DEFAULT_DAP_PORT
    end

    -- The godot binary is only used for version reporting; debugging works
    -- without it, so no setup nag.
end

---@return string?
function M.godot_path()
    return find_godot()
end

---@return integer
function M.dap_port()
    return state.dap_port or DEFAULT_DAP_PORT
end

return M
