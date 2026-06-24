#!/usr/bin/env lua

-- /qompassai/Diver/lua/utils/sf/mappings.lua
-- Qompass AI Salesforce Mappings
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
function M.attach(bufnr)
    local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            noremap = true,
            silent = true,
            desc = desc,
        })
    end
    map('n', '<leader>sfd', '<cmd>SfDeployFile<cr>', 'SF: deploy file')
    map('n', '<leader>sfD', '<cmd>SfDeployAll<cr>', 'SF: deploy project')
    map('n', '<leader>sfr', '<cmd>SfRetrieveFile<cr>', 'SF: retrieve file')
    map('n', '<leader>sfR', '<cmd>SfRetrieveAll<cr>', 'SF: retrieve project')
    map('n', '<leader>sf=', '<cmd>SfDiffFile<cr>', 'SF: diff vs org')
    map('n', '<leader>sfs', '<cmd>SfSmart<cr>', 'SF: smart action')
    map('n', '<leader>sfa', '<cmd>SfApexRun<cr>', 'SF: run .apex file')
    map('v', '<leader>sfa', '<cmd>SfApexRunSelection<cr>', 'SF: run selection')
    map('n', '<leader>sfi', '<cmd>SfApexRunInteractive<cr>', 'SF: apex REPL')
    map('n', '<leader>sfl', '<cmd>SfTailLog<cr>', 'SF: tail logs')
    map('n', '<leader>sfL', '<cmd>SfLogList<cr>', 'SF: list logs')
    map('n', '<leader>sft', '<cmd>SfRunCurrentTestClass<cr>', 'SF: run test class')
    map('n', '<leader>sfT', '<cmd>SfRunLocalTests<cr>', 'SF: run local tests')
    map('n', '<leader>sfm', '<cmd>SfRunTestMethod<cr>', 'SF: run test method')
    map('n', '<leader>sfo', '<cmd>SfOrgOpen<cr>', 'SF: open org')
    map('n', '<leader>sfO', '<cmd>SfOrgDisplay<cr>', 'SF: org display')
end

return M
