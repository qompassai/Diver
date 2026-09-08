lua
-- lua/utils/sf/agent.lua                                                  local core = require('utils.dev.sf.core')
local M = {}                                                               local function run(cmd, height)
  core.open_term_cmd(cmd, height or 20)                                    end
function M.activate(opts)                                                    if not core.ensure_sf() or not core.ensure_org() then
    return                                                                   end
  local api_name = core.input_or_arg(opts, 'Agent API name> ')               if not api_name then
    return                                                                   end
  local version = vim.fn.input('Version (blank = default/latest)> ')         local cmd = 'sf agent activate --api-name ' .. core.shellescape(api_name)
  if version ~= '' then                                                        cmd = cmd .. ' --version ' .. core.shellescape(version)
  end                                                                        run(cmd)
end                                                                        
function M.adl_create(opts)                                                  if not core.ensure_sf() or not core.ensure_org() then
    return                                                                   end
  local name = core.input_or_arg(opts, 'ADL name> ')                         if not name then
    return
  end
  run('sf agent adl create --name ' .. core.shellescape(name))
end

function M.adl_delete(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  run('sf agent adl delete --id ' .. core.shellescape(adl_id))
end

function M.adl_file_add(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  local file_path = core.input_required('File to add> ', 'file')
  if not file_path then
    return
  end
  run('sf agent adl file add --id ' .. core.shellescape(adl_id) .. ' --file ' .. core.shellescape(file_path), 30)
end

function M.adl_file_delete(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  local file_id = core.input_required('File ID> ')
  if not file_id then
    return
  end
  run('sf agent adl file delete --id ' .. core.shellescape(adl_id) .. ' --file-id ' .. core.shellescape(file_id))
end

function M.adl_file_list(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  run('sf agent adl file list --id ' .. core.shellescape(adl_id))
end

function M.adl_get(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  run('sf agent adl get --id ' .. core.shellescape(adl_id))
end

function M.adl_list()
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  run('sf agent adl list')
end

function M.adl_status(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  run('sf agent adl status --id ' .. core.shellescape(adl_id))
end

function M.adl_update(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  local name = vim.fn.input('New ADL name (blank = unchanged)> ')
  local cmd = 'sf agent adl update --id ' .. core.shellescape(adl_id)
  if name ~= '' then
    cmd = cmd .. ' --name ' .. core.shellescape(name)
  end
  run(cmd)
end

function M.adl_upload(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local adl_id = core.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then
    return
  end
  local file_path = core.input_required('File to upload> ', 'file')
  if not file_path then
    return
  end
  run('sf agent adl upload --id ' .. core.shellescape(adl_id) .. ' --file ' .. core.shellescape(file_path), 30)
end

function M.create(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local spec_file = core.input_or_arg(opts, 'Agent spec YAML file> ', 'file')
  if not spec_file then
    return
  end
  local agent_name = vim.fn.input('Agent name (blank = use spec/default)> ')
  local cmd = 'sf agent create --spec ' .. core.shellescape(spec_file)
  if agent_name ~= '' then
    cmd = cmd .. ' --agent-name ' .. core.shellescape(agent_name)
  end
  run(cmd, 30)
end

function M.deactivate(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local api_name = core.input_or_arg(opts, 'Agent API name> ')
  if not api_name then
    return
  end
  local version = vim.fn.input('Version (blank = default/latest)> ')
  local cmd = 'sf agent deactivate --api-name ' .. core.shellescape(api_name)
  if version ~= '' then
    cmd = cmd .. ' --version ' .. core.shellescape(version)
  end
  run(cmd)
end

function M.generate_agent_spec(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local spec = core.get_arg(opts) or vim.fn.input('Existing spec file (blank = none)> ', '', 'file')
  local cmd = 'sf agent generate agent-spec'
  if spec and spec ~= '' then
    cmd = cmd .. ' --spec ' .. core.shellescape(spec)
  end
  run(cmd, 30)
end

function M.generate_authoring_bundle(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local spec_file = core.input_or_arg(opts, 'Agent spec YAML file> ', 'file')
  if not spec_file then
    return
  end
  run('sf agent generate authoring-bundle --spec ' .. core.shellescape(spec_file), 30)
end

function M.generate_specs(opts)
  return M.generate_test_spec(opts)
end

function M.generate_template(opts)
  if not core.ensure_sf() or not core.ensure_project() then
    return
  end
  local api_name = core.input_or_arg(opts, 'Agent API name> ')
  if not api_name then
    return
  end
  run('sf agent generate template --api-name ' .. core.shellescape(api_name), 30)
end

function M.generate_test_spec(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local agent_name = core.input_or_arg(opts, 'Agent API name> ')
  if not agent_name then
    return
  end
  run('sf agent generate test-spec --name ' .. core.shellescape(agent_name), 30)
end

function M.preview(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local arg = core.get_arg(opts)
  local cmd = 'sf agent preview'
  if arg and arg ~= '' then
    cmd = cmd .. ' --api-name ' .. core.shellescape(arg)
    run(cmd, 30)
    return
  end
  local mode = vim.fn.input('Preview mode [api/bundle]> ')
  if mode == 'api' then
    local api_name = core.input_required('Agent API name> ')
    if not api_name then
      return
    end
    cmd = cmd .. ' --api-name ' .. core.shellescape(api_name)
  elseif mode == 'bundle' then
    local bundle = core.input_required('Authoring bundle name or path> ')
    if not bundle then
      return
    end
    cmd = cmd .. ' --authoring-bundle ' .. core.shellescape(bundle)
  end
  run(cmd, 30)
end

function M.preview_end(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local session = core.input_or_arg(opts, 'Session ID> ')
  if not session then
    return
  end
  run('sf agent preview end --id ' .. core.shellescape(session))
end

function M.preview_send(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local session = nil
  local message = nil
  if opts and opts.fargs and #opts.fargs > 0 then
    session = opts.fargs[1]
    if #opts.fargs > 1 then
      message = table.concat(vim.list_slice(opts.fargs, 2), ' ')
    end
  end
  if not session or session == '' then
    session = core.input_required('Session ID> ')
  end
  if not session then
    return
  end
  if not message or message == '' then
    message = core.input_required('Message> ')
  end
  if not message then
    return
  end
  run('sf agent preview send --id ' .. core.shellescape(session) .. ' --message ' .. core.shellescape(message), 20)
end

function M.preview_sessions()
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  run('sf agent preview sessions')
end

function M.preview_start(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local agent_id = core.input_or_arg(opts, 'Agent API name or ID> ')
  if not agent_id then
    return
  end
  run('sf agent preview start --name ' .. core.shellescape(agent_id), 20)
end

function M.publish_bundle(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local bundle = core.get_arg(opts) or vim.fn.input('Bundle path (default: force-app)> ', '', 'file')
  bundle = bundle ~= '' and bundle or 'force-app'
  run('sf agent publish authoring-bundle --bundle-path ' .. core.shellescape(bundle), 30)
end

function M.test_create(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local spec_file = core.input_or_arg(opts, 'Test spec YAML file> ', 'file')
  if not spec_file then
    return
  end
  run('sf agent test create --spec ' .. core.shellescape(spec_file), 30)
end

function M.test_list()
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  run('sf agent test list')
end

function M.test_results(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local run_id = core.input_or_arg(opts, 'Test run ID> ')
  if not run_id then
    return
  end
  run('sf agent test results --id ' .. core.shellescape(run_id))
end

function M.test_resume(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local run_id = core.input_or_arg(opts, 'Test run ID> ')
  if not run_id then
    return
  end
  run('sf agent test resume --id ' .. core.shellescape(run_id))
end

function M.test_run(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local suite = core.input_or_arg(opts, 'Test suite/spec file path> ', 'file')
  if not suite then
    return
  end
  run('sf agent test run --test-file ' .. core.shellescape(suite) .. ' --wait 5', 30)
end

function M.test_run_eval(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local spec_file = core.input_or_arg(opts, 'Eval spec YAML file> ', 'file')
  if not spec_file then
    return
  end
  run('sf agent test run-eval --spec ' .. core.shellescape(spec_file), 30)
end

function M.trace_delete(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local trace_id = core.input_or_arg(opts, 'Trace ID> ')
  if not trace_id then
    return
  end
  run('sf agent trace delete --id ' .. core.shellescape(trace_id))
end

function M.trace_list()
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  run('sf agent trace list')
end

function M.trace_read(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local session = core.input_or_arg(opts, 'Session or run ID> ')
  if not session then
    return
  end
  run('sf agent trace read --id ' .. core.shellescape(session))
end

function M.validate_bundle(opts)
  if not core.ensure_sf() or not core.ensure_org() then
    return
  end
  local bundle = core.get_arg(opts) or vim.fn.input('Bundle path (default: force-app)> ', '', 'file')
  bundle = bundle ~= '' and bundle or 'force-app'
  run('sf agent validate authoring-bundle --bundle-path ' .. core.shellescape(bundle), 30)
end


M.commands = {
  { name = 'SfAgentActivate', fn = M.activate, opts = { desc = 'Activate an Agentforce agent', nargs = '?' } },
  { name = 'SfAgentAdlCreate', fn = M.adl_create, opts = { desc = 'Create an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentAdlDelete', fn = M.adl_delete, opts = { desc = 'Delete an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentAdlFileAdd', fn = M.adl_file_add, opts = { desc = 'Add a file to an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentAdlFileDelete', fn = M.adl_file_delete, opts = { desc = 'Delete a file from an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentAdlFileList', fn = M.adl_file_list, opts = { desc = 'List Agentforce data library files', nargs = '?' } },
  { name = 'SfAgentAdlGet', fn = M.adl_get, opts = { desc = 'Get an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentAdlList', fn = M.adl_list, opts = { desc = 'List Agentforce data libraries', nargs = 0 } },
  { name = 'SfAgentAdlStatus', fn = M.adl_status, opts = { desc = 'Show Agentforce data library status', nargs = '?' } },
  { name = 'SfAgentAdlUpdate', fn = M.adl_update, opts = { desc = 'Update an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentAdlUpload', fn = M.adl_upload, opts = { desc = 'Upload a file to an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentCreate', fn = M.create, opts = { desc = 'Create an Agentforce agent', nargs = '?' } },
  { name = 'SfAgentDeactivate', fn = M.deactivate, opts = { desc = 'Deactivate an Agentforce agent', nargs = '?' } },
  { name = 'SfAgentGenerateAgentSpec', fn = M.generate_agent_spec, opts = { desc = 'Generate an Agentforce agent spec', nargs = '?' } },
  { name = 'SfAgentGenerateAuthoringBundle', fn = M.generate_authoring_bundle, opts = { desc = 'Generate an Agentforce authoring bundle', nargs = '?' } },
  { name = 'SfAgentGenerateTemplate', fn = M.generate_template, opts = { desc = 'Generate an Agentforce template', nargs = '?' } },
  { name = 'SfAgentGenerateTestSpec', fn = M.generate_test_spec, opts = { desc = 'Generate an Agentforce test spec', nargs = '?' } },
  { name = 'SfAgentPreview', fn = M.preview, opts = { desc = 'Preview an Agentforce agent', nargs = '?' } },
  { name = 'SfAgentPreviewEnd', fn = M.preview_end, opts = { desc = 'End an Agentforce preview session', nargs = '?' } },
  { name = 'SfAgentPreviewSend', fn = M.preview_send, opts = { desc = 'Send a message to an Agentforce preview', nargs = '*' } },
  { name = 'SfAgentPreviewSessions', fn = M.preview_sessions, opts = { desc = 'List Agentforce preview sessions', nargs = 0 } },
  { name = 'SfAgentPreviewStart', fn = M.preview_start, opts = { desc = 'Start an Agentforce preview session', nargs = '?' } },
  { name = 'SfAgentPublishAuthoringBundle', fn = M.publish_bundle, opts = { desc = 'Publish an Agentforce authoring bundle', nargs = '?' } },
  { name = 'SfAgentTestCreate', fn = M.test_create, opts = { desc = 'Create an Agentforce test', nargs = '?' } },
  { name = 'SfAgentTestList', fn = M.test_list, opts = { desc = 'List Agentforce tests', nargs = 0 } },
  { name = 'SfAgentTestResults', fn = M.test_results, opts = { desc = 'Show Agentforce test results', nargs = '?' } },
  { name = 'SfAgentTestResume', fn = M.test_resume, opts = { desc = 'Resume an Agentforce test', nargs = '?' } },
  { name = 'SfAgentTestRun', fn = M.test_run, opts = { desc = 'Run an Agentforce test', nargs = '?' } },
  { name = 'SfAgentTestRunEval', fn = M.test_run_eval, opts = { desc = 'Run an Agentforce evaluation', nargs = '?' } },
  { name = 'SfAgentTraceDelete', fn = M.trace_delete, opts = { desc = 'Delete an Agentforce trace', nargs = '?' } },
  { name = 'SfAgentTraceList', fn = M.trace_list, opts = { desc = 'List Agentforce traces', nargs = 0 } },
  { name = 'SfAgentTraceRead', fn = M.trace_read, opts = { desc = 'Read an Agentforce trace', nargs = '?' } },
  { name = 'SfAgentValidateBundle', fn = M.validate_bundle, opts = { desc = 'Validate an Agentforce bundle', nargs = '?' } },
}

return M