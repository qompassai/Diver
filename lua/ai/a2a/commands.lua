-- /qompassai/Diver/lua/ai/a2a/commands.lua
-- Qompass AI A2A User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing surface of the A2A console: list known agents, open
-- the task monitor, cancel work. Requiring this module registers the
-- commands; it starts nothing.

local api = vim.api

local agent_card = require('ai.a2a.agent_card')
local client = require('ai.a2a.client')
local tasks = require('ai.a2a.tasks')
local sdks = require('ai.a2a.sdks')
local ui = require('ai.a2a.ui')

api.nvim_create_user_command('A2aAgents', function()
    local names = agent_card.list()
    if #names == 0 then
        vim.notify('No A2A agents registered', vim.log.levels.WARN)
        return
    end
    local lines = {}
    for _, name in ipairs(names) do
        local card = agent_card.get(name)
        local endpoint = card and client.card_endpoint(card) or nil
        lines[#lines + 1] = name .. '  ' .. (endpoint or '?')
    end
    api.nvim_echo({ { table.concat(lines, '\n'), 'Normal' } }, false, {})
end, { desc = 'List registered A2A agents' })

api.nvim_create_user_command('A2aTasks', function()
    ui.open()
end, { desc = 'Open the A2A task monitor' })

api.nvim_create_user_command('A2aCancel', function(command)
    if command.args == '' then
        tasks.cancel_all()
        vim.notify('All A2A tasks canceled', vim.log.levels.INFO)
        return
    end
    local id = tonumber(command.args)
    if not id then
        vim.notify('A2aCancel expects a task id', vim.log.levels.ERROR)
        return
    end
    if tasks.cancel(id, 'canceled') then
        vim.notify('A2A task ' .. id .. ' canceled', vim.log.levels.INFO)
    else
        vim.notify('No live A2A task ' .. id, vim.log.levels.WARN)
    end
end, {
    nargs = '?',
    desc = 'Cancel one A2A task by id, or all tasks with no argument',
})

api.nvim_create_user_command('A2aSdks', function()
    sdks.install_menu()
end, { desc = 'Open the A2A SDK install menu' })

api.nvim_create_user_command('A2aSdkInstall', function(command)
    local spec = sdks.get(command.args)
    if spec == nil then
        vim.notify('Unknown A2A SDK: ' .. command.args, vim.log.levels.ERROR)
        return
    end
    sdks.install(spec)
end, {
    nargs = 1,
    desc = 'Install one A2A SDK by language (python, typescript, go, java, dotnet)',
    complete = function()
        return { 'python', 'typescript', 'go', 'java', 'dotnet' }
    end,
})

return true
