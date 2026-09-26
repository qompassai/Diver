-- /qompassai/Diver/lua/ai/herd/commands.lua
-- Qompass AI Herd User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing surface of the herd runtime: spawn, prompt, kill and
-- restore agents, open the status dashboard, and manage remote machines.
-- Requiring this module registers nothing; M.setup() creates the
-- commands. Every command defers all work -- including sibling requires --
-- to its callback, so setup itself performs no I/O.

local M = {}

local api = vim.api

local setup_done = false

---Let the user pick one running agent, then hand its name to on_pick.
---@param prompt_text string
---@param on_pick fun(name: string)
local function pick_agent(prompt_text, on_pick)
    local herd = require('ai.herd')
    local list = herd.agents()
    if #list == 0 then
        vim.notify('herd: no agents running', vim.log.levels.WARN)
        return
    end
    vim.ui.select(list, {
        prompt = prompt_text,
        format_item = function(item)
            return item.name .. ' (' .. item.cli .. ')'
        end,
    }, function(item)
        if item == nil then
            return
        end
        on_pick(item.name)
    end)
end

---Notify a command failure in one canonical shape.
---@param what string command name for the message
---@param err any
local function notify_failed(what, err)
    vim.notify(what .. ' failed: ' .. tostring(err), vim.log.levels.ERROR)
end

---@param cli_name string
---@param name string
---@param task string?
---@param cwd string?
local function finish_spawn(cli_name, name, task, cwd)
    local herd = require('ai.herd')
    local ok, err = herd.spawn_agent(name, cli_name, task, cwd)
    if not ok then
        notify_failed('HerdSpawn', err)
        return
    end
    vim.notify('herd: agent spawned: ' .. name, vim.log.levels.INFO)
end

---@param cli_name string
---@param name string
---@param task string?
local function ask_cwd(cli_name, name, task)
    vim.ui.input({
        prompt = 'Working directory: ',
        default = vim.fn.getcwd(),
    }, function(cwd)
        if cwd == nil then
            return
        end
        finish_spawn(cli_name, name, task, cwd ~= '' and cwd or nil)
    end)
end

---@param cli_name string
---@param name string
local function ask_task(cli_name, name)
    vim.ui.input({ prompt = 'Task (optional): ' }, function(task)
        if task == nil then
            return
        end
        ask_cwd(cli_name, name, task ~= '' and task or nil)
    end)
end

---@param cli_name string
---@param cli_label string
local function ask_agent_name(cli_name, cli_label)
    vim.ui.input({
        prompt = 'Agent name (' .. cli_label .. '): ',
        default = cli_name .. '-1',
    }, function(name)
        if name == nil or name == '' then
            return
        end
        ask_task(cli_name, name)
    end)
end

local function spawn_interactive()
    local catalog = require('ai.herd.catalog')
    local detected = catalog.detect_all()
    if #detected == 0 then
        vim.notify('herd: no agent CLIs installed', vim.log.levels.ERROR)
        return
    end
    vim.ui.select(detected, {
        prompt = 'Agent CLI:',
        format_item = function(item)
            return item.label
        end,
    }, function(item)
        if item == nil then
            return
        end
        ask_agent_name(item.name, item.label)
    end)
end

---@param name string
---@param text string
local function finish_prompt(name, text)
    local herd = require('ai.herd')
    local ok, err = herd.prompt_agent(name, text)
    if not ok then
        notify_failed('HerdPrompt', err)
        return
    end
    vim.notify('herd: prompt sent to ' .. name, vim.log.levels.INFO)
end

local function prompt_interactive()
    pick_agent('Prompt which agent?', function(name)
        vim.ui.input({ prompt = 'Prompt for ' .. name .. ': ' }, function(text)
            if text == nil or text == '' then
                return
            end
            finish_prompt(name, text)
        end)
    end)
end

---@param name string
local function finish_kill(name)
    local herd = require('ai.herd')
    local ok, err = herd.kill_agent(name)
    if not ok then
        notify_failed('HerdKill', err)
        return
    end
    vim.notify('herd: agent killed: ' .. name, vim.log.levels.INFO)
end

local function kill_interactive()
    pick_agent('Kill which agent?', function(name)
        vim.ui.select({ 'Yes', 'No' }, {
            prompt = 'Kill agent ' .. name .. '?',
        }, function(choice)
            if choice == 'Yes' then
                finish_kill(name)
            end
        end)
    end)
end

local function restore_interactive()
    local herd = require('ai.herd')
    local restored, errors = herd.restore_layout()
    local msg = 'herd: restored ' .. restored .. ' agents'
    vim.notify(msg, vim.log.levels.INFO)
    for _, err in ipairs(errors) do
        vim.notify('herd: ' .. err, vim.log.levels.WARN)
    end
end

---@return table[]? machines nil (with a warning) when none are registered
local function registered_machines()
    local remotes = require('ai.herd.remotes')
    local machines = remotes.list()
    if #machines == 0 then
        vim.notify('herd: no remote machines registered', vim.log.levels.WARN)
        return nil
    end
    return machines
end

local function machines_list()
    local remotes = require('ai.herd.remotes')
    local machines = remotes.list()
    if #machines == 0 then
        vim.notify('herd: no remote machines registered', vim.log.levels.INFO)
        return
    end
    local lines = {}
    for _, machine in ipairs(machines) do
        local line = machine.target
        if machine.diver_path ~= nil and machine.diver_path ~= '' then
            line = line .. ' (' .. machine.diver_path .. ')'
        end
        lines[#lines + 1] = line
    end
    local text = 'herd machines:\n' .. table.concat(lines, '\n')
    vim.notify(text, vim.log.levels.INFO)
end

---@param target string
---@param diver_path string?
local function finish_add(target, diver_path)
    local remotes = require('ai.herd.remotes')
    local ok, err = remotes.add(target, diver_path)
    if not ok then
        notify_failed('HerdMachines', err)
        return
    end
    vim.notify('herd: machine added: ' .. target, vim.log.levels.INFO)
end

local function machines_add()
    vim.ui.input({ prompt = 'Machine target (user@host): ' }, function(target)
        if target == nil or target == '' then
            return
        end
        vim.ui.input({
            prompt = 'Diver path on machine (optional): ',
        }, function(diver_path)
            if diver_path == nil then
                return
            end
            finish_add(target, diver_path ~= '' and diver_path or nil)
        end)
    end)
end

local function machines_remove()
    local machines = registered_machines()
    if machines == nil then
        return
    end
    local remotes = require('ai.herd.remotes')
    vim.ui.select(machines, {
        prompt = 'Remove machine:',
        format_item = function(item)
            return item.target
        end,
    }, function(item)
        if item == nil then
            return
        end
        local ok, err = remotes.remove(item.target)
        if not ok then
            notify_failed('HerdMachines', err)
            return
        end
        local msg = 'herd: machine removed: ' .. item.target
        vim.notify(msg, vim.log.levels.INFO)
    end)
end

local function machines_query()
    local machines = registered_machines()
    if machines == nil then
        return
    end
    local remotes = require('ai.herd.remotes')
    vim.ui.select(machines, {
        prompt = 'Query machine:',
        format_item = function(item)
            return item.target
        end,
    }, function(item)
        if item == nil then
            return
        end
        local result, err = remotes.query(item.target, { cmd = 'list' })
        if result == nil then
            notify_failed('HerdMachines', err)
            return
        end
        vim.notify(vim.json.encode(result), vim.log.levels.INFO)
    end)
end

local function machines_menu()
    vim.ui.select({ 'List', 'Add', 'Remove', 'Query status' }, {
        prompt = 'Herd machines:',
    }, function(choice)
        if choice == 'List' then
            machines_list()
        elseif choice == 'Add' then
            machines_add()
        elseif choice == 'Remove' then
            machines_remove()
        elseif choice == 'Query status' then
            machines_query()
        end
    end)
end

---Register the :Herd* user commands. Idempotent; performs no I/O: every
---command defers its requires and its work to its callback.
---@return boolean ok
function M.setup()
    if setup_done then
        return true
    end
    setup_done = true
    api.nvim_create_user_command('HerdSpawn', spawn_interactive, {
        desc = 'Spawn a herd agent (interactive)',
    })
    api.nvim_create_user_command('HerdStatus', function()
        require('ai.herd.ui').open()
    end, {
        desc = 'Open the herd status dashboard',
    })
    api.nvim_create_user_command('HerdPrompt', prompt_interactive, {
        desc = 'Send a prompt to a herd agent',
    })
    api.nvim_create_user_command('HerdKill', kill_interactive, {
        desc = 'Kill a herd agent (confirmed)',
    })
    api.nvim_create_user_command('HerdRestore', restore_interactive, {
        desc = 'Restore agents from the persisted layout',
    })
    api.nvim_create_user_command('HerdMachines', machines_menu, {
        desc = 'Manage remote herd machines',
    })
    return true
end

return M
