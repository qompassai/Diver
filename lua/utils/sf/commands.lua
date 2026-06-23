local apex = require('utils.sf.apex')
local files = require('utils.sf.files')
local tests = require('utils.sf.tests')
local org = require('utils.sf.org')

local M = {}

function M.setup()
    vim.api.nvim_create_user_command('SfApexRun', apex.run_current_file, {
        desc = 'Run current file as anonymous Apex',
    })

    vim.api.nvim_create_user_command('SfApexRunInteractive', apex.run_selection_interactive, {
        desc = 'Open interactive anonymous Apex runner',
    })

    vim.api.nvim_create_user_command('SfTailLog', apex.tail_logs, {
        desc = 'Tail Apex logs',
    })

    vim.api.nvim_create_user_command('SfLogList', apex.list_logs, {
        desc = 'List Apex logs',
    })

    vim.api.nvim_create_user_command('SfDeployFile', files.deploy_current, {
        desc = 'Deploy current Salesforce file or bundle',
    })

    vim.api.nvim_create_user_command('SfRetrieveFile', files.retrieve_current, {
        desc = 'Retrieve current Salesforce file',
    })

    vim.api.nvim_create_user_command('SfSmart', files.smart_action, {
        desc = 'Smart Salesforce action for current file',
    })

    vim.api.nvim_create_user_command('SfRunCurrentTestClass', tests.run_current_class, {
        desc = 'Run current Apex test class',
    })

    vim.api.nvim_create_user_command('SfRunLocalTests', tests.run_all_local, {
        desc = 'Run all local Apex tests',
    })

    vim.api.nvim_create_user_command('SfOrgOpen', org.open, {
        desc = 'Open Salesforce org',
    })

    vim.api.nvim_create_user_command('SfOrgList', org.list, {
        desc = 'List Salesforce orgs',
    })

    vim.api.nvim_create_user_command('SfOrgDisplay', org.display, {
        desc = 'Display current Salesforce org details',
    })

    vim.api.nvim_create_user_command('SfOrgSetDefault', org.set_default, {
        desc = 'Set default Salesforce target org',
        nargs = 1,
    })
end

return M
