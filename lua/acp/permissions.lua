-- A user-visible disclosure decision, bound to one exact payload and destination.
-- Copyright (C) 2025 Qompass AI, All rights reserved
local util = require('acp.util')
local M = {}
local pending = {}
local epoch = 0

function M.confirm(title, payload, callback)
    if vim.tbl_count(pending) >= 4 then
        return nil, 'Disclosure dialog limit'
    end
    local key, err = util.id()
    if not key then
        return nil, err
    end
    local finished = false
    local current_epoch = epoch
    local function finish(allowed)
        if finished then
            return
        end
        finished = true
        util.close_timer(pending[key])
        pending[key] = nil
        callback(allowed and current_epoch == epoch)
    end
    pending[key] = util.timer(120000, function()
        finish(false)
    end)
    if not require('acp.ui').inspect(title, payload) then
        finish(false)
        return nil, 'The full disclosure payload could not be displayed'
    end
    vim.ui.select({ 'Cancel', 'Send the displayed payload' }, { prompt = title }, function(choice)
        finish(choice == 'Send the displayed payload')
    end)
    return {
        cancel = function()
            finish(false)
        end,
    }
end

function M.stop_all()
    epoch = epoch + 1
    for key, timer in pairs(pending) do
        util.close_timer(timer)
        pending[key] = nil
    end
end
return M
