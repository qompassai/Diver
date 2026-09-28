-- /qompassai/Diver/lua/dev/bootdev/commands.lua
-- Qompass AI bootdev-local Launcher Commands (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- :Bootdev opens the `bootdev-local` CLI (offline Boot.dev lessons) in a
-- terminal split. Lesson files open in nvim via the tool's own
-- -code-editor / -md-editor flags; the module is a thin launcher and
-- never reimplements the lesson UI.
--
--   :Bootdev <lesson-URL>      Open a lesson (scaffolds ./Chapter N/Lesson M/)
--   :Bootdev <lesson-URL> ...  Extra args pass straight through as argv
--
-- Arguments after :Bootdev pass straight through to bootdev-local as argv
-- (never a shell string). They are split on whitespace; paths containing
-- spaces are not supported. Flags must come from the tool itself; Go's
-- flag parser stops at the first positional, so -code-editor/-md-editor
-- are always placed before the user's args.

local api = vim.api

local ARGV_MAX = 32

--- Split raw command args on whitespace into an argv tail.
---@param raw string command.args as given
---@return string[]|nil args, string|nil err
local function split_args(raw)
    local args = {}
    for token in raw:gmatch('%S+') do
        if #args >= ARGV_MAX then
            return nil, 'too many arguments (max ' .. ARGV_MAX .. ')'
        end
        args[#args + 1] = token
    end
    return args, nil
end

---@param extra string[] argv tail appended after the editor flags
local function open_terminal(extra)
    assert(type(extra) == 'table', 'open_terminal expects an argv table')
    local argv = { 'bootdev-local', '-code-editor', 'nvim', '-md-editor', 'nvim' }
    for _, token in ipairs(extra) do
        argv[#argv + 1] = token
    end
    vim.cmd('botright split')
    vim.fn.jobstart(argv, { term = true })
    vim.cmd('startinsert')
end

api.nvim_create_user_command('Bootdev', function(command)
    if vim.fn.executable('bootdev-local') ~= 1 then
        vim.notify(
            'Bootdev: `bootdev-local` not found on PATH (paru -S aur/bootdev-local)',
            vim.log.levels.ERROR
        )
        return
    end
    local args, err = split_args(command.args)
    if err ~= nil then
        vim.notify('Bootdev: ' .. err, vim.log.levels.ERROR)
        return
    end
    open_terminal(args)
end, {
    nargs = '*',
    desc = 'Open bootdev-local (offline Boot.dev lessons) in a terminal split',
})

return true
