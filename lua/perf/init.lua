---@module 'perf'
---Performance monitors, wired at startup from the root init.lua.
---
---Two self-contained trackers live beside this file:
---  * perf.event_loop_lag - samples the event loop on a timer and
---    toasts on lag spikes. It is ON DEMAND: the sampler starts on
---    the first :PerfLag and stops with :PerfLagStop; nothing runs
---    (and nothing pops up) before that.
---  * perf.autocmd_cost - times autocmd handlers registered through
---    its own register() (:PerfAutocmd). It observes only handlers
---    registered through it, never handlers registered elsewhere.
local M = {}

local lag_started = false
local wired = false

---Start the lag sampler if it is not already running.
---@return nil
local function start_lag()
    if lag_started then
        return
    end
    local ok, err = require('perf.event_loop_lag').setup()
    if not ok then
        vim.notify('perf: event_loop_lag setup failed: ' .. tostring(err), vim.log.levels.WARN)
        return
    end
    lag_started = true
end

---Wire the autocmd tracker and the report commands. Idempotent.
---The lag sampler deliberately does NOT start here.
---@return nil
function M.setup()
    if wired then
        return
    end
    wired = true
    require('perf.autocmd_cost').setup()
    vim.api.nvim_create_user_command('PerfAutocmd', function()
        require('perf.autocmd_cost').report()
    end, { desc = 'Perf: show autocmd handler costs' })
    vim.api.nvim_create_user_command('PerfLag', function()
        start_lag()
        require('perf.event_loop_lag').report()
    end, { desc = 'Perf: start the event-loop lag sampler and show its report' })
    vim.api.nvim_create_user_command('PerfLagStop', function()
        require('perf.event_loop_lag').stop()
        lag_started = false
    end, { desc = 'Perf: stop the event-loop lag sampler' })
end

return M
