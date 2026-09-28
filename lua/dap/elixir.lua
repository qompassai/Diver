-- #################################################################
-- ~/.config/nvim/lua/dap/elixir.lua
-- Qompass AI Diver Native Elixir Debug Adapter Configuration
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
---@source https://github.com/elixir-lsp/elixir-ls
---@source https://github.com/juantascon/asdf-elixir-ls/issues/3
---@source https://github.com/swaits/turbo-debug.nvim/blob/HEAD/CHANGELOG.md
---@source https://github.com/whatsapp/edb/blob/HEAD/docs/DAP.md
---@source https://github.com/whatsapp/edb/blob/HEAD/README.md

--- Elixir debugging via ElixirLS or WhatsApp EDB.
---
--- Plain-language version: there are two debuggers that understand Elixir
--- code. ElixirLS ships a debug adapter script (`debug_adapter.sh`, renamed
--- from `debugger.sh` in recent releases) that runs `mix` tasks such as
--- `mix test` under the debugger. EDB (from WhatsApp) is a newer debugger
--- for the whole Erlang VM: it starts with `edb dap` and can launch a BEAM
--- node or attach to a running one, which covers Elixir code running on the
--- VM too. This module finds whichever adapter is installed, checks it, and
--- hands out ready-made debug recipes for both.
---
--- Adapter choice is explicit: `M.adapters.elixir_ls` speaks ElixirLS's
--- `mix_task` launch style (task, taskArgs, projectDir, requireFiles, per
--- the ElixirLS README), while `M.adapters.edb` follows EDB's DAP guide
--- (`edb dap`; launch via `run`, attach via `config.node`). The nvim-dap
--- adapter ids here are `elixir_ls` and `edb`; ElixirLS's VS Code-side type
--- `mix_task` and EDB's `erlang-edb` are client-side routing names and are
--- not needed by the servers themselves.
---@module 'dap.elixir'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'elixir'

---@type string[]
local ROOT_MARKERS = {
    'mix.exs',
    'mix.lock',
    '.formatter.exs',
    '.git',
}

---@class ElixirAdapterSpec
---@field env_var string environment variable holding an explicit path
---@field g_var string vim.g variable holding an explicit path
---@field exe_names string[] executable names probed on PATH and in mason bin

---@type table<string, ElixirAdapterSpec>
local ADAPTER_SPECS = {
    elixir_ls = {
        env_var = 'NVIM_ELIXIR_LS_DEBUGGER_PATH',
        g_var = 'elixir_ls_debugger_path',
        exe_names = {
            'elixir-ls-debugger',
            'debug_adapter.sh',
            'debugger.sh',
        },
    },
    edb = {
        env_var = 'NVIM_EDB_PATH',
        g_var = 'edb_path',
        exe_names = {
            'edb',
        },
    },
}

---@type string[]
local EDB_WELL_KNOWN_PATHS = {
    '/usr/local/bin/edb',
}

---@class ElixirState
---@field paths table<string, string?> discovered adapter paths, cached on hit
local state = {
    paths = {},
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

---@return string
local function mason_bin()
    local ok, data = pcall(fn.stdpath, 'data')

    if not ok or type(data) ~= 'string' or data == '' then
        return ''
    end

    return data .. '/mason/bin'
end

---@param spec ElixirAdapterSpec
---@param well_known string[]
---@return string?
local function find_binary(spec, well_known)
    local configured = vim.env[spec.env_var]

    if executable(configured or '') then
        return normalize(fn.expand(configured))
    end

    local global = vim.g[spec.g_var]

    if executable(global or '') then
        return normalize(fn.expand(global))
    end

    for _, name in ipairs(spec.exe_names) do
        local on_path = fn.exepath(name)

        if executable(on_path) then
            return fs.normalize(on_path)
        end
    end

    local bin = mason_bin()

    if bin ~= '' then
        for _, name in ipairs(spec.exe_names) do
            local candidate = bin .. '/' .. name

            if executable(candidate) then
                return fs.normalize(candidate)
            end
        end
    end

    for _, path in ipairs(well_known) do
        if executable(path) then
            return fs.normalize(path)
        end
    end

    return nil
end

---@param which string 'elixir_ls' or 'edb'
---@return string?
local function find_adapter(which)
    if state.paths[which] ~= nil then
        return state.paths[which]
    end

    local spec = ADAPTER_SPECS[which]

    if spec == nil then
        return nil
    end

    local well_known = which == 'edb' and EDB_WELL_KNOWN_PATHS or {}
    local path = find_binary(spec, well_known)

    if path ~= nil then
        state.paths[which] = path
    end

    return path
end

---@param which string
---@param fallback string placeholder used when the adapter is missing
---@return string
local function adapter_command(which, fallback)
    local path = find_adapter(which)

    if path ~= nil then
        return path
    end

    --
    -- Keep the adapter structurally valid when the program is missing.
    -- setup() warns before any session is attempted.
    --
    return fallback
end

---@param which string
---@return boolean
local function known_adapter(which)
    return which == 'elixir_ls' or which == 'edb'
end

---@type table<string, table>
M.adapters = {
    elixir_ls = {
        name = 'elixir_ls',
        type = 'executable',
        command = adapter_command('elixir_ls', 'elixir-ls-debugger'),
        args = {},
        options = {
            source_filetype = 'elixir',
        },
    },
    edb = {
        name = 'edb',
        type = 'executable',
        command = adapter_command('edb', 'edb'),
        args = {
            'dap',
        },
        options = {
            source_filetype = 'elixir',
        },
    },
}

---@param which string 'elixir_ls' or 'edb'
---@return table?, string?
function M.resolve_adapter(which)
    if not known_adapter(which) then
        return nil, ("unknown Elixir debug adapter: '%s' (expected 'elixir_ls' or 'edb')"):format(tostring(which))
    end

    local path = find_adapter(which)

    if path == nil then
        local spec = ADAPTER_SPECS[which]

        return nil, ("Elixir debug adapter '%s' not found; set %s=/path/to/adapter"):format(which, spec.env_var)
    end

    local adapter = M.adapters[which]
    adapter.command = path

    return adapter
end

---@param args unknown
---@return string[]?, string?
local function validate_args(args)
    if args == nil then
        return {}, nil
    end

    if type(args) ~= 'table' then
        return nil, 'build_launch requires opts.args to be a list of strings'
    end

    for index, value in ipairs(args) do
        if type(value) ~= 'string' then
            return nil, ('build_launch requires opts.args[%d] to be a string'):format(index)
        end
    end

    return args, nil
end

---@param opts table
---@return table?, string?
local function build_elixir_ls_launch(opts)
    local args, err = validate_args(opts.args)

    if args == nil then
        return nil, err
    end

    if #args == 0 then
        --
        -- Debugging a single file is the documented `mix_task` recipe:
        -- the file goes in both taskArgs and requireFiles so it is
        -- loaded and interpreted before the task runs.
        --
        args = { opts.program }
    end

    return {
        name = opts.name or 'ElixirLS: mix test (file)',
        type = 'elixir_ls',
        request = 'launch',
        task = opts.task or 'test',
        taskArgs = args,
        startApps = opts.start_apps == true,
        projectDir = opts.cwd or project_root(),
        requireFiles = opts.require_files or { opts.program },
    }, nil
end

---@param opts table
---@return table?, string?
local function build_edb_launch(opts)
    local args, err = validate_args(opts.args)

    if args == nil then
        return nil, err
    end

    --
    -- EDB launches a BEAM node itself (`run`, via open_port()); the first
    -- argument is the node executable, e.g. `mix` with `test` after it.
    --
    local node_args = { opts.program }

    for _, value in ipairs(args) do
        node_args[#node_args + 1] = value
    end

    local name_domain = opts.name_domain or 'shortnames'

    if name_domain ~= 'shortnames' and name_domain ~= 'longnames' then
        return nil, "build_launch requires opts.name_domain to be 'shortnames' or 'longnames'"
    end

    return {
        name = opts.name or 'EDB: Launch node',
        type = 'edb',
        request = 'launch',
        run = {
            cwd = opts.cwd or project_root(),
            args = node_args,
        },
        config = {
            nameDomain = name_domain,
            timeout = opts.timeout_s or 60,
        },
    }, nil
end

---@param opts table
---@return table?, string?
function M.build_launch(opts)
    opts = opts or {}

    if not nonempty_string(opts.program) then
        return nil, 'build_launch requires opts.program'
    end

    if opts.cwd ~= nil and not nonempty_string(opts.cwd) then
        return nil, 'build_launch requires opts.cwd to be a non-empty string'
    end

    local which = opts.adapter or 'elixir_ls'

    if which == 'elixir_ls' then
        return build_elixir_ls_launch(opts)
    end

    if which == 'edb' then
        return build_edb_launch(opts)
    end

    return nil, ("build_launch: unknown adapter '%s' (expected 'elixir_ls' or 'edb')"):format(tostring(which))
end

---@param opts table
---@return table?, string?
function M.build_attach(opts)
    opts = opts or {}

    if not nonempty_string(opts.node) then
        return nil, 'build_attach requires opts.node (e.g. mynode@localhost)'
    end

    if opts.cookie ~= nil and not nonempty_string(opts.cookie) then
        return nil, 'build_attach requires opts.cookie to be a non-empty string'
    end

    local inner

    if nonempty_string(opts.cookie) then
        inner = {
            node = opts.node,
            cookie = opts.cookie,
            cwd = opts.cwd or project_root(),
        }
    else
        inner = {
            node = opts.node,
            cwd = opts.cwd or project_root(),
        }
    end

    return {
        name = opts.name or ('EDB: Attach %s'):format(opts.node),
        type = 'edb',
        request = 'attach',
        config = inner,
    }, nil
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
local function prompt_node()
    local input = fn.input('Node (name@host): ')

    if input == '' then
        return nil
    end

    return vim.trim(input)
end

---@type table<string, table[]>
M.configurations = {
    elixir = {
        {
            name = 'ElixirLS: mix test',
            type = 'elixir_ls',
            request = 'launch',
            task = 'test',
            taskArgs = {
                '--trace',
            },
            startApps = true,
            projectDir = function()
                return project_root()
            end,
            requireFiles = {
                'test/**/test_helper.exs',
                'test/**/*_test.exs',
            },
        },
        {
            name = 'ElixirLS: mix test (current file)',
            type = 'elixir_ls',
            request = 'launch',
            task = 'test',
            taskArgs = function()
                local file = buffer_filename()

                return file ~= '' and { file } or {}
            end,
            projectDir = function()
                return project_root()
            end,
            requireFiles = function()
                local file = buffer_filename()

                return file ~= '' and { file } or {}
            end,
        },
        {
            name = 'ElixirLS: phx.server',
            type = 'elixir_ls',
            request = 'launch',
            task = 'phx.server',
            projectDir = function()
                return project_root()
            end,
            debugAutoInterpretAllModules = false,
            debugInterpretModulesPatterns = {
                'MyApp*',
                'MyAppWeb*',
            },
            exitAfterTaskReturns = false,
        },
        {
            name = 'EDB: Launch mix test',
            type = 'edb',
            request = 'launch',
            run = {
                cwd = function()
                    return project_root()
                end,
                args = function()
                    local extra = prompt_args()
                    local node_args = { 'mix', 'test' }

                    for _, value in ipairs(extra) do
                        node_args[#node_args + 1] = value
                    end

                    return node_args
                end,
            },
            config = {
                nameDomain = 'shortnames',
                timeout = 60,
            },
        },
        {
            name = 'EDB: Attach to node',
            type = 'edb',
            request = 'attach',
            config = {
                node = function()
                    return prompt_node()
                end,
                cwd = function()
                    return project_root()
                end,
            },
        },
    },
}

local function check_health()
    local elixir_ls = find_adapter('elixir_ls')
    local edb = find_adapter('edb')

    local messages = {
        'Elixir DAP (ElixirLS + EDB)',
        '',
        'elixir_ls: ' .. (elixir_ls or 'not found'),
        'edb: ' .. (edb or 'not found'),
        'project root: ' .. project_root(),
    }

    if elixir_ls == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'ElixirLS debugger missing: unzip a release'
        messages[#messages + 1] = '(provides debug_adapter.sh) or install via'
        messages[#messages + 1] = 'asdf/mise (provides bin/elixir-ls-debugger),'
        messages[#messages + 1] = 'or set NVIM_ELIXIR_LS_DEBUGGER_PATH=/path/to/debug_adapter.sh'
    end

    if edb == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'EDB missing: build from source with'
        messages[#messages + 1] = 'rebar3 escriptize (-> _build/default/bin/edb),'
        messages[#messages + 1] = 'or set NVIM_EDB_PATH=/path/to/edb'
    end

    if edb ~= nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'note: attach targets must run with the +D'
        messages[#messages + 1] = 'flag; EDB adds +D to ERL_AFLAGS on launch'
    end

    local ok = elixir_ls ~= nil or edb ~= nil
    notify(table.concat(messages, '\n'), ok and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    ElixirDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Elixir DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    elixir_check = {
        lhs = '<leader>dEc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Elixir DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.elixir_ls_debugger_path` and `opts.edb_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.elixir_ls_debugger_path) then
        state.paths.elixir_ls = normalize(fn.expand(opts.elixir_ls_debugger_path))
    end

    if nonempty_string(opts.edb_path) then
        state.paths.edb = normalize(fn.expand(opts.edb_path))
    end

    local elixir_ls = find_adapter('elixir_ls')

    if elixir_ls ~= nil then
        M.adapters.elixir_ls.command = elixir_ls
    else
        vim.schedule(function()
            notify(
                table.concat({
                    'ElixirLS debugger was not found.',
                    '',
                    'Unzip an ElixirLS release (debug_adapter.sh), install',
                    'via asdf/mise (bin/elixir-ls-debugger), or set:',
                    'NVIM_ELIXIR_LS_DEBUGGER_PATH=/path/to/debug_adapter.sh',
                }, '\n'),
                levels.WARN
            )
        end)
    end

    local edb = find_adapter('edb')

    if edb ~= nil then
        M.adapters.edb.command = edb
    else
        vim.schedule(function()
            notify(
                table.concat({
                    'EDB was not found.',
                    '',
                    'Build from source: rebar3 escriptize',
                    '(_build/default/bin/edb), or set:',
                    'NVIM_EDB_PATH=/path/to/edb',
                }, '\n'),
                levels.WARN
            )
        end)
    end
end

---@return string?
function M.elixir_ls_path()
    return find_adapter('elixir_ls')
end

---@return string?
function M.edb_path()
    return find_adapter('edb')
end

return M
