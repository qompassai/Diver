-- /qompassai/Diver/lua/utils/dev/sf/init.lua
local api = vim.api
local core = require('utils.dev.sf.core')

local M = {}

local modules = {
  require('utils.dev.sf.agent'),
  require('utils.dev.sf.analyzer'),
  require('utils.dev.sf.apex'),
  require('utils.dev.sf.data'),
  require('utils.dev.sf.org'),
  require('utils.dev.sf.project'),
}

local legacy = {
  {
    module = 'utils.dev.sf.flow',
    commands = {
      { name = 'SfFlowDeactivate', key = 'deactivate', opts = { desc = 'Deactivate a flow', nargs = '?' } },
      { name = 'SfFlowGet', key = 'get', opts = { desc = 'Get flow details', nargs = '?' } },
      { name = 'SfFlowInterviewList', key = 'interview_list', opts = { desc = 'List flow interviews', nargs = 0 } },
      { name = 'SfFlowInterviewResume', key = 'interview_resume', opts = { desc = 'Resume a flow interview', nargs = '?' } },
      { name = 'SfFlowList', key = 'list', opts = { desc = 'List flows', nargs = 0 } },
      { name = 'SfFlowRun', key = 'run', opts = { desc = 'Run a flow', nargs = '?' } },
    },
  },
  {
    module = 'utils.dev.sf.limits',
    commands = {
      { name = 'SfLimits', key = 'api', opts = { desc = 'Show org limits', nargs = 0 } },
      { name = 'SfLimitsJson', key = 'api_json', opts = { desc = 'Show org limits as JSON', nargs = 0 } },
      { name = 'SfLimitsRecordCount', key = 'record_count', opts = { desc = 'Show org record count limits', nargs = 0 } },
      { name = 'SfLimitsWatch', key = 'watch', opts = { desc = 'Watch org limits continuously', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.package',
    commands = {
      { name = 'SfPackageCreate', key = 'create', opts = { desc = 'Create a package', nargs = '?' } },
      { name = 'SfPackageInstall', key = 'install', opts = { desc = 'Install a package', nargs = '?' } },
      { name = 'SfPackageList', key = 'list', opts = { desc = 'List packages', nargs = 0 } },
      { name = 'SfPackageUninstall', key = 'uninstall', opts = { desc = 'Uninstall a package', nargs = '?' } },
      { name = 'SfPackageVersionCreate', key = 'version_create', opts = { desc = 'Create a package version', nargs = '?' } },
      { name = 'SfPackageVersionCreateStatus', key = 'version_create_status', opts = { desc = 'Check package version creation status', nargs = '?' } },
      { name = 'SfPackageVersionList', key = 'version_list', opts = { desc = 'List package versions', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.schema',
    commands = {
      { name = 'SfSchemaDescribe', key = 'describe', opts = { desc = 'Describe Salesforce object schema', nargs = '?' } },
      { name = 'SfSchemaDescribeJson', key = 'describe_json', opts = { desc = 'Describe Salesforce object schema as JSON', nargs = '?' } },
      { name = 'SfSchemaListCustomObjects', key = 'list_custom_objects', opts = { desc = 'List custom Salesforce objects', nargs = 0 } },
      { name = 'SfSchemaListObjects', key = 'list_objects', opts = { desc = 'List Salesforce objects', nargs = 0 } },
      { name = 'SfSobjectDescribe', key = 'sobject_describe', opts = { desc = 'Describe a Salesforce sObject', nargs = '?' } },
      { name = 'SfSobjectList', key = 'sobject_list', opts = { desc = 'List Salesforce sObjects', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.query',
    commands = {
      { name = 'SfSoql', key = 'soql', opts = { desc = 'Run a SOQL query', nargs = '?' } },
      { name = 'SfSoqlBuffer', key = 'current_buffer', opts = { desc = 'Run SOQL from the current buffer', nargs = 0 } },
      { name = 'SfSoqlExplain', key = 'explain', opts = { desc = 'Explain a SOQL query plan', nargs = '?' } },
      { name = 'SfSoqlFile', key = 'current_file', opts = { desc = 'Run SOQL from a file', nargs = '?' } },
    },
  },
  {
    module = 'utils.dev.sf.tests',
    commands = {
      { name = 'SfTestReport', key = 'report', opts = { desc = 'Show Apex test report details', nargs = '?' } },
      { name = 'SfTestRunAll', key = 'run_all', opts = { desc = 'Run all Apex tests', nargs = 0 } },
      { name = 'SfTestRunClass', key = 'run_class', opts = { desc = 'Run an Apex test class', nargs = '?' } },
      { name = 'SfTestRunCurrent', key = 'run_current', opts = { desc = 'Run tests for the current context', nargs = 0 } },
      { name = 'SfTestRunNearest', key = 'run_nearest', opts = { desc = 'Run the nearest Apex test', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.user',
    commands = {
      { name = 'SfUserAssignPermset', key = 'assign_permset', opts = { desc = 'Assign a permission set to a user', nargs = '?' } },
      { name = 'SfUserAssignPermsetLicense', key = 'assign_permset_license', opts = { desc = 'Assign a permission set license to a user', nargs = '?' } },
      { name = 'SfUserCreate', key = 'create', opts = { desc = 'Create a Salesforce user', nargs = '?' } },
      { name = 'SfUserCreateFromFile', key = 'create_from_file', opts = { desc = 'Create Salesforce users from a file', nargs = '?' } },
      { name = 'SfUserGeneratePassword', key = 'generate_password', opts = { desc = 'Generate a password for a user', nargs = '?' } },
      { name = 'SfUserList', key = 'list', opts = { desc = 'List Salesforce users', nargs = 0 } },
    },
  },
}

local function register_domain_commands()
  for _, module in ipairs(modules) do
    core.register_commands(module.commands or {})
  end
end

local function register_legacy_commands()
  for _, group in ipairs(legacy) do
    local ok, module = pcall(require, group.module)
    if ok and type(module) == 'table' then
      local specs = {}
      for _, spec in ipairs(group.commands) do
        local handler = module[spec.key]
        if type(handler) == 'function' then
          specs[#specs + 1] = {
            name = spec.name,
            fn = handler,
            opts = spec.opts,
          }
        end
      end
      core.register_commands(specs)
    end
  end
end

local function setup_autocmds()
  local ok, mappings = pcall(require, 'utils.dev.sf.mappings')
  local group = api.nvim_create_augroup('SalesforceUtils', { clear = true })
  if ok and type(mappings) == 'table' and type(mappings.attach) == 'function' then
    api.nvim_create_autocmd('BufEnter', {
      group = group,
      pattern = {
        '*.apex',
        '*.cls',
        '*.css',
        '*.trigger',
        '*.js',
        '*.html',
        '*.xml',
      },
      callback = function(event)
        if core.in_sf_project() then
          mappings.attach(event.buf)
        end
      end,
      desc = 'Attach Salesforce keymaps in Salesforce project buffers',
    })
  end
  api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = { '*.cls', '*.trigger' },
    callback = function()
      if core.in_sf_project() then
        core.notify('Saved — deploy with <leader>sfd', vim.log.levels.INFO)
      end
    end,
    desc = 'Remind user to deploy after saving Apex',
  })
end

function M.setup()
  register_domain_commands()
  register_legacy_commands()
  setup_autocmds()
end

return M
~/downloads $ cat init.lua
-- /qompassai/Diver/lua/utils/dev/sf/init.lua
local api = vim.api
local core = require('utils.dev.sf.core')

local M = {}

local modules = {
  require('utils.dev.sf.agent'),
  require('utils.dev.sf.analyzer'),
  require('utils.dev.sf.apex'),
  require('utils.dev.sf.data'),
  require('utils.dev.sf.org'),
  require('utils.dev.sf.project'),
}

local legacy = {
  {
    module = 'utils.dev.sf.flow',
    commands = {
      { name = 'SfFlowDeactivate', key = 'deactivate', opts = { desc = 'Deactivate a flow', nargs = '?' } },
      { name = 'SfFlowGet', key = 'get', opts = { desc = 'Get flow details', nargs = '?' } },
      { name = 'SfFlowInterviewList', key = 'interview_list', opts = { desc = 'List flow interviews', nargs = 0 } },
      { name = 'SfFlowInterviewResume', key = 'interview_resume', opts = { desc = 'Resume a flow interview', nargs = '?' } },
      { name = 'SfFlowList', key = 'list', opts = { desc = 'List flows', nargs = 0 } },
      { name = 'SfFlowRun', key = 'run', opts = { desc = 'Run a flow', nargs = '?' } },
    },
  },
  {
    module = 'utils.dev.sf.limits',
    commands = {
      { name = 'SfLimits', key = 'api', opts = { desc = 'Show org limits', nargs = 0 } },
      { name = 'SfLimitsJson', key = 'api_json', opts = { desc = 'Show org limits as JSON', nargs = 0 } },
      { name = 'SfLimitsRecordCount', key = 'record_count', opts = { desc = 'Show org record count limits', nargs = 0 } },
      { name = 'SfLimitsWatch', key = 'watch', opts = { desc = 'Watch org limits continuously', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.package',
    commands = {
      { name = 'SfPackageCreate', key = 'create', opts = { desc = 'Create a package', nargs = '?' } },
      { name = 'SfPackageInstall', key = 'install', opts = { desc = 'Install a package', nargs = '?' } },
      { name = 'SfPackageList', key = 'list', opts = { desc = 'List packages', nargs = 0 } },
      { name = 'SfPackageUninstall', key = 'uninstall', opts = { desc = 'Uninstall a package', nargs = '?' } },
      { name = 'SfPackageVersionCreate', key = 'version_create', opts = { desc = 'Create a package version', nargs = '?' } },
      { name = 'SfPackageVersionCreateStatus', key = 'version_create_status', opts = { desc = 'Check package version creation status', nargs = '?' } },
      { name = 'SfPackageVersionList', key = 'version_list', opts = { desc = 'List package versions', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.schema',
    commands = {
      { name = 'SfSchemaDescribe', key = 'describe', opts = { desc = 'Describe Salesforce object schema', nargs = '?' } },
      { name = 'SfSchemaDescribeJson', key = 'describe_json', opts = { desc = 'Describe Salesforce object schema as JSON', nargs = '?' } },
      { name = 'SfSchemaListCustomObjects', key = 'list_custom_objects', opts = { desc = 'List custom Salesforce objects', nargs = 0 } },
      { name = 'SfSchemaListObjects', key = 'list_objects', opts = { desc = 'List Salesforce objects', nargs = 0 } },
      { name = 'SfSobjectDescribe', key = 'sobject_describe', opts = { desc = 'Describe a Salesforce sObject', nargs = '?' } },
      { name = 'SfSobjectList', key = 'sobject_list', opts = { desc = 'List Salesforce sObjects', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.query',
    commands = {
      { name = 'SfSoql', key = 'soql', opts = { desc = 'Run a SOQL query', nargs = '?' } },
      { name = 'SfSoqlBuffer', key = 'current_buffer', opts = { desc = 'Run SOQL from the current buffer', nargs = 0 } },
      { name = 'SfSoqlExplain', key = 'explain', opts = { desc = 'Explain a SOQL query plan', nargs = '?' } },
      { name = 'SfSoqlFile', key = 'current_file', opts = { desc = 'Run SOQL from a file', nargs = '?' } },
    },
  },
  {
    module = 'utils.dev.sf.tests',
    commands = {
      { name = 'SfTestReport', key = 'report', opts = { desc = 'Show Apex test report details', nargs = '?' } },
      { name = 'SfTestRunAll', key = 'run_all', opts = { desc = 'Run all Apex tests', nargs = 0 } },
      { name = 'SfTestRunClass', key = 'run_class', opts = { desc = 'Run an Apex test class', nargs = '?' } },
      { name = 'SfTestRunCurrent', key = 'run_current', opts = { desc = 'Run tests for the current context', nargs = 0 } },
      { name = 'SfTestRunNearest', key = 'run_nearest', opts = { desc = 'Run the nearest Apex test', nargs = 0 } },
    },
  },
  {
    module = 'utils.dev.sf.user',
    commands = {
      { name = 'SfUserAssignPermset', key = 'assign_permset', opts = { desc = 'Assign a permission set to a user', nargs = '?' } },
      { name = 'SfUserAssignPermsetLicense', key = 'assign_permset_license', opts = { desc = 'Assign a permission set license to a user', nargs = '?' } },
      { name = 'SfUserCreate', key = 'create', opts = { desc = 'Create a Salesforce user', nargs = '?' } },
      { name = 'SfUserCreateFromFile', key = 'create_from_file', opts = { desc = 'Create Salesforce users from a file', nargs = '?' } },
      { name = 'SfUserGeneratePassword', key = 'generate_password', opts = { desc = 'Generate a password for a user', nargs = '?' } },
      { name = 'SfUserList', key = 'list', opts = { desc = 'List Salesforce users', nargs = 0 } },
    },
  },
}

local function register_domain_commands()
  for _, module in ipairs(modules) do
    core.register_commands(module.commands or {})
  end
end

local function register_legacy_commands()
  for _, group in ipairs(legacy) do
    local ok, module = pcall(require, group.module)
    if ok and type(module) == 'table' then
      local specs = {}
      for _, spec in ipairs(group.commands) do
        local handler = module[spec.key]
        if type(handler) == 'function' then
          specs[#specs + 1] = {
            name = spec.name,
            fn = handler,
            opts = spec.opts,
          }
        end
      end
      core.register_commands(specs)
    end
  end
end

local function setup_autocmds()
  local ok, mappings = pcall(require, 'utils.dev.sf.mappings')
  local group = api.nvim_create_augroup('SalesforceUtils', { clear = true })
  if ok and type(mappings) == 'table' and type(mappings.attach) == 'function' then
    api.nvim_create_autocmd('BufEnter', {
      group = group,
      pattern = {
        '*.apex',
        '*.cls',
        '*.css',
        '*.trigger',
        '*.js',
        '*.html',
        '*.xml',
      },
      callback = function(event)
        if core.in_sf_project() then
          mappings.attach(event.buf)
        end
      end,
      desc = 'Attach Salesforce keymaps in Salesforce project buffers',
    })
  end
  api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = { '*.cls', '*.trigger' },
    callback = function()
      if core.in_sf_project() then
        core.notify('Saved — deploy with <leader>sfd', vim.log.levels.INFO)
      end
    end,
    desc = 'Remind user to deploy after saving Apex',
  })
end

function M.setup()
  register_domain_commands()
  register_legacy_commands()
  setup_autocmds()
end

return M