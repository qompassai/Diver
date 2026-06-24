-- /qompassai/Diver/lua/utils/sf/flow.lua
-- Qompass AI Salesforce Flow Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Wraps: @salesforce/plugin-flow
local util = require('utils.sf.util')
local M = {}

--- :SfFlowList  -- list flows in the org
function M.list()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    util.open_term_cmd('sf flow list', 20)
end

-- :SfFlowGet  -- retrieve a flow by API name
function M.get()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local name = vim.fn.input('Flow API name> ')
    if name == '' then
        return
    end
    util.open_term_cmd('sf flow get --flow-api-name ' .. util.shellescape(name), 20)
end

-- :SfFlowRun  -- run a flow via Apex headless invocation
function M.run()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local name = vim.fn.input('Flow API name> ')
    if name == '' then
        return
    end
    util.open_term_cmd('sf flow run --flow-api-name ' .. util.shellescape(name), 20)
end

-- :SfFlowDeactivate  -- deactivate an active flow
function M.deactivate()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local name = vim.fn.input('Flow API name> ')
    if name == '' then
        return
    end
    util.open_term_cmd('sf flow deactivate --flow-api-name ' .. util.shellescape(name), 20)
end

--- :SfFlowInterviewList  -- list paused flow interviews
function M.interview_list()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    util.open_term_cmd('sf flow interview list', 20)
end

--- :SfFlowInterviewResume  -- resume a paused interview
function M.interview_resume()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local id = vim.fn.input('Interview ID> ')
    if id == '' then
        return
    end
    util.open_term_cmd('sf flow interview resume --id ' .. util.shellescape(id), 20)
end

return M
