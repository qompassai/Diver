#!/usr/bin/env lua5.1
-- /qompassai/Diver/lua/utils/sf/picker.lua
-- Qompass AI Salesforce Command Picker
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'utils.sf.picker'
local M = {}
function M.commands()
    local ok, fzf = pcall(require, 'fzf-lua')
    if not ok then
        vim.notify('fzf-lua is not available', vim.log.levels.ERROR)
        return
    end
    local commands = require('utils.sf.commands').get_commands()
    local entries = {}
    for _, item in ipairs(commands) do
        local desc = ''
        if item.opts and item.opts.desc then
            desc = item.opts.desc
        end
        table.insert(entries, string.format('%-36s %s', item.name, desc))
    end
    fzf.fzf_exec(entries, {
        prompt = 'Salesforce Commands> ',
        fzf_opts = {
            ['--ansi'] = '',
            ['--delimiter'] = ' ',
            ['--no-multi'] = '',
            ['--preview-window'] = 'down,3,wrap',
        },
        preview = function(entry)
            local name = entry:match('^(%S+)')
            for _, item in ipairs(commands) do
                if item.name == name then
                    local lines = {
                        'Command: ' .. item.name,
                        'Description: ' .. ((item.opts and item.opts.desc) or ''),
                        'Arguments: ' .. tostring((item.opts and item.opts.nargs) or 0),
                    }
                    return table.concat(lines, '\n')
                end
            end
            return entry
        end,
        actions = {
            ['default'] = function(selected)
                if not selected or not selected[1] then
                    return
                end
                local name = selected[1]:match('^(%S+)')
                if name and name ~= '' then
                    vim.cmd(name)
                end
            end,
        },
    })
end

vim.api.nvim_create_user_command('SfCommands', function()
    require('utils.sf.picker').commands()
end, {
    desc = 'Browse Salesforce commands with fzf-lua',
})
return M