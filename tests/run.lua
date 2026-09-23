-- Run from this bundle: nvim --headless -u NONE -i NONE -l tests/run.lua
local api, fn = vim.api, vim.fn
local bundle = fn.getcwd()
vim.opt.runtimepath:prepend(bundle)
local count, notices = 0, {}
vim.notify = function(message)
  notices[#notices + 1] = tostring(message)
end
local function check(value, message)
  assert(value, message)
  count = count + 1
end
local function wait(predicate, message)
  local done = vim.wait(10000, predicate, 10)
  if not done then
    print(vim.inspect(notices))
  end
  check(done, message)
end
local util, session = require('acp.util'), require('acp.session')
local model, permissions = require('acp.model'), require('acp.permissions')
local python = vim.env.ACP_TEST_PYTHON or 'python3'
local root = fn.tempname() .. ' project with spaces'
fn.mkdir(root, 'p')
fn.writefile({ 'disk text' }, root .. '/source.txt')
vim.ui.select = function(items, _, callback)
  for _, item in ipairs(items) do
    if type(item) == 'table' and item.optionId == 'yes' then
      callback(item)
      return
    end
  end
  if items[1] == 'False' then
    callback('False')
  else
    callback(items[#items])
  end
end
vim.ui.input = function(_, callback)
  callback('fixture')
end
vim.ui.open = function()
  return true
end
check(util.contains('/', '/tmp'), 'Root containment')
check(not util.contains(root, root .. '-escape/a'), 'Prefix sibling rejected')
check(util.utf8('\255a') == '�a' and util.utf8('λ') == 'λ', 'UTF-8 sanitation')
check(not util.display('\27]52;c;secret\7safe'):find('secret'), 'OSC clipboard sequence inert')
local select_ui, choose, outcome = vim.ui.select
vim.ui.select = function(_, _, cb)
  choose = cb
end
permissions.prompt({
  toolCall = { title = 'test' },
  options = {
    { name = 'Allow', optionId = 'allow', kind = 'allow_once' },
  },
}, function(result)
  outcome = result
end, 'cancel-test')
permissions.cancel('cancel-test')
choose({ name = 'Allow', optionId = 'allow', kind = 'allow_once' })
check(outcome.outcome.outcome == 'cancelled', 'Late permission cannot approve cancelled request')
vim.ui.select = select_ui
for _, version in ipairs({ 1, 2 }) do
  assert(require('acp').setup({
    protocol_version = version,
    agents = {
      mock = {
        cmd = {
          python,
          bundle .. '/tests/mock_agent.py',
          '--version',
          tostring(version),
          '--log',
          root .. '/v' .. version .. '.jsonl',
        },
      },
    },
    store = { enabled = true, directory = root .. '/state' },
    trust = function()
      return true
    end,
    timeouts = { request_ms = 5000, permission_ms = 5000, turn_ms = 15000, auth_ms = 10000 },
  }))
  local key, start_error
  session.start('mock', {
    cwd = root,
    on_exit = function(_, state)
      print(state.stderr)
    end,
    on_update = function()
      check(not vim.in_fast_event(), 'UI updates on main event loop')
    end,
  }, function(value, err)
    key, start_error = value, err
  end)
  wait(function()
    return key or start_error
  end, 'Handshake completes')
  check(key and not start_error, 'Handshake valid: ' .. tostring(start_error))
  local state = session.sessions[key]
  check(state.version == version and state.id == 'mock-v' .. version, 'Negotiated version and ID')
  api.nvim_cmd({ cmd = 'edit', args = { root .. '/source.txt' }, bang = true }, {})
  api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved editor text' })
  local finished, failure
  check(
    session.prompt(key, 'exercise', function(err)
      finished, failure = true, err
    end),
    'Prompt starts'
  )
  check(not session.prompt(key, 'concurrent'), 'Overlapping turns rejected')
  wait(function()
    return finished
  end, 'Streaming turn completes')
  check(not failure, 'Turn succeeds: ' .. tostring(failure) .. ' / ' .. (state.client.stderr or ''))
  check(state.phase == 'ready', 'Turn returns to ready')
  local found
  for _, item in pairs(state.model.items) do
    if item.kind == 'assistant' and item.content[1] and item.content[1].text == 'hello world' then
      found = true
    end
  end
  check(found, 'Chunks concatenate without inserted newlines')
  check(
    state.model.items['tool:tool'].kind == 'tool' and state.model.items['tool:tool'].tool_kind == 'read',
    'Protocol tool kind preserves renderer identity'
  )
  if version == 1 then
    check(util.read(root .. '/written.txt') == 'written by mock\n', 'Approved v1 write')
    check(next(state.terminals) == nil, 'Terminal release cleans state')
  else
    check(state.model.items['terminal:display'].data:sub(1, #'λ') == 'λ', 'V2 display terminal split UTF-8')
    check(
      not state.client.handlers['fs/read_text_file'] and not state.client.handlers['terminal/create'],
      'Removed APIs not advertised in v2'
    )
  end
  for _, item in ipairs({ { 'thinking', false }, { 'model', 'b' } }) do
    local done, error
    session.configure(key, item[1], item[2], function(err)
      done, error = true, err
    end)
    wait(function()
      return done
    end, 'Config option response')
    check(not error, 'Typed config value validated by official schema')
  end
  local authenticated
  session.authenticate(key, 'login', function(err)
    check(not err, 'Authentication')
    authenticated = true
  end)
  wait(function()
    return authenticated
  end, 'Authentication response')
  local listed
  session.remote(key, 'list', { cwd = root }, function(err, result)
    check(not err and #result.sessions == 1, 'Remote listing')
    listed = true
  end)
  wait(function()
    return listed
  end, 'Remote list response')
  local requests = 0
  session.on_extension(key, '_client', function(_, reply)
    requests = requests + 1
    vim.defer_fn(function()
      reply({ ok = true })
    end, 10)
  end)
  session.extension(key, '_batch', {}, function(err)
    check(not err, 'Extension')
  end)
  wait(function()
    return requests == 2 and next(state.client.incoming) == nil
  end, 'Batch replies')
  local timeout
  require('acp.rpc').request(state.client, '_timeout', {}, function(err)
    timeout = err
  end, 100)
  wait(function()
    return timeout
  end, 'Bounded RPC timeout')
  check(timeout.code == -32000, 'Timeout error delivered')
  finished, failure = false, nil
  session.prompt(key, 'wait', function(err, result)
    finished, failure = true, err
    check(result and result.stopReason == 'cancelled', 'Cancellation stop reason')
  end)
  wait(function()
    return version == 1 or state.phase == 'running'
  end, 'Wait turn starts')
  check(not finished, 'Acknowledgement does not end v2 turn')
  session.cancel(key)
  wait(function()
    return finished
  end, 'Cancellation settles')
  check(not failure, 'Cancellation succeeds')
  local auth_done, auth_error
  session.authenticate(key, 'terminal', function(err)
    auth_done, auth_error = true, err
  end)
  wait(function()
    return auth_done
  end, 'Terminal authentication reconnects')
  check(not auth_error and state.phase == 'ready', 'Terminal authentication restores session')
  check(not state.auth_job and not state.auth_timer and not state.auth_finish, 'Authentication resources closed')
  local false_done, false_value
  session.extension(key, '_false', {}, function(err, result)
    check(not err, 'Boolean response successful')
    false_done, false_value = true, result
  end)
  wait(function()
    return false_done
  end, 'False response completes')
  check(false_value == false, 'False result is preserved')
  local cancelled_handler = false
  session.on_extension(key, '_cancel_me', function()
    return function()
      cancelled_handler = true
    end
  end)
  session.extension(key, '_cancel_incoming', {}, function(err)
    check(not err, 'Reverse cancellation request')
  end)
  wait(function()
    return cancelled_handler and next(state.client.incoming) == nil
  end, 'Peer cancellation invokes handler cleanup')
  local auth_count, timeout_error = 0, nil
  local original_argv = state.spec.cmd
  state.spec.cmd = vim.list_extend(vim.deepcopy(original_argv), { '--login-delay', '1' })
  require('acp.config').options.timeouts.auth_ms = 100
  session.authenticate(key, 'terminal', function(err)
    auth_count, timeout_error = auth_count + 1, err
  end)
  wait(function()
    return auth_count > 0
  end, 'Authentication deadline settles')
  check(
    auth_count == 1 and timeout_error and not state.auth_job and not state.auth_timer,
    'Authentication timeout cleans resources'
  )
  state.spec.cmd = original_argv
  require('acp.config').options.timeouts.auth_ms = 10000
  local task = session.prompt_task(key, 'task')
  wait(function()
    return task:completed()
  end, 'Native async task completes ' .. version .. ' ' .. state.phase)
  check(task:wait().stopReason == 'end_turn', 'Native async result')
  check(#assert(require('acp.store').history(key)) > 3, 'Structured history retained')
  check(require('acp.store').append(key, 'mock', 'user', 'first\nsecond|third\n'), 'Multiline record appended')
  check(require('acp.store').flush(key), 'Atomic transcript flush')
  local saved_path = root .. '/state/' .. fn.sha256(key) .. '.json'
  check(bit.band(vim.uv.fs_stat(saved_path).mode, 511) == 384, 'Transcript file is private 0600')
  check(bit.band(vim.uv.fs_stat(root .. '/state').mode, 511) == 448, 'Transcript directory is private 0700')
  require('acp.ui').open(key, 'mock', 'split')
  check(not vim.bo.modifiable, 'Read-only chat buffer')
  session.stop(key)
  check(not session.sessions[key], 'Teardown removes state')
  local history = assert(require('acp.store').history(key))
  check(history[#history].content == 'first\nsecond|third\n', 'Multiline history roundtrip')
  local replayed, replay_error
  session.start('mock', { cwd = root, session_id = 'mock-v' .. version }, function(value, err)
    replayed, replay_error = value, err
  end)
  wait(function()
    return replayed or replay_error
  end, 'Resume/load handshake')
  check(replayed and not replay_error, 'Resume/load succeeds')
  check(#session.sessions[replayed].model.order > 0, 'Replay updates retained')
  session.stop(replayed)
  require('acp').teardown()
end
for _, versions in ipairs({ { 2, 1 }, { 1, 2 } }) do
  assert(require('acp').setup({
    protocol_version = versions[1],
    trust = function()
      return true
    end,
    agents = {
      mock = {
        cmd = {
          python,
          bundle .. '/tests/mock_agent.py',
          '--version',
          tostring(versions[2]),
          '--log',
          root .. '/negotiation.jsonl',
        },
      },
    },
  }))
  local done, negotiated_key, negotiation_error
  session.start('mock', { cwd = root }, function(key, err)
    done, negotiated_key, negotiation_error = true, key, err
  end)
  wait(function()
    return done
  end, 'Version negotiation returns')
  if versions[1] == 2 then
    check(negotiated_key and session.sessions[negotiated_key].version == 1, 'Draft opt-in can negotiate down to v1')
  else
    check(
      not negotiated_key and negotiation_error and next(session.sessions) == nil,
      'V1 default rejects unsolicited draft v2'
    )
  end
  require('acp').teardown()
end
for _, method in ipairs({ '_exit', '_overflow' }) do
  local rpc = require('acp.rpc')
  local client = assert(rpc.start({
    python,
    bundle .. '/tests/mock_agent.py',
    '--version',
    '1',
    '--log',
    root .. '/failures.jsonl',
  }))
  local failed
  rpc.request(client, method, {}, function(err)
    failed = err
  end)
  wait(function()
    return failed
  end, 'Transport failure settles pending ' .. method)
  check(client.closed and next(client.pending) == nil, 'Transport failure releases requests')
  rpc.stop(client, true)
end
local reducer = model.new()
check(
  model.apply(reducer, {
    sessionUpdate = 'agent_message',
    messageId = 'x',
    content = { { type = 'text', text = 'old' } },
  }, 2),
  'Whole message'
)
check(model.apply(reducer, { sessionUpdate = 'agent_message', messageId = 'x' }, 2), 'Omitted field')
check(reducer.items['message:x'].content[1].text == 'old', 'Omitted unchanged')
check(model.apply(reducer, { sessionUpdate = 'agent_message', messageId = 'x', content = vim.NIL }, 2), 'Null field')
check(#reducer.items['message:x'].content == 0, 'Null clears')
check(
  not model.apply(reducer, { sessionUpdate = 'agent_message_chunk', content = {} }, 2),
  'Malformed known update rejected'
)
check(model.apply(reducer, { sessionUpdate = '_future', payload = false }, 2), 'Unknown update stays inert')
check(
  not model.apply(reducer, { sessionUpdate = 'agent_message_chunk', messageId = 'bad', content = { type = 'text' } }, 2),
  'Missing first text chunk rejected'
)
local cycle = {}
cycle.self = cycle
check(not util.json(cycle), 'Cyclic local JSON bounded')
local deep = {}
local nested = deep
for _ = 1, 34 do
  nested.child = {}
  nested = nested.child
end
check(not util.structure(deep), 'Nested remote JSON bounded')
check(not util.display('\27]52;c;secret\27\\safe'):find('secret'), 'ST terminated OSC stripped')
local files = require('acp.files')
local state = { key = 'files', cwd = root, roots = { root }, generation = 0, closed = false }
local denied
files.read(state, { path = root .. '/../outside' }, function(_, err)
  denied = err
end)
check(denied, 'Traversal rejected')
assert(vim.uv.fs_symlink('/etc', root .. '/escape'))
check(not util.path(root, root .. '/escape/passwd'), 'Symlink escape rejected')
fn.writefile({ 'preserve' }, root .. '/unsaved.txt')
api.nvim_cmd({ cmd = 'edit', args = { root .. '/unsaved.txt' }, mods = { hide = true } }, {})
api.nvim_buf_set_lines(0, 0, -1, false, { 'user changes' })
denied = nil
files.write(state, { path = root .. '/unsaved.txt', content = 'overwrite' }, function(_, err)
  denied = err
end)
check(denied and util.read(root .. '/unsaved.txt') == 'preserve\n', 'Unsaved buffer protected')
fn.writefile({ 'before' }, root .. '/race.txt')
vim.ui.select = function(_, _, cb)
  choose = cb
end
denied = nil
files.write(state, { path = root .. '/race.txt', content = 'overwrite' }, function(_, err)
  denied = err
end)
fn.writefile({ 'changed on disk' }, root .. '/race.txt')
choose('Allow once')
check(
  denied and util.read(root .. '/race.txt') == 'changed on disk\n',
  'Changed disk file rejects stale write approval'
)
vim.ui.select = select_ui
local context = require('acp.context')
check(context.scaffold(root) == 2, 'Canonical minimal context scaffold')
check(context.scaffold(root) == 0, 'Scaffold does not overwrite')
fn.writefile({ '# Task' }, root .. '/agent/tasks/local.task.md')
local paths = assert(context.list(root))
check(
  vim.tbl_contains(paths, 'AGENT.md') and vim.tbl_contains(paths, 'agent/tasks/local.task.md'),
  'Recursive context browsing'
)
check(require('acp.registry').parse('{"agents":[{"id":"fixture","distribution":{}}]}').fixture, 'Registry agents array')
check(not require('acp.registry').get('fixture'), 'Registry metadata cannot execute packages')
assert(require('acp').setup())
vim.g.mapleader, vim.g.maplocalleader = ' ', '\\'
vim.keymap.set('n', '<leader>aa', '<Cmd>echo "mine"<CR>')
require('mappings.acpmap').setup()
check(fn.maparg('<leader>aa', 'n'):find('mine'), 'User mapping preserved')
require('mappings.acpmap').setup()
check(fn.maparg('<leader>aa', 'n'):find('mine'), 'Repeated mapping setup safe')
require('acp').teardown()
check(fn.maparg('<leader>aa', 'n'):find('mine'), 'Teardown preserves user mapping')
fn.writefile(notices, root .. '/notices.txt')
print(('PASS: %d assertions; wire logs: %s'):format(count, root))
vim.cmd('qa!')
