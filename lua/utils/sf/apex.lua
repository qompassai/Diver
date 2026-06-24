-- /qompassai/Diver/lua/utils/sf/apex.lua
-- Qompass AI Salesforce Apex Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
local util = require('utils.sf.util')
local M = {}
function M.is_apex_script(file)
    return file:match('%.apex$') ~= nil
end

function M.is_apex_metadata(file)
    return file:match('%.cls$') ~= nil or file:match('%.trigger$') ~= nil
end

function M.is_apex_any(file)
    return M.is_apex_script(file) or M.is_apex_metadata(file)
end

function M.run_current_file()
    if not util.ensure_sf() or not util.has_file() then
        return
    end
    local file = util.current_file()
    if not M.is_apex_script(file) then
        util.notify('Current file is not a .apex script', vim.log.levels.WARN)
        return
    end
    util.open_term_cmd('sf apex run --file ' .. util.shellescape(file), 16)
end

function M.run_selection()
    if not util.ensure_sf() then
        return
    end
    local code = util.get_visual_selection()
    if code == '' then
        util.notify('No text selected', vim.log.levels.WARN)
        return
    end
    local tmp = vim.fn.tempname() .. '.apex'
    local fd = io.open(tmp, 'w')
    if not fd then
        util.notify('Could not write temp file', vim.log.levels.ERROR)
        return
    end
    fd:write(code)
    fd:close()
    util.open_term_cmd('sf apex run --file ' .. util.shellescape(tmp), 16)
end

function M.run_selection_interactive()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf apex run', 16)
end

function M.tail_logs()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf apex tail log --color', 16)
end

function M.list_logs()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf apex log list', 14)
end

function M.get_log(opts)
    if not util.ensure_sf() then
        return
    end
    local id = util.get_args(opts)
    if not id then
        id = vim.fn.input('Log ID: ')
    end
    if id == '' then
        return
    end
    util.open_term_cmd('sf apex log get --log-id ' .. util.shellescape(id), 20)
end

return M