-- #################################################################
-- /qompassai/lua/scip/ui.lua
-- Qompass AI SCIP UI
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################
local api = vim.api
local fn = vim.fn
local config = require('scip.config')
local registry = require('scip.registry')
local root = require('scip.root')
local utils = require('scip.utils')
local M = {}

---Emit a SCIP notification when notifications are enabled.
---@param message string
---@param level? integer
function M.notify(message, level)
    if not config.get().notify then
        return
    end

    vim.notify(message, level or vim.log.levels.INFO, {
        title = 'SCIP',
    })
end

---Display successful command output in a scratch split.
---@param title string
---@param text string
---@param filetype? string
function M.show_output(title, text, filetype)
    local bufnr = api.nvim_create_buf(false, true)

    api.nvim_buf_set_name(bufnr, ('scip://%s/%d'):format(title:gsub('%s+', '-'):lower(), math.floor(vim.uv.hrtime())))

    api.nvim_set_option_value('bufhidden', 'wipe', {
        buf = bufnr,
    })

    api.nvim_set_option_value('swapfile', false, {
        buf = bufnr,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, utils.text_lines(text))

    api.nvim_set_option_value('filetype', filetype or 'text', {
        buf = bufnr,
    })

    api.nvim_set_option_value('modifiable', false, {
        buf = bufnr,
    })

    vim.cmd('botright new')
    api.nvim_win_set_buf(0, bufnr)
end

---Display failed subprocess output using the quickfix list.
---@param title string
---@param result vim.SystemCompleted
function M.show_failure(title, result)
    fn.setqflist({}, 'r', {
        lines = utils.text_lines(utils.system_output(result, true)),
        title = title,
    })

    vim.cmd('botright copen')
end

---Show indexer support/readiness for the current buffer.
function M.coverage()
    local bufnr = api.nvim_get_current_buf()
    local current_filetype = vim.bo[bufnr].filetype

    local lines = {
        'SCIP indexer coverage',
        '',
        'Current filetype: ' .. (current_filetype ~= '' and current_filetype or '<none>'),
        '',
    }

    local matches = {}

    for _, name in ipairs(registry.names()) do
        local indexer = registry.get(name)

        if indexer ~= nil then
            local project_root = root.resolve(bufnr, indexer.markers)

            local ctx = require('scip.context').new(name, bufnr, project_root)

            local command = utils.resolve_command(indexer.command, ctx)

            local readiness = command ~= nil and utils.executable(command) and 'ready' or 'missing'

            lines[#lines + 1] = string.format(
                '%-12s %-8s %-24s %s',
                name,
                readiness,
                command or '<invalid command>',
                table.concat(registry.filetypes(indexer), ', ')
            )

            if indexer.filetypes[current_filetype] == true then
                matches[#matches + 1] = name
            end
        end
    end

    lines[#lines + 1] = ''

    if #matches == 0 then
        lines[#lines + 1] = 'No SCIP indexer is configured for the current filetype.'
    else
        lines[#lines + 1] = 'Current filetype indexer: ' .. table.concat(matches, ', ')
    end

    M.show_output('SCIP coverage', table.concat(lines, '\n'))
end

---Create native :Scip* commands.
---
---The requires inside callbacks are intentionally lazy. ui.lua is required by
---index.lua for notifications/output, so requiring index.lua at module load
---time here would introduce a circular dependency.
function M.setup_commands()
    api.nvim_create_user_command('ScipCancel', function()
        require('scip.index').cancel()
    end, {
        desc = 'Cancel the active SCIP indexer',
        force = true,
    })

    api.nvim_create_user_command('ScipCoverage', M.coverage, {
        desc = 'Show SCIP language coverage and readiness',
        force = true,
    })

    api.nvim_create_user_command('ScipHealth', function()
        require('scip.health').check()
    end, {
        desc = 'Run native SCIP health checks',
        force = true,
    })

    api.nvim_create_user_command('ScipIndex', function(command)
        require('scip.index').run(command.args)
    end, {
        complete = function()
            return registry.names()
        end,
        desc = 'Generate a SCIP index for the current project',
        force = true,
        nargs = '?',
    })

    api.nvim_create_user_command('ScipLint', function()
        require('scip.index').lint()
    end, {
        desc = 'Validate the current project SCIP index',
        force = true,
    })

    api.nvim_create_user_command('ScipPrint', function()
        require('scip.index').print()
    end, {
        desc = 'Open the current SCIP index as JSON',
        force = true,
    })

    api.nvim_create_user_command('ScipSnapshot', function()
        require('scip.index').snapshot()
    end, {
        desc = 'Create a human-readable SCIP snapshot',
        force = true,
    })

    api.nvim_create_user_command('ScipStats', function()
        require('scip.index').stats()
    end, {
        desc = 'Show statistics for the current SCIP index',
        force = true,
    })

    api.nvim_create_user_command('ScipStatus', function()
        require('scip.index').status()
    end, {
        desc = 'Show SCIP index/indexer status',
        force = true,
    })
end

return M
