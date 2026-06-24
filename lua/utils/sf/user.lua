-- /qompassai/Diver/lua/utils/sf/user.lua
-- Qompass AI Salesforce Flow Util
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local util = require('utils.sf.util')
local M = {}

-- :SfUserCreate
function M.create()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local alias = vim.fn.input('New user alias (optional)> ')
    local cmd = 'sf user create'
    if alias ~= '' then
        cmd = cmd .. ' --alias ' .. util.shellescape(alias)
    end
    util.open_term_cmd(cmd, 20)
end

-- :SfUserCreateFromFile  -- definition JSON file
function M.create_from_file()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local f = vim.fn.input('User definition file> ', '', 'file')
    if f == '' then
        return
    end
    util.open_term_cmd('sf user create --definition-file ' .. util.shellescape(f), 20)
end

-- :SfUserList
function M.list()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    util.open_term_cmd('sf user list', 20)
end

-- :SfUserGeneratePassword
function M.generate_password()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local username = vim.fn.input('Username (blank = default scratch user)> ')
    local cmd = 'sf user generate password'
    if username ~= '' then
        cmd = cmd .. ' --target-org ' .. util.shellescape(username)
    end
    util.open_term_cmd(cmd, 20)
end

-- :SfUserAssignPermset
function M.assign_permset()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local permset = vim.fn.input('Permission set API name> ')
    if permset == '' then
        return
    end
    local username = vim.fn.input('Username (blank = default org user)> ')
    local cmd = 'sf user permset assign --name ' .. util.shellescape(permset)
    if username ~= '' then
        cmd = cmd .. ' --on-behalf-of ' .. util.shellescape(username)
    end
    util.open_term_cmd(cmd, 20)
end

-- :SfUserAssignPermsetLicense
function M.assign_permset_license()
    if not util.ensure_sf() or not util.ensure_org() then
        return
    end
    local psl = vim.fn.input('Permission set license developer name> ')
    if psl == '' then
        return
    end
    util.open_term_cmd('sf user permset-license assign --name ' .. util.shellescape(psl), 20)
end

return M
