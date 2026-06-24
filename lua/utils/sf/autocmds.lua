#!/usr/bin/env lua

-- autocmds.lua
-- Qompass AI
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------

local mappings = require('utils.sf.mappings')
local util = require('utils.sf.util')

local M = {}

function M.setup()
    local group = vim.api.nvim_create_augroup('SalesforceUtils', {
        clear = true,
    })
    vim.api.nvim_create_autocmd('BufEnter', {
        group = group,
        pattern = {
            '*.apex',
            '*.cls',
            '*.css',
            '*.trigger',
            '*.js',
            '*.html',
            '*.xml',
        },
        callback = function(ev)
            if util.in_sf_project() then
                mappings.attach(ev.buf)
            end
        end,
        desc = 'Attach Salesforce keymaps in Salesforce project buffers',
    })
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        pattern = {
            '*.cls',
            '*.trigger',
        },
        callback = function()
            if util.in_sf_project() then
                util.notify('Saved — deploy with <leader>sfd', vim.log.levels.INFO)
            end
        end,
        desc = 'Remind user to deploy after saving Apex',
    })
end

return M