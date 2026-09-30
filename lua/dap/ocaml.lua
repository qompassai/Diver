-- #################################################################
-- ~/.config/nvim/lua/dap/ocaml.lua
-- Qompass AI Diver Native OCaml Debug Adapter Configuration
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
---@source https://github.com/hackwaly/ocamlearlybird
---@source https://github.com/hackwaly/ocamlearlybird/blob/master/src/main/main.ml
---@source https://github.com/mason-org/mason-registry/pull/4871

--- OCaml debugging via the ocamlearlybird debug adapter.
---
--- Plain-language version: the `ocamlearlybird` program (installed with
--- `opam install earlybird`, also shipped by Mason as `ocamlearlybird`)
--- speaks the Debug Adapter Protocol over its own standard input/output
--- when started as `ocamlearlybird debug`. This module finds that program
--- and hands out a ready-made recipe to launch a debug session against a
--- bytecode executable.
---
--- Verified facts (evidence over assumptions):
--- - `ocamlearlybird debug` is the stdio-DAP subcommand; the `serve`
---   subcommand instead listens on a TCP port. Verified in the adapter's
---   own command-line entry point (`src/main/main.ml`: `debug` wires
---   `Lwt_io.stdin`/`Lwt_io.stdout`; `serve` binds loopback port 4711).
--- - Launch fields follow the adapter README's configuration table:
---   `program` (required), `arguments`, `cwd`, `env`, `stopOnEntry`.
--- - The adapter ships in the Mason registry (`mason-registry` PR #4871,
---   "Adds Ocaml DAP ocamlearlybird").
---
--- Known limitations:
--- - The README's examples debug bytecode executables (e.g.
---   `test_program.bc`); there is no documented support for native
---   `ocamlopt` binaries, so build the debuggee with `ocamlc -g`.
--- - The adapter documents no `reason` filetype: only the `ocaml`
---   filetype is served here. Reason sources compile to the same
---   bytecode, but wiring a filetype the adapter never mentions would be
---   a guess, not a fact.
---@module 'dap.ocaml'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv
local levels = vim.log.levels

local M = {}

local SOURCE = 'ocaml'
local ADAPTER_ARGS = { 'debug' }

---@type string[]
local ROOT_MARKERS = {
    'dune-project',
    'dune-workspace',
    '.opam',
    '.git',
}

---@type string[]
local WELL_KNOWN_PATHS = {
    fn.expand('~/.local/share/nvim/mason/bin/ocamlearlybird'),
    fn.expand('~/.opam/default/bin/ocamlearlybird'),
    fn.expand('~/.npm-global/bin/ocamlearlybird'),
    '/usr/local/bin/ocamlearlybird',
    '/opt/homebrew/bin/ocamlearlybird',
}

---@class OcamlState
---@field adapter_path string?
local state = {
    adapter_path = nil,
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

---@return string?
local function find_ocamlearlybird()
    if state.adapter_path ~= nil then
        return state.adapter_path
    end

    local candidates = {}

    local configured = vim.env.NVIM_OCAMLEARLYBIRD_PATH

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.ocamlearlybird_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath('ocamlearlybird')

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    for _, path in ipairs(WELL_KNOWN_PATHS) do
        candidates[#candidates + 1] = path
    end

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            state.adapter_path = fs.normalize(candidate)

            return state.adapter_path
        end
    end

    return nil
end

---@return table?
function M.resolve_adapter()
    local path = find_ocamlearlybird()

    if path == nil then
        return nil
    end

    --
    -- `debug` is the verified stdio-DAP subcommand (src/main/main.ml);
    -- `serve` would instead listen on a TCP port and is not used here.
    --
    return {
        name = SOURCE,
        type = 'executable',
        command = path,
        args = ADAPTER_ARGS,
    }
end

---@return string
local function adapter_command()
    local path = find_ocamlearlybird()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when ocamlearlybird is missing.
    -- setup() warns before any session is attempted.
    --
    return 'ocamlearlybird'
end

---@param default string
---@return string?
local function prompt_program(default)
    local input = fn.input('Bytecode program: ', default, 'file')

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

---@param value unknown
---@return boolean
local function string_list(value)
    if type(value) ~= 'table' then
        return false
    end

    for _, element in ipairs(value) do
        if type(element) ~= 'string' then
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

    if opts.args ~= nil and not string_list(opts.args) then
        return nil, 'build_launch requires opts.args to be a list of strings'
    end

    if opts.cwd ~= nil and not nonempty_string(opts.cwd) then
        return nil, 'build_launch requires opts.cwd to be a non-empty string'
    end

    if opts.env ~= nil and type(opts.env) ~= 'table' then
        return nil, 'build_launch requires opts.env to be a table'
    end

    if opts.stop_on_entry ~= nil and type(opts.stop_on_entry) ~= 'boolean' then
        return nil, 'build_launch requires opts.stop_on_entry to be a boolean'
    end

    --
    -- Field names follow the adapter README's configuration table:
    -- `arguments` (not `args`), `stopOnEntry` (camelCase).
    --
    return {
        name = opts.name or 'OCaml: Launch',
        type = SOURCE,
        request = 'launch',
        program = opts.program,
        arguments = opts.args or {},
        stopOnEntry = opts.stop_on_entry == true,
        cwd = opts.cwd or project_root(),
        env = opts.env,
    }
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = ADAPTER_ARGS,
    options = {
        source_filetype = 'ocaml',
    },
}

---@type table<string, table[]>
M.configurations = {
    ocaml = {
        {
            name = 'OCaml: Launch Bytecode Program',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            arguments = function()
                local input = fn.input('Program arguments: ')

                if input == '' then
                    return {}
                end

                return fn.shellsplit(input)
            end,
            stopOnEntry = false,
            cwd = function()
                return project_root()
            end,
        },
        {
            name = 'OCaml: Launch Bytecode Program (Stop on Entry)',
            type = SOURCE,
            request = 'launch',
            program = function()
                return prompt_program(project_root() .. '/')
            end,
            stopOnEntry = true,
            cwd = function()
                return project_root()
            end,
        },
    },
}

local function check_health()
    local path = find_ocamlearlybird()

    local messages = {
        'OCaml DAP (ocamlearlybird, stdio)',
        '',
        'ocamlearlybird: ' .. (path or 'not found'),
        'invocation: ocamlearlybird debug',
        'project root: ' .. project_root(),
    }

    if path == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install with one of:'
        messages[#messages + 1] = '  opam install earlybird'
        messages[#messages + 1] = '  :MasonInstall ocamlearlybird'
        messages[#messages + 1] = 'or set NVIM_OCAMLEARLYBIRD_PATH=/path/to/ocamlearlybird'
    end

    notify(table.concat(messages, '\n'), path ~= nil and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    OcamlCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check OCaml DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    ocaml_check = {
        lhs = '<leader>dOc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'OCaml DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.ocamlearlybird_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.ocamlearlybird_path) then
        state.adapter_path = normalize(fn.expand(opts.ocamlearlybird_path))
    end

    local path = find_ocamlearlybird()

    if path == nil then
        -- Defer the nag: surfaced by Session.spawn when a session starts.
        M.adapter.missing_message = table.concat({
            'ocamlearlybird was not found.',
            '',
            'Install with: opam install earlybird',
            'Or: :MasonInstall ocamlearlybird',
            'Or set: NVIM_OCAMLEARLYBIRD_PATH=/path/to/ocamlearlybird',
        }, '\n')

        return
    end

    --
    -- Keep the adapter command synchronized with discovery.
    --
    M.adapter.command = path
    M.adapter.missing_message = nil
end

---@return string?
function M.ocamlearlybird_path()
    return find_ocamlearlybird()
end

return M
