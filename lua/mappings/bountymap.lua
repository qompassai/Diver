-- Bug-bounty pipeline keymaps; leader accelerators for the :Bounty* commands.
-- SPDX-License-Identifier: Apache-2.0
local core = require('mappings._core')

local M = {}
local OWNER = 'bountymap'

---BountyReconCancel needs a run id: prompt instead of leaving it unmapped.
local function prompt_cancel()
    vim.ui.input({ prompt = 'Recon run id to cancel: ' }, function(id)
        if id ~= nil and id ~= '' then
            vim.cmd('BountyReconCancel ' .. vim.fn.escape(id, ' \\'))
        end
    end)
end

---BountyApprove needs kind + target: pick the kind, then prompt the target.
local function prompt_approve()
    vim.ui.select({ 'scope', 'finding', 'submission' }, { prompt = 'Gate kind:' }, function(kind)
        if kind == nil then
            return
        end
        vim.ui.input({ prompt = 'Target slug: ' }, function(target)
            if target ~= nil and target ~= '' then
                vim.cmd('BountyApprove ' .. kind .. ' ' .. vim.fn.escape(target, ' \\'))
            end
        end)
    end)
end

function M.setup()
    M.teardown()
    core.install(OWNER, 0, {
        { lhs = '<Leader>ss', rhs = '<Cmd>BountyScope<CR>', desc = 'Bounty: file program scope' },
        { lhs = '<Leader>sr', rhs = '<Cmd>BountyRecon<CR>', desc = 'Bounty: start recon run' },
        { lhs = '<Leader>st', rhs = '<Cmd>BountyReconStatus<CR>', desc = 'Bounty: recon run status' },
        { lhs = '<Leader>sx', rhs = prompt_cancel, desc = 'Bounty: cancel recon run' },
        { lhs = '<Leader>sp', rhs = '<Cmd>BountyProfile<CR>', desc = 'Bounty: program profiles' },
        { lhs = '<Leader>sa', rhs = prompt_approve, desc = 'Bounty: approve a gate' },
        { lhs = '<Leader>sg', rhs = '<Cmd>BountyReport<CR>', desc = 'Bounty: generate report' },
        { lhs = '<Leader>su', rhs = '<Cmd>BountySubmit<CR>', desc = 'Bounty: preview submission' },
        { lhs = '<Leader>si', rhs = '<Cmd>BountyIndex<CR>', desc = 'Bounty: program/report index' },
        { lhs = '<Leader>so', rhs = '<Cmd>BountyTools<CR>', desc = 'Bounty: recon tool availability' },
    })
end

function M.teardown()
    core.teardown(OWNER)
end

return M
