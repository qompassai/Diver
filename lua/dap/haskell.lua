-- #################################################################
-- ~/.config/nvim/lua/dap/haskell.lua
-- Qompass AI Diver Native Haskell Debug Adapter Configuration
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
---@source https://github.com/phoityne/haskell-debug-adapter
---@source https://github.com/phoityne/phoityne-vscode

--- Haskell debugging via the phoityne debug adapter.
---
--- Plain-language version: this module finds the `haskell-debug-adapter`
--- program and hands your Haskell project to it as a stdio debug adapter.
--- It detects whether you use Stack or Cabal, builds the right `ghci` command
--- for your project, and offers recipes to debug the main program, a single
--- file, or your test suite. It needs `ghci-dap` and `haskell-dap` too.
---@module 'dap.haskell'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'haskell'

---@type string[]
local ROOT_MARKERS = {
    'stack.yaml',
    'cabal.project',
    'package.yaml',
    '.git',
}

---@class HaskellBuildTool
---@field kind 'stack'|'cabal'|'none'
---@field root string

---@class HaskellState
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

        --
        -- A lone *.cabal file next to the source also anchors a project.
        --
        local parent = fs.dirname(filename)

        if type(parent) == 'string' and parent ~= '' then
            local handle = vim.uv.fs_scandir(parent)

            if handle ~= nil then
                while true do
                    local entry = vim.uv.fs_scandir_next(handle)

                    if entry == nil then
                        break
                    end

                    if entry:match('%.cabal$') ~= nil then
                        return fs.normalize(parent)
                    end
                end
            end

            return fs.normalize(parent)
        end
    end

    return fs.normalize(fn.getcwd())
end

---@return string?
local function find_adapter()
    if state.adapter_path ~= nil then
        return state.adapter_path
    end

    local candidates = {}

    local configured = vim.env.NVIM_HASKELL_DEBUG_ADAPTER

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g.haskell_debug_adapter_path

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath('haskell-debug-adapter')

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    candidates[#candidates + 1] = fn.expand('~/.local/bin/haskell-debug-adapter')

    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            state.adapter_path = fs.normalize(candidate)

            return state.adapter_path
        end
    end

    return nil
end

---@param root string
---@return HaskellBuildTool
local function detect_build_tool(root)
    if root == '' then
        return { kind = 'none', root = root }
    end

    if vim.fn.filereadable(root .. '/stack.yaml') == 1 then
        return { kind = 'stack', root = root }
    end

    if
        vim.fn.filereadable(root .. '/cabal.project') == 1
        or vim.fn.filereadable(root .. '/package.yaml') == 1
    then
        return { kind = 'cabal', root = root }
    end

    return { kind = 'none', root = root }
end

---@param root string
---@return string?
local function first_cabal_target(root)
    if root == '' then
        return nil
    end

    local handle = vim.uv.fs_scandir(root)

    if handle == nil then
        return nil
    end

    while true do
        local entry = vim.uv.fs_scandir_next(handle)

        if entry == nil then
            break
        end

        local name = entry:match('^(.+)%.cabal$')

        if name ~= nil then
            return name
        end
    end

    return nil
end

---@param tool HaskellBuildTool
---@return string
local function ghci_command(tool)
    local global = vim.g.haskell_ghci_cmd

    if nonempty_string(global) then
        return global
    end

    --
    -- phoityne drives the project through ghci-dap; the command below is the
    -- shape its README documents, adapted to the detected build tool.
    --
    if tool.kind == 'stack' then
        return 'stack ghci --with-ghc=ghci-dap --test --no-load --no-build --main-is TARGET'
    end

    if tool.kind == 'cabal' then
        local target = first_cabal_target(tool.root) or 'TARGET'
        local build_dir = '${workspaceFolder}/.vscode/dist-cabal-repl'

        return ('cabal repl -w ghci-dap --repl-no-load --builddir=%s %s'):format(
            build_dir,
            target
        )
    end

    return 'ghci-dap'
end

---@return string
local function adapter_command()
    local path = find_adapter()

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when the program is missing.
    -- setup() warns before any session is attempted.
    --
    return 'haskell-debug-adapter'
end

---@type table
M.adapter = {
    name = SOURCE,
    type = 'executable',
    command = adapter_command(),
    args = {},
    options = {
        source_filetype = 'haskell',
    },
}

---@type table<string, table[]>
M.configurations = {
    haskell = {
        {
            name = 'Haskell: Debug Main',
            type = SOURCE,
            request = 'launch',
            workspace = function()
                return project_root()
            end,
            startup = '${workspaceFolder}/app/Main.hs',
            startupFunc = 'main',
            startupArgs = '',
            stopOnEntry = false,
            mainArgs = '',
            ghciPrompt = 'H>>= ',
            ghciInitialPrompt = 'H>>= ',
            ghciCmd = function()
                return ghci_command(detect_build_tool(project_root()))
            end,
            ghciEnv = vim.empty_dict(),
            logFile = vim.fs.joinpath(fn.stdpath('cache'), 'haskell-debug-adapter.log'),
            logLevel = 'WARNING',
            forceInspect = false,
        },
        {
            name = 'Haskell: Debug Current File',
            type = SOURCE,
            request = 'launch',
            workspace = function()
                return project_root()
            end,
            startup = function()
                local filename = buffer_filename()

                if filename ~= '' then
                    return filename
                end

                return '${file}'
            end,
            stopOnEntry = true,
            mainArgs = '',
            ghciPrompt = 'H>>= ',
            ghciInitialPrompt = 'H>>= ',
            ghciCmd = function()
                return ghci_command(detect_build_tool(project_root()))
            end,
            ghciEnv = vim.empty_dict(),
            logFile = vim.fs.joinpath(fn.stdpath('cache'), 'haskell-debug-adapter.log'),
            logLevel = 'WARNING',
            forceInspect = false,
        },
        {
            name = 'Haskell: Debug Test Suite',
            type = SOURCE,
            request = 'launch',
            workspace = function()
                return project_root()
            end,
            startup = '${workspaceFolder}/test/Spec.hs',
            stopOnEntry = false,
            mainArgs = '',
            ghciPrompt = 'H>>= ',
            ghciInitialPrompt = 'H>>= ',
            ghciCmd = function()
                return ghci_command(detect_build_tool(project_root()))
            end,
            ghciEnv = vim.empty_dict(),
            logFile = vim.fs.joinpath(fn.stdpath('cache'), 'haskell-debug-adapter.log'),
            logLevel = 'WARNING',
            forceInspect = false,
        },
    },
}

local function check_health()
    local path = find_adapter()
    local root = project_root()
    local tool = detect_build_tool(root)
    local missing = {}

    for _, program in ipairs({ 'ghci-dap', 'haskell-dap' }) do
        if fn.exepath(program) == '' then
            missing[#missing + 1] = program
        end
    end

    local messages = {
        'Haskell DAP (phoityne)',
        '',
        'adapter: ' .. (path or 'not found'),
        'build tool: ' .. tool.kind,
        'project root: ' .. root,
        'ghci command: ' .. ghci_command(tool),
    }

    if #missing > 0 then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'missing helpers: ' .. table.concat(missing, ', ')
    end

    if path == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install haskell-debug-adapter or set:'
        messages[#messages + 1] = 'NVIM_HASKELL_DEBUG_ADAPTER=/path/to/haskell-debug-adapter'
    end

    notify(
        table.concat(messages, '\n'),
        (path ~= nil and #missing == 0) and levels.INFO or levels.WARN
    )
end

---@type table<string, DebugCommand>
M.commands = {
    HaskellCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Haskell DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    haskell_check = {
        lhs = '<leader>dHc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Haskell DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.adapter_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.adapter_path) then
        state.adapter_path = normalize(fn.expand(opts.adapter_path))
    end

    local path = find_adapter()

    if path == nil then
        vim.schedule(function()
            notify(
                table.concat({
                    'haskell-debug-adapter was not found.',
                    '',
                    'Install it (stack install haskell-debug-adapter)',
                    'or set NVIM_HASKELL_DEBUG_ADAPTER=/path/to/haskell-debug-adapter.',
                    'You also need ghci-dap and haskell-dap on PATH.',
                }, '\n'),
                levels.WARN
            )
        end)

        return
    end

    --
    -- Keep the adapter command synchronized with discovery.
    --
    M.adapter.command = path
end

---@return string?
function M.adapter_path()
    return find_adapter()
end

return M
