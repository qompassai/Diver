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
---@source https://github.com/well-typed/haskell-debugger
---@source https://well-typed.github.io/haskell-debugger/
---@source https://codeberg.org/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#haskell-hdb
---@source https://github.com/mrcjkb/haskell-tools.nvim/commit/d73425655f06a56b62efa2224a88c4eb861d5d5e
---@source https://github.com/phoityne/haskell-debug-adapter
---@source https://github.com/phoityne/phoityne-vscode

--- Haskell debugging with two adapters, probed in preference order.
---
--- Plain-language version: this module finds whichever Haskell debug
--- adapter you have installed and hands your project to it. It prefers
--- `hdb` -- Well-Typed's official step-through debugger, actively
--- maintained against current GHC (9.14+) -- and falls back to the
--- community `haskell-debug-adapter` (phoityne), which drives the project
--- through `ghci-dap`.
---
--- Verified hdb facts (see the @source URLs above):
--- * Repository: well-typed/haskell-debugger; executable name: `hdb`,
---   installed by `cabal install haskell-debugger` (lands in
---   ~/.local/bin by default; bindists ship a wrapper script).
--- * DAP entry point: `hdb server --port <port>` -- a TCP server, wired
---   here as an nvim-dap `type = 'server'` adapter. hdb has NO stdio DAP
---   mode: its CLI subcommands are `server`, `cli` (an interactive
---   terminal debugger, not DAP), `proxy`, and internal
---   `external-interpreter` helpers (verified against
---   hdb/Development/Debug/Options.hs on master).
--- * Launch request fields: `projectRoot` (full path), `entryFile`
---   (relative to projectRoot, e.g. `app/Main.hs`), `entryPoint`
---   (e.g. `main`), `entryArgs`, `extraGhcArgs` (official "Configuration"
---   table on the project homepage).
--- * Requires GHC >= 9.14 on PATH -- the same GHC version hdb was built
---   with.
---
--- Preference rationale: when both adapters are installed, hdb wins
--- because it is the official, actively maintained debugger for current
--- GHC, needs no ghci-dap/haskell-dap helpers, and loads the project
--- directly instead of scripting a ghci session. phoityne stays as the
--- fallback for older GHC toolchains.
---@module 'dap.haskell'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'haskell'

--- nvim-dap adapter name for the hdb adapter (matches the nvim-dap wiki).
local HDB_ADAPTER_NAME = 'haskell-debugger'

--- nvim-dap adapter name for the phoityne adapter (legacy value).
local PHOITYNE_ADAPTER_NAME = 'haskell'

---@type string[]
local ROOT_MARKERS = {
    'stack.yaml',
    'cabal.project',
    'package.yaml',
    '.git',
}

---@type string[]
local HDB_WELL_KNOWN = {
    '~/.cabal/bin/hdb',
    '~/.local/bin/hdb',
}

---@type string[]
local PHOITYNE_WELL_KNOWN = {
    '~/.cabal/bin/haskell-debug-adapter',
    '~/.local/bin/haskell-debug-adapter',
}

---@class HaskellBuildTool
---@field kind 'stack'|'cabal'|'none'
---@field root string

---@class HaskellProbeResult
---@field adapter 'hdb'|'phoityne'|nil preferred adapter, nil when none installed
---@field hdb_path string? discovered hdb executable
---@field phoityne_path string? discovered haskell-debug-adapter executable
---@field message string human-readable probe summary

---@class HaskellState
---@field hdb_path string? user override from setup()
---@field phoityne_path string? user override from setup()
local state = {
    hdb_path = nil,
    phoityne_path = nil,
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

---@param override string?
---@param env_name string
---@param global_name string
---@param exe_name string
---@param well_known string[]
---@return string[]
local function adapter_candidates(override, env_name, global_name, exe_name, well_known)
    local candidates = {}

    if nonempty_string(override) then
        candidates[#candidates + 1] = normalize(fn.expand(override))
    end

    local configured = vim.env[env_name]

    if nonempty_string(configured) then
        candidates[#candidates + 1] = normalize(fn.expand(configured))
    end

    local global = vim.g[global_name]

    if nonempty_string(global) then
        candidates[#candidates + 1] = normalize(fn.expand(global))
    end

    local on_path = fn.exepath(exe_name)

    if nonempty_string(on_path) then
        candidates[#candidates + 1] = fs.normalize(on_path)
    end

    for _, suffix in ipairs(well_known) do
        candidates[#candidates + 1] = fn.expand(suffix)
    end

    return candidates
end

---@param candidates string[]
---@return string?
local function first_executable(candidates)
    for _, candidate in ipairs(candidates) do
        if executable(candidate) then
            return fs.normalize(candidate)
        end
    end

    return nil
end

--- Discover the hdb executable. An override (from setup() or the
--- environment) wins only when it points at an executable; a stale or
--- mistyped override falls through to the remaining candidates.
---@return string?
function M.hdb_path()
    if nonempty_string(state.hdb_path) and executable(state.hdb_path) then
        return state.hdb_path
    end

    return first_executable(adapter_candidates(nil, 'NVIM_HDB_PATH', 'hdb_path', 'hdb', HDB_WELL_KNOWN))
end

--- Discover the haskell-debug-adapter (phoityne) executable.
---@return string?
function M.adapter_path()
    if nonempty_string(state.phoityne_path) and executable(state.phoityne_path) then
        return state.phoityne_path
    end

    return first_executable(
        adapter_candidates(
            nil,
            'NVIM_HASKELL_DEBUG_ADAPTER_PATH',
            'haskell_debug_adapter_path',
            'haskell-debug-adapter',
            PHOITYNE_WELL_KNOWN
        )
    )
end

--- Detect which adapters are installed. When both are present, hdb wins:
--- it is the official Well-Typed debugger, maintained against current
--- GHC, while phoityne is a community adapter kept as the fallback.
---@return HaskellProbeResult
function M.probe()
    local hdb_path = M.hdb_path()
    local phoityne_path = M.adapter_path()

    local result = {
        adapter = nil,
        hdb_path = hdb_path,
        phoityne_path = phoityne_path,
        message = '',
    }

    if hdb_path ~= nil and phoityne_path ~= nil then
        result.adapter = 'hdb'
        result.message = 'hdb and haskell-debug-adapter (phoityne) found; preferring hdb'
    elseif hdb_path ~= nil then
        result.adapter = 'hdb'
        result.message = 'hdb found'
    elseif phoityne_path ~= nil then
        result.adapter = 'phoityne'
        result.message = 'haskell-debug-adapter (phoityne) found; hdb not installed'
    else
        result.message = 'neither hdb nor haskell-debug-adapter (phoityne) found'
    end

    return result
end

--- Resolve an adapter definition: the probed/preferred adapter when
--- `which` is nil, or the named adapter. The returned table's command is
--- synchronized with discovery.
---@param which? 'hdb'|'phoityne'
---@return table? adapter definition
---@return string? err
function M.resolve_adapter(which)
    if which == nil then
        local probe = M.probe()

        if probe.adapter == nil then
            return nil, 'no Haskell debug adapter installed: ' .. probe.message
        end

        which = probe.adapter
    end

    if which == 'hdb' then
        local path = M.hdb_path()

        if path == nil then
            return nil,
                'hdb (Well-Typed haskell-debugger) is not installed: '
                    .. 'see https://well-typed.github.io/haskell-debugger/ '
                    .. '(note: `cabal install haskell-debug-adapter` installs the phoityne adapter instead)'
        end

        M.adapters.hdb.executable.command = path
        M.adapter = M.adapters.hdb

        return M.adapters.hdb
    end

    if which == 'phoityne' then
        local path = M.adapter_path()

        if path == nil then
            return nil,
                'haskell-debug-adapter (phoityne) is not installed: '
                    .. 'stack install haskell-debug-adapter or set NVIM_HASKELL_DEBUG_ADAPTER_PATH'
        end

        M.adapters.phoityne.command = path
        M.adapter = M.adapters.phoityne

        return M.adapters.phoityne
    end

    return nil, ("unknown Haskell debug adapter '%s' (expected 'hdb' or 'phoityne')"):format(tostring(which))
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

        return ('cabal repl -w ghci-dap --repl-no-load --builddir=%s %s'):format(build_dir, target)
    end

    return 'ghci-dap'
end

--- hdb wants entryFile relative to projectRoot (official "Configuration"
--- table). Keep the absolute path when the file sits outside the root.
---@param entry_file string
---@param root string
---@return string
local function relative_entry_file(entry_file, root)
    if root ~= '' and entry_file:sub(1, #root) == root then
        local rest = entry_file:sub(#root + 1)

        if rest:sub(1, 1) == '/' then
            rest = rest:sub(2)
        end

        if rest ~= '' then
            return rest
        end
    end

    return entry_file
end

---@param opts? table
---@return table? config
---@return string? err
function M.build_launch_hdb(opts)
    opts = opts or {}

    if M.hdb_path() == nil then
        return nil,
            'hdb (Well-Typed haskell-debugger) is not installed: '
                .. 'see https://well-typed.github.io/haskell-debugger/'
    end

    local root = opts.project_root or project_root()

    if not nonempty_string(root) then
        return nil, 'project_root must be a non-empty string'
    end

    local entry_file = opts.entry_file

    if entry_file == nil then
        entry_file = buffer_filename()

        if entry_file == '' then
            entry_file = '${file}'
        end
    end

    if not nonempty_string(entry_file) then
        return nil, 'entry_file must be a non-empty string'
    end

    local entry_point = opts.entry_point or 'main'

    if not nonempty_string(entry_point) then
        return nil, 'entry_point must be a non-empty string'
    end

    local entry_args = opts.entry_args or {}

    if type(entry_args) ~= 'table' then
        return nil, 'entry_args must be a list of strings'
    end

    local extra_ghc_args = opts.extra_ghc_args or {}

    if type(extra_ghc_args) ~= 'table' then
        return nil, 'extra_ghc_args must be a list of strings'
    end

    return {
        name = opts.name or 'Haskell: Launch (hdb)',
        type = HDB_ADAPTER_NAME,
        request = 'launch',
        projectRoot = root,
        entryFile = relative_entry_file(entry_file, root),
        entryPoint = entry_point,
        entryArgs = entry_args,
        extraGhcArgs = extra_ghc_args,
    }
end

---@param opts? table
---@return table? config
---@return string? err
function M.build_launch_phoityne(opts)
    opts = opts or {}

    if M.adapter_path() == nil then
        return nil,
            'haskell-debug-adapter (phoityne) is not installed: '
                .. 'stack install haskell-debug-adapter or set NVIM_HASKELL_DEBUG_ADAPTER_PATH'
    end

    local root = opts.project_root or project_root()

    if not nonempty_string(root) then
        return nil, 'project_root must be a non-empty string'
    end

    local startup = opts.startup

    if startup == nil then
        startup = buffer_filename()

        if startup == '' then
            startup = '${file}'
        end
    end

    if not nonempty_string(startup) then
        return nil, 'startup must be a non-empty string'
    end

    if opts.stop_on_entry ~= nil and type(opts.stop_on_entry) ~= 'boolean' then
        return nil, 'stop_on_entry must be a boolean'
    end

    local main_args = opts.main_args or ''

    if type(main_args) ~= 'string' then
        return nil, 'main_args must be a string'
    end

    local ghci_cmd = opts.ghci_cmd or ghci_command(detect_build_tool(root))

    if not nonempty_string(ghci_cmd) then
        return nil, 'ghci_cmd must be a non-empty string'
    end

    return {
        name = opts.name or 'Haskell: Launch (phoityne)',
        type = PHOITYNE_ADAPTER_NAME,
        request = 'launch',
        workspace = root,
        startup = startup,
        startupFunc = 'main',
        startupArgs = '',
        stopOnEntry = opts.stop_on_entry or false,
        mainArgs = main_args,
        ghciPrompt = 'H>>= ',
        ghciInitialPrompt = 'H>>= ',
        ghciCmd = ghci_cmd,
        ghciEnv = vim.empty_dict(),
        logFile = fs.joinpath(fn.stdpath('cache'), 'haskell-debug-adapter.log'),
        logLevel = 'WARNING',
        forceInspect = false,
    }
end

--- Build a launch configuration for the probed/preferred adapter, or for
--- the adapter named by `opts.adapter`. Every builder validates and
--- returns a config or nil+err.
---@param opts? table honours `opts.adapter` ('hdb'|'phoityne') plus the per-adapter opts
---@return table? config
---@return string? err
function M.build_launch(opts)
    opts = opts or {}

    local which = opts.adapter

    if which == nil then
        local probe = M.probe()

        if probe.adapter == nil then
            return nil, 'no Haskell debug adapter installed: ' .. probe.message
        end

        which = probe.adapter
    end

    if which == 'hdb' then
        return M.build_launch_hdb(opts)
    end

    if which == 'phoityne' then
        return M.build_launch_phoityne(opts)
    end

    return nil,
        ("unknown Haskell debug adapter '%s' (expected 'hdb' or 'phoityne')"):format(tostring(which))
end

---@type table<string, table>
M.adapters = {
    hdb = {
        name = HDB_ADAPTER_NAME,
        type = 'server',
        port = '${port}',
        executable = {
            command = 'hdb',
            --
            -- Verified DAP entry point (well-typed/haskell-debugger,
            -- hdb/Development/Debug/Options.hs): `hdb server --port <port>`.
            -- hdb has no stdio DAP mode.
            --
            args = { 'server', '--port', '${port}' },
        },
        options = {
            source_filetype = 'haskell',
        },
    },
    phoityne = {
        name = PHOITYNE_ADAPTER_NAME,
        type = 'executable',
        command = 'haskell-debug-adapter',
        args = {},
        options = {
            source_filetype = 'haskell',
        },
    },
}

--- Preferred adapter definition; refreshed by setup() and resolve_adapter().
---@type table
M.adapter = M.adapters.phoityne

---@param name string
---@param startup string|function
---@param stop_on_entry boolean
---@return table
local function phoityne_config(name, startup, stop_on_entry)
    return {
        name = name,
        type = PHOITYNE_ADAPTER_NAME,
        request = 'launch',
        workspace = function()
            return project_root()
        end,
        startup = startup,
        startupFunc = 'main',
        startupArgs = '',
        stopOnEntry = stop_on_entry,
        mainArgs = '',
        ghciPrompt = 'H>>= ',
        ghciInitialPrompt = 'H>>= ',
        ghciCmd = function()
            return ghci_command(detect_build_tool(project_root()))
        end,
        ghciEnv = vim.empty_dict(),
        logFile = fs.joinpath(fn.stdpath('cache'), 'haskell-debug-adapter.log'),
        logLevel = 'WARNING',
        forceInspect = false,
    }
end

---@type table<string, table[]>
M.configurations = {
    haskell = {
        {
            name = 'Haskell: Launch (hdb)',
            type = HDB_ADAPTER_NAME,
            request = 'launch',
            projectRoot = function()
                return project_root()
            end,
            entryFile = function()
                local root = project_root()
                local filename = buffer_filename()

                if filename == '' then
                    return '${file}'
                end

                return relative_entry_file(filename, root)
            end,
            entryPoint = 'main',
            entryArgs = {},
            extraGhcArgs = {},
        },
        {
            name = 'Haskell: Debug Main (hdb)',
            type = HDB_ADAPTER_NAME,
            request = 'launch',
            projectRoot = function()
                return project_root()
            end,
            entryFile = 'app/Main.hs',
            entryPoint = 'main',
            entryArgs = {},
            extraGhcArgs = {},
        },
        phoityne_config('Haskell: Launch (phoityne)', function()
            local filename = buffer_filename()

            if filename ~= '' then
                return filename
            end

            return '${file}'
        end, false),
        phoityne_config('Haskell: Debug Main (phoityne)', '${workspaceFolder}/app/Main.hs', false),
        phoityne_config('Haskell: Debug Current File (phoityne)', function()
            local filename = buffer_filename()

            if filename ~= '' then
                return filename
            end

            return '${file}'
        end, true),
        phoityne_config('Haskell: Debug Test Suite (phoityne)', '${workspaceFolder}/test/Spec.hs', false),
    },
}

local function check_health()
    local probe = M.probe()
    local root = project_root()
    local tool = detect_build_tool(root)
    local missing = {}

    if probe.phoityne_path ~= nil then
        for _, program in ipairs({ 'ghci-dap', 'haskell-dap' }) do
            if fn.exepath(program) == '' then
                missing[#missing + 1] = program
            end
        end
    end

    local messages = {
        'Haskell DAP (hdb + phoityne)',
        '',
        'hdb (Well-Typed): ' .. (probe.hdb_path or 'not found'),
        'phoityne: ' .. (probe.phoityne_path or 'not found'),
        'preferred: ' .. (probe.adapter or 'none'),
        'build tool: ' .. tool.kind,
        'project root: ' .. root,
        'ghci command: ' .. ghci_command(tool),
    }

    if probe.adapter == 'hdb' then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'hdb needs GHC >= 9.14 on PATH (same version it was built with)'
    end

    if #missing > 0 then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'missing phoityne helpers: ' .. table.concat(missing, ', ')
    end

    if probe.adapter == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'install hdb (cabal install haskell-debugger)'
        messages[#messages + 1] = 'or haskell-debug-adapter (stack install haskell-debug-adapter),'
        messages[#messages + 1] = 'or set NVIM_HDB_PATH / NVIM_HASKELL_DEBUG_ADAPTER_PATH'
    end

    local level = levels.WARN

    if probe.adapter ~= nil and #missing == 0 then
        level = levels.INFO
    end

    notify(table.concat(messages, '\n'), level)
end

---@type table<string, DebugCommand>
M.commands = {
    HaskellDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Haskell DAP configuration (hdb + phoityne)',
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
        desc = 'Haskell DAP: Check configuration (hdb + phoityne)',
    },
}

---@param opts? table user overrides; honours `opts.hdb_path` and `opts.adapter_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.hdb_path) then
        state.hdb_path = normalize(fn.expand(opts.hdb_path))
    end

    if nonempty_string(opts.adapter_path) then
        state.phoityne_path = normalize(fn.expand(opts.adapter_path))
    end

    local probe = M.probe()

    if probe.hdb_path ~= nil then
        M.adapters.hdb.executable.command = probe.hdb_path
    end

    if probe.phoityne_path ~= nil then
        M.adapters.phoityne.command = probe.phoityne_path
    end

    if probe.adapter ~= nil then
        M.adapter = M.adapters[probe.adapter]
    else
        vim.schedule(function()
            notify(
                table.concat({
                    'No Haskell debug adapter was found.',
                    '',
                    'Install hdb (cabal install haskell-debugger) or',
                    'haskell-debug-adapter (stack install haskell-debug-adapter),',
                    'or set NVIM_HDB_PATH / NVIM_HASKELL_DEBUG_ADAPTER_PATH.',
                    'phoityne also needs ghci-dap and haskell-dap on PATH;',
                    'hdb needs GHC >= 9.14 on PATH.',
                }, '\n'),
                levels.WARN
            )
        end)
    end
end

return M
