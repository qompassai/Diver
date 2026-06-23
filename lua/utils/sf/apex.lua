local util = require('utils.sf.util')

local M = {}

function M.is_apex_script(file)
    return file:match('%.apex$') ~= nil
end

function M.is_apex_metadata(file)
    return file:match('%.cls$') ~= nil or file:match('%.trigger$') ~= nil
end

function M.run_current_file()
    if not util.ensure_sf() or not util.has_file() then
        return
    end
    local file = util.current_file()
    util.open_term_cmd('sf apex run --file ' .. util.shellescape(file))
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

return M
