-- /qompassai/Diver/lua/utils/sf/tests.lua
-- Qompass AI Salesforce Testing Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
local util = require('utils.sf.util')

local M = {}

function M.run_current_class()
    if not util.ensure_sf() or not util.has_file() then
        return
    end

    local name = util.current_basename()
    if name == '' then
        util.notify('Unable to determine class name from file', vim.log.levels.WARN)
        return
    end

    util.open_term_cmd(
        'sf apex run test --tests ' .. util.shellescape(name) .. ' --synchronous --result-format human',
        18
    )
end

function M.run_current_method(opts)
    if not util.ensure_sf() or not util.has_file() then
        return
    end

    local class = util.current_basename()
    if class == '' then
        util.notify('Unable to determine class name from file', vim.log.levels.WARN)
        return
    end

    local method = util.get_args(opts)
    if not method then
        method = vim.fn.input('Method name: ')
    end
    if method == '' then
        return
    end

    util.open_term_cmd(
        'sf apex run test --tests '
            .. util.shellescape(class .. '.' .. method)
            .. ' --synchronous --result-format human',
        18
    )
end

function M.run_all_local()
    if not util.ensure_sf() then
        return
    end

    util.open_term_cmd('sf apex run test --test-level RunLocalTests --synchronous --result-format human', 18)
end

function M.run_all_org()
    if not util.ensure_sf() then
        return
    end

    util.open_term_cmd('sf apex run test --test-level RunAllTestsInOrg --synchronous --result-format human', 18)
end

function M.run_suite(opts)
    if not util.ensure_sf() then
        return
    end

    local suite = util.get_args(opts)
    if not suite then
        suite = vim.fn.input('Test suite name: ')
    end
    if suite == '' then
        return
    end

    util.open_term_cmd(
        'sf apex run test --suite-names ' .. util.shellescape(suite) .. ' --synchronous --result-format human',
        18
    )
end

function M.get_last_result(opts)
    if not util.ensure_sf() then
        return
    end

    local run_id = util.get_args(opts)
    if not run_id then
        run_id = vim.fn.input('Test run ID (leave blank for latest): ')
    end

    local cmd = 'sf apex get test --result-format human'
    if run_id ~= '' then
        cmd = cmd .. ' --test-run-id ' .. util.shellescape(run_id)
    end

    util.open_term_cmd(cmd, 18)
end

return M
