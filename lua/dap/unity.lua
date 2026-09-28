--- Unity game debugger — debug Unity games from Neovim.
---
--- Plain-language version: Unity is a game engine with its own way of running
--- code. This module connects Neovim's debugger to a running Unity editor or
--- player: attach to it, launch DLLs, and browse the compiled scripts. It
--- runs when you start a Unity debug session; it needs a Unity editor around.
---@module 'dap.unity'
-- #################################################################
-- /qompassai/lua/dap/unity.lua
-- Qompass AI Unity
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
-- ~/.config/nvim/lua/dap/unity.lua
local api = vim.api
local fn = vim.fn
local uv = vim.uv
local debug = vim.debug
local M = {}

--- Bound for the `ps` probe; a hung child must not freeze the editor.
local UNITY_COMMAND_TIMEOUT_MS = 15000

--- Cap on Unity process candidates offered for attach.
local UNITY_PROCESS_MATCHES_MAX = 50

---@type table
M.adapter = {
    name = 'coreclr',
    command = 'netcoredbg',
    args = { '--interpreter=vscode' },
}
local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.unity' })
end

local function executable(cmd)
    return fn.executable(cmd) == 1
end

local function input(prompt, default, completion)
    return fn.input(prompt, default or '', completion or '')
end

local function cwd()
    return fn.getcwd()
end

local function current_file()
    return api.nvim_buf_get_name(0)
end

local function file_exists(path)
    return type(path) == 'string' and path ~= '' and uv.fs_stat(path) ~= nil
end

local function is_dir(path)
    local stat = uv.fs_stat(path)
    return stat and stat.type == 'directory' or false
end

local function workspace_root()
    local file = current_file()
    local start = file ~= '' and file or cwd()

    local root = vim.fs.root(start, {
        'Assets',
        'Packages',
        'ProjectSettings',
        '*.sln',
        '.git',
    })

    return root or cwd()
end

local function ensure_adapter()
    if executable(M.adapter.command) then
        return true
    end

    notify(
        ('Unity debugger not found: %s. Install Samsung/netcoredbg and put it in PATH.'):format(
            M.adapter.command
        ),
        vim.log.levels.ERROR
    )
    return false
end

local function start(config)
    if not ensure_adapter() then
        return
    end

    config.type = M.adapter.name
    config.adapter = {
        type = 'executable',
        command = M.adapter.command,
        args = M.adapter.args,
    }
    debug.start(config)
end

local function prompt_args()
    local raw = input('Args: ', '')
    if raw == '' then
        return {}
    end
    return vim.split(raw, '%s+', { trimempty = true })
end

local function prompt_env()
    local env = {}
    while true do
        local key = input('Env key (blank to finish): ', '')
        if key == '' then
            break
        end
        env[key] = input('Env value for ' .. key .. ': ', '')
    end
    return env
end

local function unity_root()
    local root = workspace_root()

    local assets = vim.fs.joinpath(root, 'Assets')

    local settings = vim.fs.joinpath(root, 'ProjectSettings')

    if is_dir(assets) and is_dir(settings) then
        return root
    end

    return root
end

local function dll_candidates(root)
    local product = fn.fnamemodify(root, ':t')
    return {
        vim.fs.joinpath(root, 'Library', 'ScriptAssemblies', 'Assembly-CSharp.dll'),
        vim.fs.joinpath(root, 'Library', 'ScriptAssemblies', 'Assembly-CSharp-Editor.dll'),
        vim.fs.joinpath(root, 'Build', product .. '.dll'),
        vim.fs.joinpath(root, product .. '.dll'),
    }
end

local function guess_unity_dll()
    local root = unity_root()
    for _, dll in ipairs(dll_candidates(root)) do
        if file_exists(dll) then
            return dll
        end
    end
    return vim.fs.joinpath(root, 'Library', 'ScriptAssemblies', 'Assembly-CSharp.dll')
end

local function prompt_program()
    local dll = input('Path to Unity managed DLL: ', guess_unity_dll(), 'file')
    if dll == '' then
        return nil
    end
    return dll
end

---@return integer?
local function pick_pid_from_ps()
    local result = vim.system({ 'ps', '-eo', 'pid=,comm=' }, { text = true }):wait(
        UNITY_COMMAND_TIMEOUT_MS
    )

    if result.code ~= 0 or not result.stdout or result.stdout == '' then
        return nil
    end

    ---@type { pid: integer, comm: string }[]
    local matches = {}

    for line in result.stdout:gmatch('[^\r\n]+') do
        if #matches >= UNITY_PROCESS_MATCHES_MAX then
            break
        end

        local pid, comm = line:match('^%s*(%d+)%s+(%S+)')

        if pid ~= nil and comm ~= nil then
            local lower = comm:lower()

            if
                lower:find('unity', 1, true) ~= nil
                or lower:find('mono', 1, true) ~= nil
                or lower:find('dotnet', 1, true) ~= nil
            then
                matches[#matches + 1] = { pid = tonumber(pid), comm = comm }
            end
        end
    end

    if #matches == 0 then
        return nil
    end

    local choices = { 'Select Unity/.NET process:' }
    for i, match in ipairs(matches) do
        choices[#choices + 1] = string.format('%d. %d %s', i, match.pid, match.comm)
    end

    local idx = fn.inputlist(choices)
    if idx < 1 or idx > #matches then
        return nil
    end

    return matches[idx].pid
end

---Launch a managed Unity DLL under the debugger.
---@return nil
function M.launch_dll()
    local program = prompt_program()
    if not program or program == '' then
        notify('Managed DLL path is required', vim.log.levels.ERROR)
        return
    end

    start({
        request = 'launch',
        name = 'Unity launch managed DLL',
        program = program,
        cwd = unity_root(),
        args = prompt_args(),
        env = prompt_env(),
        stopAtEntry = false,
        console = 'internalConsole',
    })
end

---Attach the debugger to a Unity process by PID.
---@return nil
function M.attach_pid()
    local pid = pick_pid_from_ps()
    if not pid then
        pid = tonumber(input('PID: ', ''))
    end

    if not pid then
        notify('Invalid PID', vim.log.levels.ERROR)
        return
    end

    start({
        request = 'attach',
        name = 'Unity attach PID',
        processId = pid,
        cwd = unity_root(),
    })
end

---Attach the debugger to a Unity player over the network.
---@return nil
function M.attach_server()
    local port = tonumber(input('Port: ', '4711'))
    if not port then
        notify('Invalid port', vim.log.levels.ERROR)
        return
    end

    debug.start({
        type = 'unity-server',
        request = 'attach',
        name = 'Unity attach server',
        host = input('Host: ', '127.0.0.1'),
        port = port,
    })
end

---Open the folder with Unity's compiled script assemblies.
---@return nil
function M.open_script_assemblies()
    local root = unity_root()
    local dir = vim.fs.joinpath(root, 'Library', 'ScriptAssemblies')

    if not is_dir(dir) then
        notify('Library/ScriptAssemblies not found', vim.log.levels.WARN)
        return
    end

    vim.cmd('edit ' .. fn.fnameescape(dir))
end

---Show Unity project/editor info for the current session.
---@return nil
function M.unity_info()
    local root = unity_root()
    local lines = {
        'Unity DAP notes',
        '',
        'Project root: ' .. root,
        'Managed assembly guess: ' .. guess_unity_dll(),
        '',
        'Recommended workflow:',
        '- Use your C# LSP for code intelligence.',
        '- Let Unity generate .sln/.csproj files.',
        '- Use :UnityDapAttach for a running Unity-related process.',
        '- Use :UnityDapLaunch if you specifically want to launch a managed DLL.',
        '',
        'Adapter:',
        '- netcoredbg --interpreter=vscode',
    }

    vim.cmd('new')
    local buf = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].filetype = 'markdown'
end

local setup_done = false

---Register the Unity debug commands. Idempotent.
---@return nil
function M.setup()
    if setup_done then
        return
    end

    setup_done = true

    api.nvim_create_user_command('UnityDapLaunch', M.launch_dll, {
        desc = 'Launch Unity managed DLL with netcoredbg',
    })

    api.nvim_create_user_command('UnityDapAttach', M.attach_pid, {
        desc = 'Attach to running Unity/.NET process',
    })

    api.nvim_create_user_command('UnityDapServer', M.attach_server, {
        desc = 'Attach to Unity debug server/port',
    })

    api.nvim_create_user_command('UnityScriptAssemblies', M.open_script_assemblies, {
        desc = 'Open Unity Library/ScriptAssemblies directory',
    })

    api.nvim_create_user_command('UnityDapInfo', M.unity_info, {
        desc = 'Show Unity DAP info',
    })

    vim.keymap.set('n', '<leader>ul', M.launch_dll, { desc = 'Unity DAP launch' })
    vim.keymap.set('n', '<leader>ua', M.attach_pid, { desc = 'Unity DAP attach' })
    vim.keymap.set('n', '<leader>us', M.attach_server, { desc = 'Unity DAP server' })
    vim.keymap.set('n', '<leader>ui', M.unity_info, { desc = 'Unity DAP info' })
end

return M
