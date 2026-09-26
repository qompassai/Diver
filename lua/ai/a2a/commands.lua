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
local orchestrator = require('ai.a2a.orchestrator')

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

-- Cross-language orchestration -------------------------------------------
-- A2aOrchestrate prompts for a task, then offers the registry
-- languages one at a time ('done' finishes the multi-select), then
-- the agent base URL, and fans the task out across the chosen SDK
-- drivers. Results land in a scratch buffer, one block per agent.

local orchestrate_langs = { 'python', 'typescript', 'go', 'java', 'dotnet' }

---@param done fun(langs: string[])
local function orchestrate_pick_langs(done)
    local picked = {}
    local function step()
        local items = {}
        for _, lang in ipairs(orchestrate_langs) do
            if not vim.tbl_contains(picked, lang) then
                items[#items + 1] = lang
            end
        end
        items[#items + 1] = 'done'
        local prompt = 'A2A orchestrate language (' .. #picked .. ' picked):'
        vim.ui.select(items, { prompt = prompt }, function(choice)
            if choice == nil or choice == 'done' then
                done(picked)
                return
            end
            picked[#picked + 1] = choice
            step()
        end)
    end
    step()
end

---@param results A2aOrchestratedResult[]
local function orchestrate_show(results)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(buf, 'a2a://orchestrate')
    vim.bo[buf].filetype = 'a2a-orchestrate'
    local lines = { 'A2A orchestration results  (q to close)', '' }
    for _, r in ipairs(results) do
        local status = r.ok and 'OK' or 'FAIL'
        lines[#lines + 1] = string.format('[%s] %-10s %dms', status, r.lang, r.elapsed_ms)
        if r.ok then
            lines[#lines + 1] = '  ' .. ((r.result or ''):gsub('\n', ' | '):sub(1, 200))
        else
            lines[#lines + 1] = '  error: ' .. (r.error or '?')
        end
        lines[#lines + 1] = ''
    end
    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
    local width = math.min(100, math.floor(vim.o.columns * 0.8))
    local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.7))
    api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' A2A orchestration ',
    })
end

api.nvim_create_user_command('A2aOrchestrate', function()
    vim.ui.input({ prompt = 'Orchestrate task: ' }, function(task)
        if task == nil or task == '' then
            return
        end
        orchestrate_pick_langs(function(langs)
            if #langs == 0 then
                vim.notify('A2aOrchestrate: no languages selected', vim.log.levels.WARN)
                return
            end
            vim.ui.input({ prompt = 'Agent base URL: ' }, function(base_url)
                if base_url == nil or base_url == '' then
                    return
                end
                local started, err = orchestrator.orchestrate({
                    task = task,
                    langs = langs,
                    base_url = base_url,
                    context = {},
                }, function(results)
                    vim.notify('A2A orchestration complete', vim.log.levels.INFO)
                    orchestrate_show(results)
                end)
                if not started then
                    vim.notify('A2aOrchestrate: ' .. tostring(err), vim.log.levels.ERROR)
                end
            end)
        end)
    end)
end, { desc = 'Fan a task out across A2A SDK drivers by language' })

return true
