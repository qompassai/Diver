-- #################################################################
-- ~/.config/nvim/lua/dap/renderdoc.lua
-- Qompass AI Diver RenderDoc Graphics-Debug Helper
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
---@source https://renderdoc.org/
---@source https://github.com/baldurk/renderdoc

--- RenderDoc graphics-debug helper. This is NOT a DAP adapter.
---
--- What RenderDoc is: the industry-standard frame-capture graphics
--- debugger by Baldur Karlsson (baldurk/renderdoc), v1.46 (Sept 2026),
--- MIT licensed, actively maintained. Captures frames from Vulkan,
--- D3D11/D3D12, OpenGL and GLES applications so every draw call,
--- texture and shader in a frame can be inspected.
---
--- Why this lives in lua/dap/ without being a DAP adapter: no DAP wire
--- protocol exists for RenderDoc. It ships a GUI (qrenderdoc) plus the
--- renderdoccmd CLI. This module wraps renderdoccmd capture, capture
--- listing and capture opening as argv-built subprocess calls, and
--- registers discoverable commands through the dap dispatcher registry
--- (see register_module_definition in dap/init.lua), so graphics
--- developers get the same command surface as real DAP adapters.
---
--- Plain-language version: RenderDoc takes a snapshot of what your GPU
--- drew in one frame, then lets you inspect it. This module launches
--- those snapshots and opens them from inside Neovim. It never speaks
--- the Debug Adapter Protocol.
---
--- vogl: deliberately NOT implemented. Valve's vogl OpenGL debugger lost
--- its lead developer (Rich Geldreich left Valve in 2014) and the repo
--- has been stale/archived for a decade. RenderDoc covers everything
--- vogl did and more, so no dedicated vogl module should be created.
---@module 'dap.renderdoc'

local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = 'renderdoc'
local RENDERDOCCMD = 'renderdoccmd'
local QRENDERDOC = 'qrenderdoc'
local CAPTURE_SUFFIX = '.rdc'

-- Bounds. INT_OPTION_MAX mirrors the CLI: "Must be within [0, 10000]".
local MAX_CAPTURES = 512
local MAX_CAPTURE_ARGS = 128
local MAX_PATH_BYTES = 4096
local INT_OPTION_MAX = 10000

---@class RenderdocCaptureOpts
---@field executable string target binary to launch under capture (required)
---@field args? string[] program arguments, passed verbatim as argv
---@field working_dir? string directory the target runs in (must exist)
---@field capture_file? string filename template; the frame number is appended automatically
---@field wait_for_exit? boolean pass --wait-for-exit (block until the target exits)
---@field disallow_vsync? boolean --opt-disallow-vsync
---@field disallow_fullscreen? boolean --opt-disallow-fullscreen
---@field api_validation? boolean --opt-api-validation
---@field api_validation_unmute? boolean --opt-api-validation-unmute
---@field capture_callstacks? boolean --opt-capture-callstacks
---@field capture_callstacks_only_actions? boolean --opt-capture-callstacks-only-actions
---@field verify_buffer_access? boolean --opt-verify-buffer-access
---@field hook_children? boolean --opt-hook-children
---@field ref_all_resources? boolean --opt-ref-all-resources
---@field capture_all_cmd_lists? boolean --opt-capture-all-cmd-lists
---@field delay_for_debugger? integer --opt-delay-for-debugger, seconds, within [0, 10000]
---@field soft_memory_limit? integer --opt-soft-memory-limit, within [0, 10000]

local setup_done = false

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

---@param value string
---@return boolean
local function has_nul(value)
    return value:find('%z') ~= nil
end

---@param value unknown
---@param what string
---@return string?, string?
local function validate_path_text(value, what)
    if not nonempty_string(value) then
        return nil, what .. ' must be a non-empty string'
    end

    ---@cast value string
    if has_nul(value) then
        return nil, what .. ' contains a NUL byte'
    end

    if #value > MAX_PATH_BYTES then
        return nil, ('%s exceeds %d bytes'):format(what, MAX_PATH_BYTES)
    end

    return value
end

---@param dir unknown
---@return string?, string?
local function validate_dir(dir)
    local path, path_err = validate_path_text(dir, 'working_dir')

    if path == nil then
        return nil, path_err
    end

    -- fnamemodify(':p') absolutizes and collapses '..' segments, so a
    -- traversal attempt is checked in its resolved form, not its text form.
    local absolute = fs.normalize(fn.fnamemodify(path, ':p'))
    local stat = uv.fs_stat(absolute)

    if stat == nil then
        return nil, 'directory does not exist: ' .. absolute
    end

    if stat.type ~= 'directory' then
        return nil, 'not a directory: ' .. absolute
    end

    return absolute
end

---@param executable unknown
---@return string?, string?
local function validate_executable(executable)
    local path, path_err = validate_path_text(executable, 'executable')

    if path == nil then
        return nil, path_err
    end

    if path:find('[/\\]') ~= nil then
        local stat = uv.fs_stat(path)

        if stat == nil or stat.type ~= 'file' then
            return nil, 'executable not found: ' .. path
        end

        return path
    end

    if fn.executable(path) ~= 1 then
        return nil, 'executable not in PATH: ' .. path
    end

    return path
end

---@param args unknown
---@return string[]?, string?
local function validate_args(args)
    if args == nil then
        return {}
    end

    if type(args) ~= 'table' then
        return nil, 'args must be a table of strings'
    end

    if #args > MAX_CAPTURE_ARGS then
        return nil, ('args exceeds %d entries'):format(MAX_CAPTURE_ARGS)
    end

    ---@type string[]
    local validated = {}

    for index, arg in ipairs(args) do
        local clean, arg_err = validate_path_text(arg, ('args[%d]'):format(index))

        if clean == nil then
            return nil, arg_err
        end

        validated[#validated + 1] = clean
    end

    return validated
end

---@param value unknown
---@param flag string
---@return integer?, string?
local function validate_int_option(value, flag)
    if value == nil then
        return nil
    end

    if type(value) ~= 'number' or value % 1 ~= 0 then
        return nil, flag .. ' must be an integer'
    end

    if value < 0 or value > INT_OPTION_MAX then
        return nil, ('%s must be within [0, %d]'):format(flag, INT_OPTION_MAX)
    end

    ---@cast value integer
    return value
end

---@param argv string[]
---@param flag string
---@param enabled unknown
local function append_flag(argv, flag, enabled)
    if enabled == true then
        argv[#argv + 1] = flag
    end
end

-- Builds the argv array for `renderdoccmd capture`. Every flag below was
-- observed in `renderdoccmd capture --help` on renderdoccmd v1.46; nothing
-- is invented. Program arguments are appended verbatim after the
-- executable: no shell string is ever constructed.
---@param opts table
---@return string[]?, string?
local function build_capture_argv(opts)
    if type(opts) ~= 'table' then
        return nil, 'opts must be a table'
    end

    local executable, executable_err = validate_executable(opts.executable)

    if executable == nil then
        return nil, executable_err
    end

    local args, args_err = validate_args(opts.args)

    if args == nil then
        return nil, args_err
    end

    ---@type string[]
    local argv = {
        RENDERDOCCMD,
        'capture',
    }

    if opts.working_dir ~= nil then
        local dir, dir_err = validate_dir(opts.working_dir)

        if dir == nil then
            return nil, dir_err
        end

        argv[#argv + 1] = '--working-dir'
        argv[#argv + 1] = dir
    end

    if opts.capture_file ~= nil then
        local template, template_err = validate_path_text(opts.capture_file, 'capture_file')

        if template == nil then
            return nil, template_err
        end

        argv[#argv + 1] = '--capture-file'
        argv[#argv + 1] = template
    end

    if opts.wait_for_exit == true then
        argv[#argv + 1] = '--wait-for-exit'
    end

    append_flag(argv, '--opt-disallow-vsync', opts.disallow_vsync)
    append_flag(argv, '--opt-disallow-fullscreen', opts.disallow_fullscreen)
    append_flag(argv, '--opt-api-validation', opts.api_validation)
    append_flag(argv, '--opt-api-validation-unmute', opts.api_validation_unmute)
    append_flag(argv, '--opt-capture-callstacks', opts.capture_callstacks)
    append_flag(argv, '--opt-capture-callstacks-only-actions', opts.capture_callstacks_only_actions)
    append_flag(argv, '--opt-verify-buffer-access', opts.verify_buffer_access)
    append_flag(argv, '--opt-hook-children', opts.hook_children)
    append_flag(argv, '--opt-ref-all-resources', opts.ref_all_resources)
    append_flag(argv, '--opt-capture-all-cmd-lists', opts.capture_all_cmd_lists)

    local delay, delay_err = validate_int_option(opts.delay_for_debugger, '--opt-delay-for-debugger')

    if delay_err ~= nil then
        return nil, delay_err
    end

    if delay ~= nil then
        argv[#argv + 1] = '--opt-delay-for-debugger'
        argv[#argv + 1] = tostring(delay)
    end

    local limit, limit_err = validate_int_option(opts.soft_memory_limit, '--opt-soft-memory-limit')

    if limit_err ~= nil then
        return nil, limit_err
    end

    if limit ~= nil then
        argv[#argv + 1] = '--opt-soft-memory-limit'
        argv[#argv + 1] = tostring(limit)
    end

    argv[#argv + 1] = executable

    for _, arg in ipairs(args) do
        argv[#argv + 1] = arg
    end

    return argv
end

---@param argv string[]
---@param what string
---@return boolean, string?
local function spawn_detached(argv, what)
    assert(type(argv) == 'table' and #argv > 0, 'argv must be a non-empty table')

    local ok, job_err = pcall(vim.system, argv, {
        detach = true,
    }, function(result)
        if result.code ~= 0 then
            vim.schedule(function()
                notify(('%s failed (exit %d)'):format(what, result.code), levels.ERROR)
            end)
        end
    end)

    if not ok then
        return false, ('failed to start %s: %s'):format(what, tostring(job_err))
    end

    return true
end

---@return boolean
function M.is_available()
    return fn.executable(RENDERDOCCMD) == 1
end

---@return boolean
function M.ui_available()
    return fn.executable(QRENDERDOC) == 1
end

---@param opts RenderdocCaptureOpts
---@return boolean, string?
function M.capture(opts)
    if not M.is_available() then
        return false, RENDERDOCCMD .. ' is not installed or not in PATH'
    end

    local argv, argv_err = build_capture_argv(opts)

    if argv == nil then
        return false, argv_err
    end

    return spawn_detached(argv, RENDERDOCCMD .. ' capture')
end

---@param entry { path: string, mtime: integer, name: string }
---@param other { path: string, mtime: integer, name: string }
---@return boolean
local function capture_newest_first(entry, other)
    if entry.mtime ~= other.mtime then
        return entry.mtime > other.mtime
    end

    return entry.name < other.name
end

--- List RenderDoc captures (*.rdc) in a directory, newest first.
--- Deterministic: ties break on filename, so repeated calls agree.
---@param dir? string directory to scan; defaults to the current working directory
---@return string[]?, string?
function M.list_captures(dir)
    local scan_dir = dir or fn.getcwd()
    local absolute, absolute_err = validate_dir(scan_dir)

    if absolute == nil then
        return nil, absolute_err
    end

    local ok, iterator = pcall(fs.dir, absolute)

    if not ok or type(iterator) ~= 'function' then
        return nil, 'cannot read directory: ' .. absolute
    end

    ---@type { path: string, mtime: integer, name: string }[]
    local entries = {}

    for name, kind in iterator do
        if kind == 'file' and #name >= #CAPTURE_SUFFIX and name:sub(-#CAPTURE_SUFFIX) == CAPTURE_SUFFIX then
            local path = fs.joinpath(absolute, name)
            local stat = uv.fs_stat(path)
            local mtime = 0

            if stat ~= nil and stat.mtime ~= nil and type(stat.mtime.sec) == 'number' then
                mtime = stat.mtime.sec
            end

            entries[#entries + 1] = {
                path = path,
                mtime = mtime,
                name = name,
            }
        end
    end

    table.sort(entries, capture_newest_first)

    ---@type string[]
    local result = {}

    for index, entry in ipairs(entries) do
        if index > MAX_CAPTURES then
            break
        end

        result[#result + 1] = entry.path
    end

    return result
end

---@param path unknown
---@return boolean, string?
function M.open_capture(path)
    if not M.ui_available() then
        return false, QRENDERDOC .. ' is not installed or not in PATH'
    end

    local clean, clean_err = validate_path_text(path, 'capture path')

    if clean == nil then
        return false, clean_err
    end

    if #clean < #CAPTURE_SUFFIX or clean:sub(-#CAPTURE_SUFFIX):lower() ~= CAPTURE_SUFFIX then
        return false, 'not a RenderDoc capture (' .. CAPTURE_SUFFIX .. '): ' .. clean
    end

    local stat = uv.fs_stat(clean)

    if stat == nil or stat.type ~= 'file' then
        return false, 'capture not found: ' .. clean
    end

    return spawn_detached({
        QRENDERDOC,
        clean,
    }, QRENDERDOC)
end

---@return boolean, string?
function M.open_ui()
    if not M.ui_available() then
        return false, QRENDERDOC .. ' is not installed or not in PATH'
    end

    return spawn_detached({
        QRENDERDOC,
    }, QRENDERDOC)
end

---@type table<string, DebugCommand>
M.commands = {
    VulkanCapture = {
        callback = function(args)
            local fargs = args.fargs or {}
            local executable = fargs[1]

            if not nonempty_string(executable) then
                notify('usage: VulkanCapture <executable> [args ...]', levels.ERROR)

                return
            end

            ---@type string[]
            local capture_args = {}

            for index = 2, #fargs do
                capture_args[#capture_args + 1] = fargs[index]
            end

            local ok, capture_err = M.capture({
                executable = executable,
                args = capture_args,
                -- Vulkan-specific: record API (validation-layer) debug
                -- events so the capture carries the messages the
                -- validation layers emitted during the frame.
                api_validation = true,
            })

            if not ok then
                notify(capture_err or 'capture failed', levels.ERROR)

                return
            end

            notify('capturing Vulkan target (API validation on): ' .. executable)
        end,

        complete = 'file',

        desc = 'Capture a Vulkan application with RenderDoc (API validation enabled)',

        nargs = '+',
    },

    RenderdocCapture = {
        callback = function(args)
            local fargs = args.fargs or {}
            local executable = fargs[1]

            if not nonempty_string(executable) then
                notify('usage: RenderdocCapture <executable> [args ...]', levels.ERROR)

                return
            end

            ---@type string[]
            local capture_args = {}

            for index = 2, #fargs do
                capture_args[#capture_args + 1] = fargs[index]
            end

            local ok, capture_err = M.capture({
                executable = executable,
                args = capture_args,
            })

            if not ok then
                notify(capture_err or 'capture failed', levels.ERROR)

                return
            end

            notify('capturing: ' .. executable)
        end,

        complete = 'file',

        desc = 'Capture a graphics application with RenderDoc',

        nargs = '+',
    },

    RenderdocCaptures = {
        callback = function()
            local captures, list_err = M.list_captures()

            if captures == nil then
                notify(list_err or 'capture listing failed', levels.ERROR)

                return
            end

            if #captures == 0 then
                notify('no ' .. CAPTURE_SUFFIX .. ' captures in ' .. fn.getcwd(), levels.WARN)

                return
            end

            vim.ui.select(captures, {
                prompt = 'RenderDoc capture:',
            }, function(choice)
                if choice == nil then
                    return
                end

                local ok, open_err = M.open_capture(choice)

                if not ok then
                    notify(open_err or 'open failed', levels.ERROR)
                end
            end)
        end,

        desc = 'List RenderDoc captures and open the selected one',
    },

    RenderdocOpen = {
        callback = function(args)
            local ok, open_err = M.open_capture(args.args)

            if not ok then
                notify(open_err or 'open failed', levels.ERROR)
            end
        end,

        complete = 'file',

        desc = 'Open a .rdc capture in the RenderDoc UI',

        nargs = 1,
    },

    RenderdocUI = {
        callback = function()
            local ok, ui_err = M.open_ui()

            if not ok then
                notify(ui_err or 'UI launch failed', levels.ERROR)
            end
        end,

        desc = 'Open the RenderDoc UI',
    },

    RenderdocStatus = {
        callback = function()
            notify(
                ('renderdoccmd: %s | qrenderdoc: %s'):format(
                    M.is_available() and 'available' or 'missing',
                    M.ui_available() and 'available' or 'missing'
                )
            )
        end,

        desc = 'Show RenderDoc tool availability',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    renderdoc_vulkan_capture = {
        lhs = '<leader>dGv',

        mode = 'n',

        rhs = function()
            local executable = fn.input('Vulkan target executable: ')

            if executable == '' then
                return
            end

            local ok, capture_err = M.capture({
                executable = executable,
                api_validation = true,
            })

            if not ok then
                notify(capture_err or 'capture failed', levels.ERROR)

                return
            end

            notify('capturing Vulkan target (API validation on): ' .. executable)
        end,

        desc = 'RenderDoc: Capture Vulkan target (API validation on)',
    },

    renderdoc_capture = {
        lhs = '<leader>dGc',

        mode = 'n',

        rhs = function()
            local executable = fn.input('RenderDoc target executable: ')

            if executable == '' then
                return
            end

            local ok, capture_err = M.capture({
                executable = executable,
            })

            if not ok then
                notify(capture_err or 'capture failed', levels.ERROR)

                return
            end

            notify('capturing: ' .. executable)
        end,

        desc = 'RenderDoc: Capture target executable',
    },

    renderdoc_captures = {
        lhs = '<leader>dGl',

        mode = 'n',

        rhs = function()
            M.commands.RenderdocCaptures.callback({})
        end,

        desc = 'RenderDoc: List captures',
    },

    renderdoc_ui = {
        lhs = '<leader>dGo',

        mode = 'n',

        rhs = function()
            local ok, ui_err = M.open_ui()

            if not ok then
                notify(ui_err or 'UI launch failed', levels.ERROR)
            end
        end,

        desc = 'RenderDoc: Open UI',
    },
}

---@param opts? table reserved for future use; currently unused
function M.setup(opts)
    opts = opts or {}

    if setup_done then
        return
    end

    setup_done = true

    -- RenderDoc commands report a missing binary themselves when used,
    -- so no setup nag.
end

return M
