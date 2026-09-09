-- /qompassai/Diver/lua/utils/dev/sf/agent.lua
-- Qompass AI Diver Salesforce Agentforce Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local core = require('utils.dev.sf.core')
local fn = vim.fn
local M = {}
local TERM_HEIGHT = 20
local LONG_TERM_HEIGHT = 30
local SOURCE_TYPES = {
  knowledge = true,
  retriever = true,
  sfdrive = true,
}
---@param argv string[]
---@param height? integer
local function run(argv, height)
  core.open_term_cmd(argv, height or TERM_HEIGHT)
end

---@param require_project? boolean
---@return boolean
local function ready(require_project)
  return core.ensure({
    org = true,
    project = require_project == true,
  })
end

---@param value string
---@return string
local function default_developer_name(value)
  local name = value:gsub('[^%w_]', '_'):gsub('_+', '_'):gsub('^_+', ''):gsub('_+$', '')
  if name:match('^%d') then
    name = 'Library_' .. name
  end
  return name
end

---@param prompt string
---@return string?, string?
local function prompt_selector(prompt)
  local mode = fn.input((prompt or 'Agent selector') .. ' [api/bundle]> '):lower()
  if mode ~= 'api' and mode ~= 'bundle' then
    core.notify('Selector must be `api` or `bundle`', vim.log.levels.WARN)
    return nil, nil
  end
  local value = core.input_required(mode == 'api' and 'Published agent API name> ' or 'Authoring bundle API name> ')
  if not value then
    return nil, nil
  end
  return mode == 'api' and '--api-name' or '--authoring-bundle', value
end

---@param argv string[]
---@param flag string?
---@param value string?
local function append_pair(argv, flag, value)
  if type(flag) == 'string' and flag ~= '' and type(value) == 'string' and value ~= '' then
    argv[#argv + 1] = flag
    argv[#argv + 1] = value
  end
end

---@param opts? SfCommandArgs
function M.activate(opts)
  if not ready() then
    return
  end
  local api_name = core.input_or_arg(opts, 'Agent API name> ')
  if not api_name then
    return
  end
  local argv = { 'sf', 'agent', 'activate', '--api-name', api_name }
  append_pair(argv, '--version', fn.input('Version (blank = choose interactively)> '))
  run(argv)
end

---@param opts? SfCommandArgs
function M.adl_create(opts)
  if not ready() then
    return
  end
  local name = core.input_or_arg(opts, 'Data library display name> ')
  if not name then
    return
  end
  local developer_name = fn.input('Data library developer name> ', default_developer_name(name))
  if developer_name == '' or not developer_name:match('^[%a][%w_]*$') then
    core.notify(
      'Developer name must start with a letter and contain only letters, numbers, or underscores',
      vim.log.levels.WARN
    )
    return
  end
  local source_type = fn.input('Source type [sfdrive/knowledge/retriever]> ', 'sfdrive'):lower()
  if not SOURCE_TYPES[source_type] then
    core.notify('Source type must be sfdrive, knowledge, or retriever', vim.log.levels.WARN)
    return
  end
  local argv = {
    'sf',
    'agent',
    'adl',
    'create',
    '--name',
    name,
    '--developer-name',
    developer_name,
    '--source-type',
    source_type,
  }
  if source_type == 'knowledge' then
    local primary_one = core.input_required('Primary index field 1> ')
    local primary_two = core.input_required('Primary index field 2> ')
    if not primary_one or not primary_two then
      return
    end
    append_pair(argv, '--primary-index-field1', primary_one)
    append_pair(argv, '--primary-index-field2', primary_two)
  elseif source_type == 'retriever' then
    local retriever_id = core.input_required('Active custom retriever ID> ')
    if not retriever_id then
      return
    end
    append_pair(argv, '--retriever-id', retriever_id)
  end
  run(argv, LONG_TERM_HEIGHT)
end

---@param opts? SfCommandArgs
function M.adl_delete(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  if library_id then
    run({ 'sf', 'agent', 'adl', 'delete', '--library-id', library_id })
  end
end

---@param opts? SfCommandArgs
function M.adl_file_add(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  local path = core.input_required('File to add> ', 'file')
  if library_id and path then
    run({ 'sf', 'agent', 'adl', 'file', 'add', '--library-id', library_id, '--path', path }, LONG_TERM_HEIGHT)
  end
end

---@param opts? SfCommandArgs
function M.adl_file_delete(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  local file_id = core.input_required('Grounding file ID> ')
  if library_id and file_id then
    run({ 'sf', 'agent', 'adl', 'file', 'delete', '--library-id', library_id, '--file-id', file_id })
  end
end

---@param opts? SfCommandArgs
function M.adl_file_list(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  if library_id then
    run({ 'sf', 'agent', 'adl', 'file', 'list', '--library-id', library_id })
  end
end

---@param opts? SfCommandArgs
function M.adl_get(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  if library_id then
    run({ 'sf', 'agent', 'adl', 'get', '--library-id', library_id })
  end
end

function M.adl_list()
  if ready() then
    run({
      'sf',
      'agent',
      'adl',
      'list',
    })
  end
end

---@param opts? SfCommandArgs
function M.adl_status(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  if library_id then
    run({ 'sf', 'agent', 'adl', 'status', '--library-id', library_id })
  end
end

---@param opts? SfCommandArgs
function M.adl_update(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  if not library_id then
    return
  end
  local name = fn.input('New display name> ')
  if name == '' then
    core.notify('A new display name is required', vim.log.levels.WARN)
    return
  end
  run({ 'sf', 'agent', 'adl', 'update', '--library-id', library_id, '--name', name })
end

---@param opts? SfCommandArgs
function M.adl_upload(opts)
  if not ready() then
    return
  end
  local library_id = core.input_or_arg(opts, 'Data library ID> ')
  local path = core.input_required('File to upload> ', 'file')
  if library_id and path then
    run({ 'sf', 'agent', 'adl', 'upload', '--library-id', library_id, '--file', path }, LONG_TERM_HEIGHT)
  end
end

---@param opts? SfCommandArgs
function M.create(opts)
  if not ready(true) then
    return
  end
  local spec = core.input_or_arg(opts, 'Agent spec YAML file> ', 'file')
  if not spec then
    return
  end
  local argv = { 'sf', 'agent', 'create', '--spec', spec }
  append_pair(argv, '--name', fn.input('Agent display name (blank = choose interactively)> '))
  append_pair(argv, '--api-name', fn.input('Agent API name (blank = derive from name)> '))
  run(argv, LONG_TERM_HEIGHT)
end

---@param opts? SfCommandArgs
function M.deactivate(opts)
  if not ready() then
    return
  end
  local api_name = core.input_or_arg(opts, 'Agent API name> ')
  if api_name then
    run({ 'sf', 'agent', 'deactivate', '--api-name', api_name })
  end
end

---@param opts? SfCommandArgs
function M.generate_agent_spec(opts)
  if not ready() then
    return
  end
  local spec = core.get_arg(opts) or fn.input('Existing spec file (blank = new spec)> ', '', 'file')
  local argv = { 'sf', 'agent', 'generate', 'agent-spec' }
  append_pair(argv, '--spec', spec)
  run(argv, LONG_TERM_HEIGHT)
end

---@param opts? SfCommandArgs
function M.generate_authoring_bundle(opts)
  if not ready(true) then
    return
  end
  local spec = core.input_or_arg(opts, 'Agent spec YAML file> ', 'file')
  if spec then
    run({ 'sf', 'agent', 'generate', 'authoring-bundle', '--spec', spec }, LONG_TERM_HEIGHT)
  end
end

---@param opts? SfCommandArgs
function M.generate_template(opts)
  if not core.ensure({ project = true }) then
    return
  end
  local args = core.get_args(opts)
  local agent_file = args[1] or core.input_required('Bot metadata file> ', 'file')
  local version = args[2] or core.input_required('Agent version> ')
  local source_org = args[3] or core.input_required('Namespaced scratch org alias> ')
  local output_dir = args[4] or fn.input('Output directory> ', 'force-app/main/default', 'dir')
  if not agent_file or not version or not source_org or output_dir == '' then
    return
  end
  run({
    'sf',
    'agent',
    'generate',
    'template',
    '--agent-file',
    agent_file,
    '--agent-version',
    version,
    '--source-org',
    source_org,
    '--output-dir',
    output_dir,
  }, LONG_TERM_HEIGHT)
end

---@param opts? SfCommandArgs
function M.generate_test_spec(opts)
  if not core.ensure({ project = true }) then
    return
  end
  local args = core.get_args(opts)
  local definition = args[1] or fn.input('Definition metadata file (blank = interactive)> ', '', 'file')
  local output = args[2] or fn.input('Output YAML file (blank = generated default)> ', '', 'file')
  local argv = { 'sf', 'agent', 'generate', 'test-spec' }
  append_pair(argv, '--from-definition', definition)
  append_pair(argv, '--output-file', output)
  run(argv, LONG_TERM_HEIGHT)
end

M.generate_specs = M.generate_test_spec

---@param opts? SfCommandArgs
function M.preview(opts)
  if not ready(true) then
    return
  end
  local argv = { 'sf', 'agent', 'preview' }
  local api_name = core.get_arg(opts)
  if api_name then
    append_pair(argv, '--api-name', api_name)
  else
    local flag, value = prompt_selector('Preview selector')
    if not flag then
      return
    end
    append_pair(argv, flag, value)
  end
  run(argv, LONG_TERM_HEIGHT)
end

---@param opts? SfCommandArgs
function M.preview_end(opts)
  if not ready(true) then
    return
  end
  local args = core.get_args(opts)
  local session_id = args[1] or core.input_required('Session ID> ')
  if not session_id then
    return
  end
  local flag, value = prompt_selector('Session owner')
  if not flag then
    return
  end
  run({ 'sf', 'agent', 'preview', 'end', '--session-id', session_id, flag, value })
end

---@param opts? SfCommandArgs
function M.preview_send(opts)
  if not ready(true) then
    return
  end
  local args = core.get_args(opts)
  local session_id = args[1] or core.input_required('Session ID> ')
  if not session_id then
    return
  end
  local flag, value = prompt_selector('Session owner')
  if not flag then
    return
  end
  local utterance = #args > 1 and table.concat(args, ' ', 2) or core.input_required('Utterance> ')
  if not utterance then
    return
  end
  run({
    'sf',
    'agent',
    'preview',
    'send',
    '--session-id',
    session_id,
    flag,
    value,
    '--utterance',
    utterance,
  })
end

function M.preview_sessions()
  if core.ensure() then
    run({
      'sf',
      'agent',
      'preview',
      'sessions',
    })
  end
end

---@param opts? SfCommandArgs
function M.preview_start(opts)
  if not ready(true) then
    return
  end
  local argv = { 'sf', 'agent', 'preview', 'start' }
  local api_name = core.get_arg(opts)
  if api_name then
    append_pair(argv, '--api-name', api_name)
  else
    local flag, value = prompt_selector('Preview selector')
    if not flag then
      return
    end
    append_pair(argv, flag, value)
    if flag == '--authoring-bundle' then
      local action_mode = fn.input('Action mode [simulate/live]> ', 'simulate'):lower()
      if action_mode == 'simulate' then
        argv[#argv + 1] = '--simulate-actions'
      elseif action_mode == 'live' then
        argv[#argv + 1] = '--use-live-actions'
      else
        core.notify('Action mode must be `simulate` or `live`', vim.log.levels.WARN)
        return
      end
    end
  end
  run(argv)
end

---@param opts? SfCommandArgs
function M.publish_bundle(opts)
  if not ready(true) then
    return
  end
  local api_name = core.input_or_arg(opts, 'Authoring bundle API name> ')
  if api_name then
    run({ 'sf', 'agent', 'publish', 'authoring-bundle', '--api-name', api_name }, LONG_TERM_HEIGHT)
  end
end

---@param opts? SfCommandArgs
function M.test_create(opts)
  if not ready(true) then
    return
  end
  local spec = core.input_or_arg(opts, 'Test spec YAML file> ', 'file')
  if spec then
    run({ 'sf', 'agent', 'test', 'create', '--spec', spec }, LONG_TERM_HEIGHT)
  end
end

function M.test_list()
  if ready() then
    run({ 'sf', 'agent', 'test', 'list' })
  end
end

---@param opts? SfCommandArgs
function M.test_results(opts)
  if not ready() then
    return
  end
  local job_id = core.input_or_arg(opts, 'Test job ID> ')
  if job_id then
    run({ 'sf', 'agent', 'test', 'results', '--job-id', job_id })
  end
end

---@param opts? SfCommandArgs
function M.test_resume(opts)
  if not ready() then
    return
  end
  local job_id = core.input_or_arg(opts, 'Test job ID> ')
  if job_id then
    run({ 'sf', 'agent', 'test', 'resume', '--job-id', job_id })
  end
end

---@param opts? SfCommandArgs
function M.test_run(opts)
  if not ready() then
    return
  end
  local api_name = core.input_or_arg(opts, 'Agent test API name> ')
  if api_name then
    run({ 'sf', 'agent', 'test', 'run', '--api-name', api_name, '--wait', '5' }, LONG_TERM_HEIGHT)
  end
end

---@param opts? SfCommandArgs
function M.test_run_eval(opts)
  if not ready() then
    return
  end
  local spec = core.input_or_arg(opts, 'Evaluation spec YAML or JSON file> ', 'file')
  if spec then
    run({ 'sf', 'agent', 'test', 'run-eval', '--spec', spec }, LONG_TERM_HEIGHT)
  end
end

---@param opts? SfCommandArgs
function M.trace_delete(opts)
  if not core.ensure({ project = true }) then
    return
  end
  local session_id = core.input_or_arg(opts, 'Session ID> ')
  if session_id then
    run({ 'sf', 'agent', 'trace', 'delete', '--session-id', session_id })
  end
end

function M.trace_list()
  if core.ensure({ project = true }) then
    run({ 'sf', 'agent', 'trace', 'list' })
  end
end

---@param opts? SfCommandArgs
function M.trace_read(opts)
  if not core.ensure({ project = true }) then
    return
  end
  local session_id = core.input_or_arg(opts, 'Session ID> ')
  if session_id then
    run({ 'sf', 'agent', 'trace', 'read', '--session-id', session_id })
  end
end

---@param opts? SfCommandArgs
function M.validate_bundle(opts)
  if not ready(true) then
    return
  end
  local api_name = core.input_or_arg(opts, 'Authoring bundle API name> ')
  if api_name then
    run({ 'sf', 'agent', 'validate', 'authoring-bundle', '--api-name', api_name }, LONG_TERM_HEIGHT)
  end
end

M.commands = {
  { name = 'SfAgentActivate', fn = M.activate, opts = { desc = 'Activate an Agentforce agent', nargs = '?' } },
  {
    name = 'SfAgentAdlCreate',
    fn = M.adl_create,
    opts = { desc = 'Create an Agentforce data library', nargs = '?' },
  },
  {
    name = 'SfAgentAdlDelete',
    fn = M.adl_delete,
    opts = { desc = 'Delete an Agentforce data library', nargs = '?' },
  },
  {
    name = 'SfAgentAdlFileAdd',
    fn = M.adl_file_add,
    opts = { desc = 'Add a file to an Agentforce data library', nargs = '?' },
  },
  {
    name = 'SfAgentAdlFileDelete',
    fn = M.adl_file_delete,
    opts = { desc = 'Delete a file from an Agentforce data library', nargs = '?' },
  },
  {
    name = 'SfAgentAdlFileList',
    fn = M.adl_file_list,
    opts = { desc = 'List Agentforce data library files', nargs = '?' },
  },
  { name = 'SfAgentAdlGet', fn = M.adl_get, opts = { desc = 'Get an Agentforce data library', nargs = '?' } },
  { name = 'SfAgentAdlList', fn = M.adl_list, opts = { desc = 'List Agentforce data libraries', nargs = 0 } },
  {
    name = 'SfAgentAdlStatus',
    fn = M.adl_status,
    opts = { desc = 'Show Agentforce data library status', nargs = '?' },
  },
  {
    name = 'SfAgentAdlUpdate',
    fn = M.adl_update,
    opts = { desc = 'Update an Agentforce data library', nargs = '?' },
  },
  {
    name = 'SfAgentAdlUpload',
    fn = M.adl_upload,
    opts = { desc = 'Upload a file to an Agentforce data library', nargs = '?' },
  },
  { name = 'SfAgentCreate', fn = M.create, opts = { desc = 'Create an Agentforce agent', nargs = '?' } },
  { name = 'SfAgentDeactivate', fn = M.deactivate, opts = { desc = 'Deactivate an Agentforce agent', nargs = '?' } },
  {
    name = 'SfAgentGenerateAgentSpec',
    fn = M.generate_agent_spec,
    opts = { desc = 'Generate an Agentforce agent spec', nargs = '?' },
  },
  {
    name = 'SfAgentGenerateAuthoringBundle',
    fn = M.generate_authoring_bundle,
    opts = { desc = 'Generate an Agentforce authoring bundle', nargs = '?' },
  },
  {
    name = 'SfAgentGenerateTemplate',
    fn = M.generate_template,
    opts = { complete = 'file', desc = 'Generate an Agentforce template', nargs = '*' },
  },
  {
    name = 'SfAgentGenerateTestSpec',
    fn = M.generate_test_spec,
    opts = { complete = 'file', desc = 'Generate an Agentforce test spec', nargs = '*' },
  },
  { name = 'SfAgentPreview', fn = M.preview, opts = { desc = 'Preview an Agentforce agent', nargs = '?' } },
  {
    name = 'SfAgentPreviewEnd',
    fn = M.preview_end,
    opts = { desc = 'End an Agentforce preview session', nargs = '*' },
  },
  {
    name = 'SfAgentPreviewSend',
    fn = M.preview_send,
    opts = { desc = 'Send an utterance to an Agentforce preview', nargs = '*' },
  },
  {
    name = 'SfAgentPreviewSessions',
    fn = M.preview_sessions,
    opts = { desc = 'List Agentforce preview sessions', nargs = 0 },
  },
  {
    name = 'SfAgentPreviewStart',
    fn = M.preview_start,
    opts = { desc = 'Start an Agentforce preview session', nargs = '?' },
  },
  {
    name = 'SfAgentPublishAuthoringBundle',
    fn = M.publish_bundle,
    opts = { desc = 'Publish an Agentforce authoring bundle', nargs = '?' },
  },
  { name = 'SfAgentTestCreate', fn = M.test_create, opts = { desc = 'Create an Agentforce test', nargs = '?' } },
  { name = 'SfAgentTestList', fn = M.test_list, opts = { desc = 'List Agentforce tests', nargs = 0 } },
  { name = 'SfAgentTestResults', fn = M.test_results, opts = { desc = 'Show Agentforce test results', nargs = '?' } },
  { name = 'SfAgentTestResume', fn = M.test_resume, opts = { desc = 'Resume an Agentforce test', nargs = '?' } },
  { name = 'SfAgentTestRun', fn = M.test_run, opts = { desc = 'Run an Agentforce test', nargs = '?' } },
  {
    name = 'SfAgentTestRunEval',
    fn = M.test_run_eval,
    opts = { desc = 'Run an Agentforce evaluation', nargs = '?' },
  },
  {
    name = 'SfAgentTraceDelete',
    fn = M.trace_delete,
    opts = { desc = 'Delete Agentforce traces by session', nargs = '?' },
  },
  { name = 'SfAgentTraceList', fn = M.trace_list, opts = { desc = 'List Agentforce traces', nargs = 0 } },
  { name = 'SfAgentTraceRead', fn = M.trace_read, opts = { desc = 'Read an Agentforce trace', nargs = '?' } },
  {
    name = 'SfAgentValidateBundle',
    fn = M.validate_bundle,
    opts = { desc = 'Validate an Agentforce authoring bundle', nargs = '?' },
  },
}

return M