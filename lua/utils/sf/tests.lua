local util = require('utils.sf.util')

local M = {}

function M.run_current_class()
    if not util.ensure_sf() or not util.has_file() then
        return
    end

    local name = util.current_basename()
    if name == '' then
        util.notify('Unable to determine class name', vim.log.levels.WARN)
        return
    end

    util.open_term_cmd(
        'sf apex run test --tests ' .. util.shellescape(name) .. ' --synchronous --result-format human',
        18
    )
end

function M.run_all_local()
    if not util.ensure_sf() then
        return
    end

    util.open_term_cmd('sf apex run test --test-level RunLocalTests --synchronous --result-format human', 18)
end

return M
