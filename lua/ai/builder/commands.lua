-- /qompassai/Diver/lua/ai/builder/commands.lua
-- Qompass AI Interactive Application Builder: User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing surface: :AiBuild starts a new interactive session
-- (menu -> pipeline), :AiBuildResume continues the last session from the
-- bounded session file in stdpath('data'). Requiring this module
-- registers the commands and keymaps; it starts no session.
--
-- The <LocalLeader>ab / <LocalLeader>aB keymaps live here rather than in
-- lua/mappings/aimap.lua: aimap's attach() installs buffer-local,
-- LSP-method-gated maps, which is the wrong scope for these global
-- builder commands. Existing maps are never clobbered.

local api = vim.api

local menu = require('ai.builder.menu')
local pipeline = require('ai.builder.pipeline')

---@param result table Pipeline outcome.
local function finish_notification(result)
    assert(type(result) == 'table', 'finish_notification expects a result')
    if result.status == 'done' then
        vim.notify('builder: wrote ' .. #result.created .. ' file(s)', vim.log.levels.INFO)
    elseif result.status == 'aborted' then
        vim.notify('builder: aborted at stage ' .. tostring(result.stage), vim.log.levels.WARN)
    else
        vim.notify('builder: ' .. tostring(result.message), vim.log.levels.ERROR)
    end
end

local function start()
    menu.interactive(function(spec, err)
        if spec == nil then
            vim.notify('builder: ' .. tostring(err), vim.log.levels.WARN)
            return
        end
        pipeline.run(spec, {}, finish_notification)
    end)
end

local function resume()
    local session, load_err = pipeline.load_session()
    if session == nil then
        vim.notify('builder: ' .. tostring(load_err), vim.log.levels.WARN)
        return
    end
    pipeline.resume(session, {}, finish_notification)
end

api.nvim_create_user_command('AiBuild', start, {
    desc = 'Start an interactive application-builder session',
})

api.nvim_create_user_command('AiBuildResume', resume, {
    desc = 'Resume the last builder session',
})

---@param lhs string
---@param command string Ex command name, without the leading ':'.
---@param desc string
local function add_keymap(lhs, command, desc)
    assert(type(lhs) == 'string', 'add_keymap expects a lhs')
    assert(type(command) == 'string', 'add_keymap expects a command')
    if vim.fn.maparg(lhs, 'n') ~= '' then
        return
    end
    vim.keymap.set('n', lhs, '<Cmd>' .. command .. '<CR>', { desc = desc, silent = true })
end

add_keymap('<LocalLeader>ab', 'AiBuild', 'Builder: start interactive session')
add_keymap('<LocalLeader>aB', 'AiBuildResume', 'Builder: resume last session')

return true
