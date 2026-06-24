-- /qompassai/Diver/lua/utils/sf/commands.lua
-- Qompass AI Salesforce Command Utilities
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'utils.sf.commands'

local agent = require('utils.sf.agent')
local analyzer = require('utils.sf.analyzer')
local apex = require('utils.sf.apex')
local auth = require('utils.sf.auth')
local community = require('utils.sf.community')
local data = require('utils.sf.data')
local files = require('utils.sf.files')
local flow = require('utils.sf.flow')
local limits = require('utils.sf.limits')
local org = require('utils.sf.org')
local pkg = require('utils.sf.package')
local query = require('utils.sf.query')
local schema = require('utils.sf.schema')
local tests = require('utils.sf.tests')
local user = require('utils.sf.user')

local M = {}

local function severity_complete(arg_lead)
    local values = {
        'Critical',
        'High',
        'Moderate',
        'Low',
        'Info',
    }

    local matches = {}
    local lead = (arg_lead or ''):lower()

    for _, value in ipairs(values) do
        if value:lower():find(lead, 1, true) == 1 then
            table.insert(matches, value)
        end
    end

    return matches
end

---@type table[]
local COMMANDS = {
    -- Agent
    {
        name = 'SfAgentActivate',
        fn = agent.activate,
        opts = {
            desc = 'Activate an agent in the target org',
            nargs = '?',
        },
    },
    {
        name = 'SfAgentAdlCreate',
        fn = agent.adl_create,
        opts = { desc = 'Create an Agentforce Data Library', nargs = '?' },
    },
    {
        name = 'SfAgentAdlDelete',
        fn = agent.adl_delete,
        opts = { desc = 'Delete an Agentforce Data Library', nargs = '?' },
    },
    {
        name = 'SfAgentAdlFileAdd',
        fn = agent.adl_file_add,
        opts = { desc = 'Add a file to an Agentforce Data Library', nargs = '?' },
    },
    {
        name = 'SfAgentAdlFileDelete',
        fn = agent.adl_file_delete,
        opts = { desc = 'Delete a file from an Agentforce Data Library', nargs = '?' },
    },
    {
        name = 'SfAgentAdlFileList',
        fn = agent.adl_file_list,
        opts = { desc = 'List files in an Agentforce Data Library', nargs = '?' },
    },
    {
        name = 'SfAgentAdlGet',
        fn = agent.adl_get,
        opts = { desc = 'Get Agentforce Data Library details', nargs = '?' },
    },
    {
        name = 'SfAgentAdlList',
        fn = agent.adl_list,
        opts = { desc = 'List Agentforce Data Libraries', nargs = 0 },
    },
    {
        name = 'SfAgentAdlStatus',
        fn = agent.adl_status,
        opts = { desc = 'Get Agentforce Data Library status', nargs = '?' },
    },
    {
        name = 'SfAgentAdlUpdate',
        fn = agent.adl_update,
        opts = { desc = 'Update an Agentforce Data Library', nargs = '?' },
    },
    {
        name = 'SfAgentAdlUpload',
        fn = agent.adl_upload,
        opts = { desc = 'Upload a file to an Agentforce Data Library', nargs = '?' },
    },
    {
        name = 'SfAgentCreate',
        fn = agent.create,
        opts = { desc = 'Create an agent from a spec file', nargs = '?' },
    },
    {
        name = 'SfAgentDeactivate',
        fn = agent.deactivate,
        opts = { desc = 'Deactivate an agent in the target org', nargs = '?' },
    },
    {
        name = 'SfAgentGenerateAgentSpec',
        fn = agent.generate_agent_spec,
        opts = { desc = 'Generate an agent spec YAML file', nargs = '?' },
    },
    {
        name = 'SfAgentGenerateAuthoringBundle',
        fn = agent.generate_authoring_bundle,
        opts = { desc = 'Generate an authoring bundle from an agent spec', nargs = '?' },
    },
    {
        name = 'SfAgentGenerateTemplate',
        fn = agent.generate_template,
        opts = { desc = 'Generate an agent template from an existing agent', nargs = '?' },
    },
    {
        name = 'SfAgentGenerateTestSpec',
        fn = agent.generate_test_spec,
        opts = { desc = 'Generate an agent test spec YAML file', nargs = '?' },
    },
    {
        name = 'SfAgentPreview',
        fn = agent.preview,
        opts = { desc = 'Run interactive agent preview', nargs = '?' },
    },
    {
        name = 'SfAgentPreviewEnd',
        fn = agent.preview_end,
        opts = { desc = 'End an agent preview session', nargs = '?' },
    },
    {
        name = 'SfAgentPreviewSend',
        fn = agent.preview_send,
        opts = { desc = 'Send a message to an agent preview session', nargs = '*' },
    },
    {
        name = 'SfAgentPreviewSessions',
        fn = agent.preview_sessions,
        opts = { desc = 'List known agent preview sessions', nargs = 0 },
    },
    {
        name = 'SfAgentPreviewStart',
        fn = agent.preview_start,
        opts = { desc = 'Start a programmatic agent preview session', nargs = '?' },
    },
    {
        name = 'SfAgentPublishAuthoringBundle',
        fn = agent.publish_bundle,
        opts = { desc = 'Publish an authoring bundle', nargs = '?' },
    },
    {
        name = 'SfAgentTestCreate',
        fn = agent.test_create,
        opts = { desc = 'Create an agent test from a test spec', nargs = '?' },
    },
    {
        name = 'SfAgentTestList',
        fn = agent.test_list,
        opts = { desc = 'List agent tests', nargs = 0 },
    },
    {
        name = 'SfAgentTestResults',
        fn = agent.test_results,
        opts = { desc = 'Get completed agent test results', nargs = '?' },
    },
    {
        name = 'SfAgentTestResume',
        fn = agent.test_resume,
        opts = { desc = 'Resume a previously started agent test', nargs = '?' },
    },
    {
        name = 'SfAgentTestRun',
        fn = agent.test_run,
        opts = { desc = 'Run an agent test', nargs = '?' },
    },
    {
        name = 'SfAgentTestRunEval',
        fn = agent.test_run_eval,
        opts = { desc = 'Run rich evaluation tests for an agent', nargs = '?' },
    },
    {
        name = 'SfAgentTraceDelete',
        fn = agent.trace_delete,
        opts = { desc = 'Delete agent trace files', nargs = '?' },
    },
    {
        name = 'SfAgentTraceList',
        fn = agent.trace_list,
        opts = { desc = 'List agent trace files', nargs = 0 },
    },
    {
        name = 'SfAgentTraceRead',
        fn = agent.trace_read,
        opts = { desc = 'Read an agent trace file', nargs = '?' },
    },
    {
        name = 'SfAgentValidateBundle',
        fn = agent.validate_bundle,
        opts = { desc = 'Validate an agent authoring bundle', nargs = '?' },
    },

    -- Analyzer
    {
        name = 'SfAnalyzeConfig',
        fn = analyzer.config,
        opts = { desc = 'Show Code Analyzer configuration', nargs = 0 },
    },
    {
        name = 'SfAnalyzeConfigGenerate',
        fn = analyzer.config_generate,
        opts = { desc = 'Generate a Code Analyzer config file', nargs = '?' },
    },
    {
        name = 'SfAnalyzeDiagnostics',
        fn = analyzer.run_file_diagnostics,
        opts = {
            desc = 'Run Code Analyzer on the current file and publish diagnostics',
            nargs = '?',
        },
    },
    {
        name = 'SfAnalyzeDiagnosticsClear',
        fn = analyzer.clear_diagnostics,
        opts = {
            desc = 'Clear Code Analyzer diagnostics from the current buffer',
            nargs = 0,
        },
    },
    {
        name = 'SfAnalyzeFile',
        fn = analyzer.run_file,
        opts = { desc = 'Run Code Analyzer on the current file', nargs = '?' },
    },
    {
        name = 'SfAnalyzeProject',
        fn = analyzer.run_project,
        opts = { desc = 'Run Code Analyzer on the current project', nargs = '?' },
    },
    {
        name = 'SfAnalyzeProjectJsonFile',
        fn = analyzer.run_project_json_to_file,
        opts = {
            desc = 'Run Code Analyzer on the project and write JSON output to a file',
            nargs = '?',
        },
    },
    {
        name = 'SfAnalyzeRules',
        fn = analyzer.rules,
        opts = { desc = 'List Code Analyzer rules', nargs = 0 },
    },
    {
        name = 'SfAnalyzeSeverity',
        fn = analyzer.run_severity,
        opts = { desc = 'Run Code Analyzer with a severity threshold', nargs = 1, complete = severity_complete },
    },

    -- Apex
    {
        name = 'SfApexLogGet',
        fn = apex.log_get,
        opts = { desc = 'Get an Apex log by ID', nargs = '?' },
    },
    {
        name = 'SfApexLogTail',
        fn = apex.log_tail,
        opts = { desc = 'Tail Apex logs', nargs = 0 },
    },
    {
        name = 'SfApexReplayDebug',
        fn = apex.replay_debug,
        opts = { desc = 'Replay debug logs for Apex', nargs = '?' },
    },
    {
        name = 'SfApexRunCurrent',
        fn = apex.run_current,
        opts = { desc = 'Run the current Apex buffer or file', nargs = 0 },
    },
    {
        name = 'SfApexRunFile',
        fn = apex.run_file,
        opts = { desc = 'Run an Apex file', nargs = '?' },
    },
    {
        name = 'SfApexTestClass',
        fn = apex.test_class,
        opts = { desc = 'Run an Apex test class', nargs = '?' },
    },
    {
        name = 'SfApexTestCurrent',
        fn = apex.test_current,
        opts = { desc = 'Run tests for the current Apex context', nargs = 0 },
    },

    -- Auth
    {
        name = 'SfAuthAccesstokenStore',
        fn = auth.accesstoken_store,
        opts = { desc = 'Store an access token for auth', nargs = 0 },
    },
    {
        name = 'SfAuthJwtGrant',
        fn = auth.jwt_grant,
        opts = { desc = 'Authenticate with JWT grant', nargs = 0 },
    },
    {
        name = 'SfAuthList',
        fn = auth.list,
        opts = { desc = 'List authenticated orgs and auth info', nargs = 0 },
    },
    {
        name = 'SfAuthLogout',
        fn = auth.logout,
        opts = { desc = 'Log out from an org', nargs = '?' },
    },
    {
        name = 'SfAuthLogoutAll',
        fn = auth.logout_all,
        opts = { desc = 'Log out from all orgs', nargs = 0 },
    },
    {
        name = 'SfAuthWebLogin',
        fn = auth.web_login,
        opts = { desc = 'Authenticate with web login', nargs = '?' },
    },

    -- Community
    {
        name = 'SfCommunityCreate',
        fn = community.create,
        opts = { desc = 'Create a community', nargs = '?' },
    },
    {
        name = 'SfCommunityList',
        fn = community.list,
        opts = { desc = 'List communities', nargs = 0 },
    },
    {
        name = 'SfCommunityPublish',
        fn = community.publish,
        opts = { desc = 'Publish a community', nargs = '?' },
    },

    -- Data
    {
        name = 'SfDataCreateRecord',
        fn = data.create_record,
        opts = { desc = 'Create a Salesforce record', nargs = '?' },
    },
    {
        name = 'SfDataDeleteRecord',
        fn = data.delete_record,
        opts = { desc = 'Delete a Salesforce record', nargs = '?' },
    },
    {
        name = 'SfDataExportTree',
        fn = data.export_tree,
        opts = { desc = 'Export records as a tree', nargs = '?' },
    },
    {
        name = 'SfDataGetRecord',
        fn = data.get_record,
        opts = { desc = 'Get a Salesforce record by ID', nargs = '?' },
    },
    {
        name = 'SfDataQuery',
        fn = data.query,
        opts = { desc = 'Run a Salesforce data query', nargs = '?' },
    },
    {
        name = 'SfDataQueryBuffer',
        fn = data.query_buffer,
        opts = { desc = 'Run SOQL from the current buffer', nargs = 0 },
    },
    {
        name = 'SfDataQueryFile',
        fn = data.query_file,
        opts = { desc = 'Run SOQL from a file', nargs = '?' },
    },
    {
        name = 'SfDataUpsertBulk',
        fn = data.upsert_bulk,
        opts = { desc = 'Run a bulk upsert job', nargs = '?' },
    },

    -- Deploy / Retrieve
    {
        name = 'SfDeployCurrent',
        fn = files.deploy_current,
        opts = { desc = 'Deploy the current file or metadata bundle', nargs = 0 },
    },
    {
        name = 'SfDeployFile',
        fn = files.deploy_file,
        opts = { desc = 'Deploy a file', nargs = '?' },
    },
    {
        name = 'SfDeployManifest',
        fn = files.deploy_manifest,
        opts = { desc = 'Deploy a manifest file', nargs = '?' },
    },
    {
        name = 'SfDeployProject',
        fn = files.deploy_project,
        opts = { desc = 'Deploy the current Salesforce project', nargs = '?' },
    },
    {
        name = 'SfDeployValidate',
        fn = files.deploy_validate,
        opts = { desc = 'Validate a deploy without committing changes', nargs = '?' },
    },
    {
        name = 'SfRetrieveCurrent',
        fn = files.retrieve_current,
        opts = { desc = 'Retrieve the current file or metadata bundle', nargs = 0 },
    },
    {
        name = 'SfRetrieveFile',
        fn = files.retrieve_file,
        opts = { desc = 'Retrieve a file', nargs = '?' },
    },
    {
        name = 'SfRetrieveManifest',
        fn = files.retrieve_manifest,
        opts = { desc = 'Retrieve metadata from a manifest file', nargs = '?' },
    },

    -- Flow
    {
        name = 'SfFlowDeactivate',
        fn = flow.deactivate,
        opts = { desc = 'Deactivate a flow', nargs = '?' },
    },
    {
        name = 'SfFlowGet',
        fn = flow.get,
        opts = { desc = 'Get flow details', nargs = '?' },
    },
    {
        name = 'SfFlowInterviewList',
        fn = flow.interview_list,
        opts = { desc = 'List flow interviews', nargs = 0 },
    },
    {
        name = 'SfFlowInterviewResume',
        fn = flow.interview_resume,
        opts = { desc = 'Resume a flow interview', nargs = '?' },
    },
    {
        name = 'SfFlowList',
        fn = flow.list,
        opts = { desc = 'List flows', nargs = 0 },
    },
    {
        name = 'SfFlowRun',
        fn = flow.run,
        opts = { desc = 'Run a flow', nargs = '?' },
    },

    -- Limits
    {
        name = 'SfLimits',
        fn = limits.api,
        opts = { desc = 'Show org limits', nargs = 0 },
    },
    {
        name = 'SfLimitsJson',
        fn = limits.api_json,
        opts = { desc = 'Show org limits as JSON', nargs = 0 },
    },
    {
        name = 'SfLimitsRecordCount',
        fn = limits.record_count,
        opts = { desc = 'Show org record count limits', nargs = 0 },
    },
    {
        name = 'SfLimitsWatch',
        fn = limits.watch,
        opts = { desc = 'Watch org limits continuously', nargs = 0 },
    },

    -- Org
    {
        name = 'SfOrgCurrent',
        fn = org.current,
        opts = { desc = 'Show the current default org', nargs = 0 },
    },
    {
        name = 'SfOrgDisplay',
        fn = org.display,
        opts = { desc = 'Display org details', nargs = '?' },
    },
    {
        name = 'SfOrgList',
        fn = org.list,
        opts = { desc = 'List authenticated orgs', nargs = 0 },
    },
    {
        name = 'SfOrgLoginWeb',
        fn = org.login_web,
        opts = { desc = 'Log in to an org via web', nargs = '?' },
    },
    {
        name = 'SfOrgLogout',
        fn = org.logout,
        opts = { desc = 'Log out from an org', nargs = '?' },
    },
    {
        name = 'SfOrgOpen',
        fn = org.open,
        opts = { desc = 'Open the current org in a browser', nargs = '?' },
    },
    {
        name = 'SfOrgSetDefault',
        fn = org.set_default,
        opts = { desc = 'Set the default target org', nargs = '?' },
    },

    -- Package
    {
        name = 'SfPackageCreate',
        fn = pkg.create,
        opts = { desc = 'Create a package', nargs = '?' },
    },
    {
        name = 'SfPackageInstall',
        fn = pkg.install,
        opts = { desc = 'Install a package', nargs = '?' },
    },
    {
        name = 'SfPackageList',
        fn = pkg.list,
        opts = { desc = 'List packages', nargs = 0 },
    },
    {
        name = 'SfPackageUninstall',
        fn = pkg.uninstall,
        opts = { desc = 'Uninstall a package', nargs = '?' },
    },
    {
        name = 'SfPackageVersionCreate',
        fn = pkg.version_create,
        opts = { desc = 'Create a package version', nargs = '?' },
    },
    {
        name = 'SfPackageVersionCreateStatus',
        fn = pkg.version_create_status,
        opts = { desc = 'Check package version creation status', nargs = '?' },
    },
    {
        name = 'SfPackageVersionList',
        fn = pkg.version_list,
        opts = { desc = 'List package versions', nargs = 0 },
    },

    -- Schema / Query
    {
        name = 'SfSchemaDescribe',
        fn = schema.describe,
        opts = { desc = 'Describe Salesforce object schema', nargs = '?' },
    },
    {
        name = 'SfSchemaDescribeJson',
        fn = schema.describe_json,
        opts = { desc = 'Describe Salesforce object schema as JSON', nargs = '?' },
    },
    {
        name = 'SfSchemaListCustomObjects',
        fn = schema.list_custom_objects,
        opts = { desc = 'List custom Salesforce objects', nargs = 0 },
    },
    {
        name = 'SfSchemaListObjects',
        fn = schema.list_objects,
        opts = { desc = 'List Salesforce objects', nargs = 0 },
    },
    {
        name = 'SfSobjectDescribe',
        fn = schema.sobject_describe,
        opts = { desc = 'Describe a Salesforce sObject', nargs = '?' },
    },
    {
        name = 'SfSobjectList',
        fn = schema.sobject_list,
        opts = { desc = 'List Salesforce sObjects', nargs = 0 },
    },
    {
        name = 'SfSoql',
        fn = query.soql,
        opts = { desc = 'Run a SOQL query', nargs = '?' },
    },
    {
        name = 'SfSoqlBuffer',
        fn = query.current_buffer,
        opts = { desc = 'Run SOQL from the current buffer', nargs = 0 },
    },
    {
        name = 'SfSoqlExplain',
        fn = query.explain,
        opts = { desc = 'Explain a SOQL query plan', nargs = '?' },
    },
    {
        name = 'SfSoqlFile',
        fn = query.current_file,
        opts = { desc = 'Run SOQL from a file', nargs = '?' },
    },

    -- Tests
    {
        name = 'SfTestReport',
        fn = tests.report,
        opts = { desc = 'Show Apex test report details', nargs = '?' },
    },
    {
        name = 'SfTestRunAll',
        fn = tests.run_all,
        opts = { desc = 'Run all Apex tests', nargs = 0 },
    },
    {
        name = 'SfTestRunClass',
        fn = tests.run_class,
        opts = { desc = 'Run an Apex test class', nargs = '?' },
    },
    {
        name = 'SfTestRunCurrent',
        fn = tests.run_current,
        opts = { desc = 'Run tests for the current context', nargs = 0 },
    },
    {
        name = 'SfTestRunNearest',
        fn = tests.run_nearest,
        opts = { desc = 'Run the nearest Apex test', nargs = 0 },
    },

    -- User
    {
        name = 'SfUserAssignPermset',
        fn = user.assign_permset,
        opts = { desc = 'Assign a permission set to a user', nargs = '?' },
    },
    {
        name = 'SfUserAssignPermsetLicense',
        fn = user.assign_permset_license,
        opts = { desc = 'Assign a permission set license to a user', nargs = '?' },
    },
    {
        name = 'SfUserCreate',
        fn = user.create,
        opts = { desc = 'Create a Salesforce user', nargs = '?' },
    },
    {
        name = 'SfUserCreateFromFile',
        fn = user.create_from_file,
        opts = { desc = 'Create Salesforce users from a file', nargs = '?' },
    },
    {
        name = 'SfUserGeneratePassword',
        fn = user.generate_password,
        opts = { desc = 'Generate a password for a user', nargs = '?' },
    },
    {
        name = 'SfUserList',
        fn = user.list,
        opts = { desc = 'List Salesforce users', nargs = 0 },
    },
}

function M.get_commands()
    return COMMANDS
end

function M.register()
    for _, item in ipairs(COMMANDS) do
        vim.api.nvim_create_user_command(item.name, item.fn, item.opts or {})
    end
end

return M
