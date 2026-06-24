#!/usr/bin/env lua5.1
-- /qompassai/Diver/lua/utils/sf/auth.lua
-- Qompass AI Salesforce Command Picker
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local util = require('utils.sf.util')
local M = {}

-- :SfAuthWebLogin
function M.web_login()
    if not util.ensure_sf() then
        return
    end
    local alias = vim.fn.input('Org alias (optional)> ')
    local cmd = 'sf auth web login'
    if alias ~= '' then
        cmd = cmd .. ' --alias ' .. util.shellescape(alias)
    end
    util.open_term_cmd(cmd, 20)
end

-- :SfAuthJwtGrant
function M.jwt_grant()
    if not util.ensure_sf() then
        return
    end
    local username = vim.fn.input('Username> ')
    if username == '' then
        return
    end
    local client_id = vim.fn.input('Connected App Client ID> ')
    if client_id == '' then
        return
    end
    local key_file = vim.fn.input('Private key file> ', '', 'file')
    if key_file == '' then
        return
    end
    local alias = vim.fn.input('Org alias (optional)> ')
    local cmd = 'sf auth jwt grant'
        .. ' --username '
        .. util.shellescape(username)
        .. ' --client-id '
        .. util.shellescape(client_id)
        .. ' --jwt-key-file '
        .. util.shellescape(key_file)
    if alias ~= '' then
        cmd = cmd .. ' --alias ' .. util.shellescape(alias)
    end
    util.open_term_cmd(cmd, 20)
end

-- :SfAuthList
function M.list()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf auth list', 20)
end

-- :SfAuthLogout
function M.logout()
    if not util.ensure_sf() then
        return
    end
    local alias = vim.fn.input('Org alias or username to logout> ')
    if alias == '' then
        return
    end
    util.open_term_cmd('sf auth logout --target-org ' .. util.shellescape(alias) .. ' --no-prompt', 20)
end

-- :SfAuthLogoutAll
function M.logout_all()
    if not util.ensure_sf() then
        return
    end
    local confirm = vim.fn.input('Logout ALL orgs? (yes/no)> ')
    if confirm ~= 'yes' then
        vim.notify('[sf] Logout cancelled', vim.log.levels.INFO)
        return
    end
    util.open_term_cmd('sf auth logout --all --no-prompt', 20)
end

-- :SfAuthAccesstokenStore
function M.accesstoken_store()
    if not util.ensure_sf() then
        return
    end
    local instance = vim.fn.input('Instance URL> ')
    if instance == '' then
        return
    end
    local alias = vim.fn.input('Org alias (optional)> ')
    local cmd = 'sf auth accesstoken store --instance-url ' .. util.shellescape(instance)
    if alias ~= '' then
        cmd = cmd .. ' --alias ' .. util.shellescape(alias)
    end
    util.open_term_cmd(cmd, 20)
end

return M