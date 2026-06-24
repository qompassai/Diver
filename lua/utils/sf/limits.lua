-- lua/utils/sf/limits.lua
local util = require('utils.sf.util')
local M = {}

-- :SfLimits
function M.api()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    util.open_term_cmd('sf limits api display', 20)
end

-- :SfLimitsJson
function M.api_json()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    util.open_term_cmd('sf limits api display --json | jq .', 20)
end

-- :SfLimitsRecordCount
function M.record_count()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local sobjects = vim.fn.input('SObjects (comma-separated, blank = all)> ')
    local cmd = 'sf limits recordcount display'
    if sobjects ~= '' then
        cmd = cmd .. ' --sobject ' .. util.shellescape(sobjects)
    end
    util.open_term_cmd(cmd, 20)
end

-- :SfLimitsWatch  -- poll limits with watch(1)
function M.watch()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local interval_input = vim.fn.input('Refresh interval seconds (default 10)> ')
    local interval = tonumber(interval_input)
    if not interval or interval <= 0 then
        interval = 10
    end
    util.open_term_cmd('watch -n ' .. interval .. ' sf limits api display', 20)
end

return M