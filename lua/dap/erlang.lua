-- #################################################################
-- ~/.config/nvim/lua/dap/erlang.lua
-- Qompass AI Diver Native Erlang Debug Adapter Configuration
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
---@source https://github.com/whatsapp/edb/blob/HEAD/docs/DAP.md
---@source https://github.com/whatsapp/edb/blob/HEAD/README.md
---@source https://github.com/erlang-ls/erlang-ls.github.io/blob/HEAD/docs/articles/tutorial-debugger.md
---@source https://github.com/vladdu/erlang_ls/blob/HEAD/vladdu_erlang_ls/SPAWNFEST.md
---@source https://erlang-ls.github.io/articles/tutorial-debugger/

--- Erlang debugging via WhatsApp EDB or ErlangLS's els_dap.
---
--- Plain-language version: two debuggers speak the Debug Adapter Protocol
--- for Erlang. EDB (from WhatsApp, the primary route) starts with
--- `edb dap`: it can launch a BEAM node itself or attach to a running one
--- (the target needs the `+D` flag). els_dap (from ErlangLS, the secondary
--- route) is a separate escript built with `rebar3 as dap escriptize`
--- (lands in `_build/dap/bin/els_dap`) that runs on the OTP interpreter,
--- the same engine behind OTP's own debugger. This module finds whichever
--- adapter is installed, checks it, and hands out ready-made recipes.
---
--- The nvim-dap adapter ids here are `edb` and `els_dap`; EDB's VS Code-side
--- type `erlang-edb` is client-side routing and is not needed by the server.
---@module 'dap.erlang'

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels

local M = {}

local SOURCE = 'erlang'

---@type string[]
local ROOT_MARKERS = {
    'rebar.config',
    'rebar.config.script',
    'rebar.lock',
    'Makefile',
    '.git',
}

---@class ErlangAdapterSpec
---@field env_var string environment variable holding an explicit path
---@field g_var string vim.g variable holding an explicit path
---@field exe_names string[] executable names probed on PATH and in mason bin

---@type table<string, ErlangAdapterSpec>
local ADAPTER_SPECS = {
    edb = {
        env_var = 'NVIM_EDB_PATH',
        g_var = 'edb_path',
        exe_names = {
            'edb',
        },
    },
    els_dap = {
        env_var = 'NVIM_ELS_DAP_PATH',
        g_var = 'els_dap_path',
        exe_names = {
            'els_dap',
        },
    },
}

---@type table<string, string[]>
local WELL_KNOWN_PATHS = {
    edb = {
        '/usr/local/bin/edb',
    },
    els_dap = {
        '/usr/local/bin/els_dap',
    },
}

---@class ErlangState
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

---@param spec ErlangAdapterSpec
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

---@param which string 'edb' or 'els_dap'
---@return string?
local function find_adapter(which)
    if state.paths[which] ~= nil then
        return state.paths[which]
    end

    local spec = ADAPTER_SPECS[which]

    if spec == nil then
        return nil
    end

    local path = find_binary(spec, WELL_KNOWN_PATHS[which] or {})

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
    return which == 'edb' or which == 'els_dap'
end

---@type table<string, table>
M.adapters = {
    edb = {
        name = 'edb',
        type = 'executable',
        command = adapter_command('edb', 'edb'),
        args = {
            'dap',
        },
        options = {
            source_filetype = 'erlang',
        },
    },
    els_dap = {
        name = 'els_dap',
        type = 'executable',
        command = adapter_command('els_dap', 'els_dap'),
        args = {},
        options = {
            source_filetype = 'erlang',
        },
    },
}

---@param which string 'edb' or 'els_dap'
---@return table?, string?
function M.resolve_adapter(which)
    if not known_adapter(which) then
        return nil, ("unknown Erlang debug adapter: '%s' (expected 'edb' or 'els_dap')"):format(tostring(which))
    end

    local path = find_adapter(which)

    if path == nil then
        local spec = ADAPTER_SPECS[which]

        return nil, ("Erlang debug adapter '%s' not found; set %s=/path/to/adapter"):format(which, spec.env_var)
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
local function build_edb_launch(opts)
    local args, err = validate_args(opts.args)

    if args == nil then
        return nil, err
    end

    --
    -- EDB launches a BEAM node itself (`run`, via open_port()); the first
    -- argument is the node executable, e.g. `erl` with `-sname` after it.
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
local function build_els_dap_launch(opts)
    local args, err = validate_args(opts.args)

    if args == nil then
        return nil, err
    end

    --
    -- els_dap spawns `program` itself: the documented dap-mode recipe runs
    -- `rebar3 shell` through it.
    --
    return {
        name = opts.name or 'els_dap: Launch',
        type = 'els_dap',
        request = 'launch',
        program = opts.program,
        args = args,
        cwd = opts.cwd or project_root(),
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

    local which = opts.adapter or 'edb'

    if which == 'edb' then
        return build_edb_launch(opts)
    end

    if which == 'els_dap' then
        return build_els_dap_launch(opts)
    end

    return nil, ("build_launch: unknown adapter '%s' (expected 'edb' or 'els_dap')"):format(tostring(which))
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
    erlang = {
        {
            name = 'EDB: Launch node',
            type = 'edb',
            request = 'launch',
            run = {
                cwd = function()
                    return project_root()
                end,
                args = {
                    'erl',
                    '-name',
                    'debuggee@localhost',
                },
            },
            config = {
                nameDomain = 'longnames',
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
        {
            name = 'els_dap: rebar3 shell',
            type = 'els_dap',
            request = 'launch',
            program = 'rebar3',
            args = {
                'shell',
            },
            cwd = function()
                return project_root()
            end,
        },
    },
}

local function check_health()
    local edb = find_adapter('edb')
    local els_dap = find_adapter('els_dap')

    local messages = {
        'Erlang DAP (EDB + els_dap)',
        '',
        'edb: ' .. (edb or 'not found'),
        'els_dap: ' .. (els_dap or 'not found'),
        'project root: ' .. project_root(),
    }

    if edb == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'EDB missing: build from source with'
        messages[#messages + 1] = 'rebar3 escriptize (-> _build/default/bin/edb),'
        messages[#messages + 1] = 'or set NVIM_EDB_PATH=/path/to/edb'
    else
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'note: attach targets must run with the +D'
        messages[#messages + 1] = 'flag; EDB adds +D to ERL_AFLAGS on launch'
    end

    if els_dap == nil then
        messages[#messages + 1] = ''
        messages[#messages + 1] = 'els_dap missing: build ErlangLS with'
        messages[#messages + 1] = 'rebar3 as dap escriptize'
        messages[#messages + 1] = '(-> _build/dap/bin/els_dap),'
        messages[#messages + 1] = 'or set NVIM_ELS_DAP_PATH=/path/to/els_dap'
    end

    local ok = edb ~= nil or els_dap ~= nil
    notify(table.concat(messages, '\n'), ok and levels.INFO or levels.WARN)
end

---@type table<string, DebugCommand>
M.commands = {
    ErlangDebugCheck = {
        callback = function()
            check_health()
        end,
        desc = 'Check Erlang DAP configuration',
    },
}

---@type table<string, DebugMapping>
M.mappings = {
    erlang_check = {
        lhs = '<leader>dErc',
        mode = 'n',
        rhs = function()
            check_health()
        end,
        desc = 'Erlang DAP: Check configuration',
    },
}

---@param opts? table user overrides; honours `opts.edb_path` and `opts.els_dap_path`
function M.setup(opts)
    opts = opts or {}

    if nonempty_string(opts.edb_path) then
        state.paths.edb = normalize(fn.expand(opts.edb_path))
    end

    if nonempty_string(opts.els_dap_path) then
        state.paths.els_dap = normalize(fn.expand(opts.els_dap_path))
    end

    local edb = find_adapter('edb')

    if edb ~= nil then
        M.adapters.edb.command = edb
        M.adapters.edb.missing_message = nil
    else
        -- Defer the nag: surfaced by Session.spawn when a session starts.
        M.adapters.edb.missing_message = table.concat({
            'EDB was not found.',
            '',
            'Build from source: rebar3 escriptize',
            '(_build/default/bin/edb), or set:',
            'NVIM_EDB_PATH=/path/to/edb',
        }, '\n')
    end

    local els_dap = find_adapter('els_dap')

    if els_dap ~= nil then
        M.adapters.els_dap.command = els_dap
        M.adapters.els_dap.missing_message = nil
    else
        -- Defer the nag: surfaced by Session.spawn when a session starts.
        M.adapters.els_dap.missing_message = table.concat({
            'els_dap was not found.',
            '',
            'Build ErlangLS with: rebar3 as dap escriptize',
            '(_build/dap/bin/els_dap), or set:',
            'NVIM_ELS_DAP_PATH=/path/to/els_dap',
        }, '\n')
    end
end

---@return string?
function M.edb_path()
    return find_adapter('edb')
end

---@return string?
function M.els_dap_path()
    return find_adapter('els_dap')
end

return M
