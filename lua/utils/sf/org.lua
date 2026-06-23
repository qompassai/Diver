local util = require('utils.sf.util')

local M = {}

function M.open()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf org open', 12)
end

function M.list()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf org list', 16)
end

function M.display()
    if not util.ensure_sf() then
        return
    end
    util.open_term_cmd('sf org display', 16)
end

function M.set_default(opts)
    if not util.ensure_sf() then
        return
    end

    local alias = opts.args
    if not alias or alias == '' then
        util.notify('Usage: :SfOrgSetDefault <alias>', vim.log.levels.WARN)
        return
    end

    util.open_term_cmd('sf config set target-org=' .. util.shellescape(alias), 12)
end

return M
