-- lua/utils/sf/agent.lua
local cmdutil = require('utils.sf.cmdutil')
local util = require('utils.sf.util')

local M = {}

local function run(cmd, height)
  util.open_term_cmd(cmd, height or 20)
end

function M.activate(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local api_name = cmdutil.input_or_arg(opts, 'Agent API name> ')
  if not api_name then return end
  local version = vim.fn.input('Version (blank = default/latest)> ')
  local cmd = 'sf agent activate --api-name ' .. util.shellescape(api_name)
  if version ~= '' then
    cmd = cmd .. ' --version ' .. util.shellescape(version)
  end
  run(cmd)
end

function M.adl_create(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local name = cmdutil.input_or_arg(opts, 'ADL name> ')
  if not name then return end
  run('sf agent adl create --name ' .. util.shellescape(name))
end

function M.adl_delete(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  run('sf agent adl delete --id ' .. util.shellescape(adl_id))
end

function M.adl_file_add(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  local file_path = cmdutil.input_required('File to add> ', 'file')
  if not file_path then return end
  run('sf agent adl file add --id ' .. util.shellescape(adl_id) .. ' --file ' .. util.shellescape(file_path), 30)
end

function M.adl_file_delete(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  local file_id = cmdutil.input_required('File ID> ')
  if not file_id then return end
  run('sf agent adl file delete --id ' .. util.shellescape(adl_id) .. ' --file-id ' .. util.shellescape(file_id))
end

function M.adl_file_list(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  run('sf agent adl file list --id ' .. util.shellescape(adl_id))
end

function M.adl_get(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  run('sf agent adl get --id ' .. util.shellescape(adl_id))
end

function M.adl_list()
  if not util.ensure_sf() or not util.ensure_org() then return end
  run('sf agent adl list')
end

function M.adl_status(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  run('sf agent adl status --id ' .. util.shellescape(adl_id))
end

function M.adl_update(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  local name = vim.fn.input('New ADL name (blank = unchanged)> ')
  local cmd = 'sf agent adl update --id ' .. util.shellescape(adl_id)
  if name ~= '' then
    cmd = cmd .. ' --name ' .. util.shellescape(name)
  end
  run(cmd)
end

function M.adl_upload(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local adl_id = cmdutil.input_or_arg(opts, 'ADL ID or name> ')
  if not adl_id then return end
  local file_path = cmdutil.input_required('File to upload> ', 'file')
  if not file_path then return end
  run('sf agent adl upload --id ' .. util.shellescape(adl_id) .. ' --file ' .. util.shellescape(file_path), 30)
end

function M.create(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local spec_file = cmdutil.input_or_arg(opts, 'Agent spec YAML file> ', 'file')
  if not spec_file then return end
  local agent_name = vim.fn.input('Agent name (blank = use spec/default)> ')
  local cmd = 'sf agent create --spec ' .. util.shellescape(spec_file)
  if agent_name ~= '' then
    cmd = cmd .. ' --agent-name ' .. util.shellescape(agent_name)
  end
  run(cmd, 30)
end

function M.deactivate(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local api_name = cmdutil.input_or_arg(opts, 'Agent API name> ')
  if not api_name then return end
  local version = vim.fn.input('Version (blank = default/latest)> ')
  local cmd = 'sf agent deactivate --api-name ' .. util.shellescape(api_name)
  if version ~= '' then
    cmd = cmd .. ' --version ' .. util.shellescape(version)
  end
  run(cmd)
end

function M.generate_agent_spec(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local spec = cmdutil.get_arg(opts) or vim.fn.input('Existing spec file (blank = none)> ', '', 'file')
  local cmd = 'sf agent generate agent-spec'
  if spec and spec ~= '' then
    cmd = cmd .. ' --spec ' .. util.shellescape(spec)
  end
  run(cmd, 30)
end

function M.generate_authoring_bundle(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local spec_file = cmdutil.input_or_arg(opts, 'Agent spec YAML file> ', 'file')
  if not spec_file then return end
  run('sf agent generate authoring-bundle --spec ' .. util.shellescape(spec_file), 30)
end

function M.generate_specs(opts)
  return M.generate_test_spec(opts)
end

function M.generate_template(opts)
  if not util.ensure_sf() or not util.ensure_project() then return end
  local api_name = cmdutil.input_or_arg(opts, 'Agent API name> ')
  if not api_name then return end
  run('sf agent generate template --api-name ' .. util.shellescape(api_name), 30)
end

function M.generate_test_spec(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local agent_name = cmdutil.input_or_arg(opts, 'Agent API name> ')
  if not agent_name then return end
  run('sf agent generate test-spec --name ' .. util.shellescape(agent_name), 30)
end

function M.preview(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local arg = cmdutil.get_arg(opts)
  local cmd = 'sf agent preview'
  if arg and arg ~= '' then
    cmd = cmd .. ' --api-name ' .. util.shellescape(arg)
    run(cmd, 30)
    return
  end
  local mode = vim.fn.input('Preview mode [api/bundle]> ')
  if mode == 'api' then
    local api_name = cmdutil.input_required('Agent API name> ')
    if not api_name then return end
    cmd = cmd .. ' --api-name ' .. util.shellescape(api_name)
  elseif mode == 'bundle' then
    local bundle = cmdutil.input_required('Authoring bundle name or path> ')
    if not bundle then return end
    cmd = cmd .. ' --authoring-bundle ' .. util.shellescape(bundle)
  end
  run(cmd, 30)
end

function M.preview_end(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local session = cmdutil.input_or_arg(opts, 'Session ID> ')
  if not session then return end
  run('sf agent preview end --id ' .. util.shellescape(session))
end

function M.preview_send(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local session = nil
  local message = nil
  if opts and opts.fargs and #opts.fargs > 0 then
    session = opts.fargs[1]
    if #opts.fargs > 1 then
      message = table.concat(vim.list_slice(opts.fargs, 2), ' ')
    end
  end
  if not session or session == '' then
    session = cmdutil.input_required('Session ID> ')
  end
  if not session then return end
  if not message or message == '' then
    message = cmdutil.input_required('Message> ')
  end
  if not message then return end
  run('sf agent preview send --id ' .. util.shellescape(session) .. ' --message ' .. util.shellescape(message), 20)
end

function M.preview_sessions()
  if not util.ensure_sf() or not util.ensure_org() then return end
  run('sf agent preview sessions')
end

function M.preview_start(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local agent_id = cmdutil.input_or_arg(opts, 'Agent API name or ID> ')
  if not agent_id then return end
  run('sf agent preview start --name ' .. util.shellescape(agent_id), 20)
end

function M.publish_bundle(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local bundle = cmdutil.get_arg(opts) or vim.fn.input('Bundle path (default: force-app)> ', '', 'file')
  bundle = bundle ~= '' and bundle or 'force-app'
  run('sf agent publish authoring-bundle --bundle-path ' .. util.shellescape(bundle), 30)
end

function M.test_create(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local spec_file = cmdutil.input_or_arg(opts, 'Test spec YAML file> ', 'file')
  if not spec_file then return end
  run('sf agent test create --spec ' .. util.shellescape(spec_file), 30)
end

function M.test_list()
  if not util.ensure_sf() or not util.ensure_org() then return end
  run('sf agent test list')
end

function M.test_results(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local run_id = cmdutil.input_or_arg(opts, 'Test run ID> ')
  if not run_id then return end
  run('sf agent test results --id ' .. util.shellescape(run_id))
end

function M.test_resume(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local run_id = cmdutil.input_or_arg(opts, 'Test run ID> ')
  if not run_id then return end
  run('sf agent test resume --id ' .. util.shellescape(run_id))
end

function M.test_run(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local suite = cmdutil.input_or_arg(opts, 'Test suite/spec file path> ', 'file')
  if not suite then return end
  run('sf agent test run --test-file ' .. util.shellescape(suite) .. ' --wait 5', 30)
end

function M.test_run_eval(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local spec_file = cmdutil.input_or_arg(opts, 'Eval spec YAML file> ', 'file')
  if not spec_file then return end
  run('sf agent test run-eval --spec ' .. util.shellescape(spec_file), 30)
end

function M.trace_delete(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local trace_id = cmdutil.input_or_arg(opts, 'Trace ID> ')
  if not trace_id then return end
  run('sf agent trace delete --id ' .. util.shellescape(trace_id))
end

function M.trace_list()
  if not util.ensure_sf() or not util.ensure_org() then return end
  run('sf agent trace list')
end

function M.trace_read(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local session = cmdutil.input_or_arg(opts, 'Session or run ID> ')
  if not session then return end
  run('sf agent trace read --id ' .. util.shellescape(session))
end

function M.validate_bundle(opts)
  if not util.ensure_sf() or not util.ensure_org() then return end
  local bundle = cmdutil.get_arg(opts) or vim.fn.input('Bundle path (default: force-app)> ', '', 'file')
  bundle = bundle ~= '' and bundle or 'force-app'
  run('sf agent validate authoring-bundle --bundle-path ' .. util.shellescape(bundle), 30)
end

return M
