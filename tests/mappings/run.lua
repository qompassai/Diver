-- Run from the bundle root: nvim --headless -u NONE -l tests/run.lua
-- Native APIs are real; external LSP/DAP services are controlled test doubles.
local api = vim.api
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
vim.g.maplocalleader = ','
vim.o.hidden = true
local passed, errors, notices = 0, {}, {}
local mock_notify = function(message, level)
    notices[#notices + 1] = tostring(message)
    if level == vim.log.levels.ERROR then
        errors[#errors + 1] = tostring(message)
    end
end
vim.notify = mock_notify
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end
local function map(lhs, mode)
    return vim.fn.maparg(lhs, mode or 'n', false, true)
end
local function press(lhs, mode)
    local found = map(lhs, mode)
    assert(type(found.callback) == 'function', lhs .. ' must be a Lua mapping')
    return found.callback()
end
local function set_ft(ft)
    vim.bo.filetype = ft
    api.nvim_exec_autocmds('FileType', { buffer = 0 })
end
local function groups_count()
    local count = 0
    for _, item in ipairs(api.nvim_get_autocmds({})) do
        if (item.group_name or ''):match('^NativeMappings_') or item.group_name == 'LanguageMappings' then
            count = count + 1
        end
    end
    return count
end
local root = vim.fn.tempname() .. ' task space $literal'
vim.fn.mkdir(root, 'p')
vim.fn.writefile({}, root .. '/pyproject.toml')
vim.fn.writefile({ 'print("native-task-ok")' }, root .. '/test_sample.py')
api.nvim_cmd({ cmd = 'edit', args = { root .. '/test_sample.py' }, magic = { bar = false, file = false } }, {})
set_ft('python')
local python_buf = api.nvim_get_current_buf()
local loader = require('mappings')
check(loader.setup(), 'all modules load')
check(map(',tt').buffer == 1, 'generic test key is buffer local for Python')
check(map(',tr').buffer == 1, 'Python run mapping is installed')
check(map('f').lhs == nil and map('ca').lhs == nil, 'native f/ca are preserved')
check(map('gc').rhs ~= '<Nop>' and map('gcc').rhs ~= '<Nop>', 'native comments are preserved')
check(map('j', 'c').lhs == nil and map('k', 'c').lhs == nil, 'command-line text is preserved')
check(map('<C-h>', 'i').lhs == nil, 'insert backspace is preserved')
local count = groups_count()
check(loader.setup(), 'setup may repeat')
check(groups_count() == count, 'setup does not duplicate autocmds')
vim.keymap.set('n', ',tt', function() end, { buffer = python_buf, desc = 'User test override' })
require('mappings.langmap').attach(python_buf)
check(map(',tt').desc == 'User test override', 'refresh preserves a user replacement')
loader.teardown()
check(map(',tt').desc == 'User test override', 'teardown preserves a user replacement')
vim.keymap.del('n', ',tt', { buffer = python_buf })
check(loader.setup(), 'reload after teardown')
set_ft('text')
check(map(',tt').lhs == nil and map(',tr').lhs == nil, 'FileType removes language actions')
set_ft('python')

local real_clients = vim.lsp.get_clients
local definition_method = true
local mock_clients = function(filter)
    if filter.bufnr ~= python_buf then
        return {}
    end
    return {
        {
            id = 700,
            name = 'python-test-lsp',
            supports_method = function(_, method, _bufnr)
                return definition_method
                    and (method == 'textDocument/definition' or method == 'textDocument/completion')
            end,
        },
    }
end
vim.lsp.get_clients = mock_clients
require('mappings.lspmap').on_attach({ buf = python_buf, data = { client_id = 700 } })
check(map('gd').buffer == 1, 'definition exists only with a supporting buffer client')
check(map('gD').lhs == nil, 'unsupported declaration is absent')
api.nvim_exec_autocmds('BufEnter', { buffer = python_buf })
check(map('<C-Space>', 'i').buffer == 1, 'completion is capability scoped')
definition_method = false
api.nvim_exec_autocmds('LspDetach', { buffer = python_buf, data = { client_id = 700 } })
vim.wait(20)
check(map('gd').lhs == nil, 'detached capability mapping is removed')
vim.lsp.get_clients = real_clients
api.nvim_exec_autocmds('BufEnter', { buffer = python_buf })

local linted, formatted
package.loaded.linters = {
    linters_by_ft = { python = { 'python-only' } },
    run = function(bufnr)
        linted = bufnr
    end,
    stop = function() end,
    reset = function() end,
}
package.loaded.formatters = {
    formatters_by_ft = { python = { { 'python-only' } } },
    format = function(opts)
        formatted = opts.bufnr
    end,
    stop = function() end,
}
api.nvim_exec_autocmds('BufEnter', { buffer = python_buf })
press(',cl')
press(',cf')
check(linted == python_buf and formatted == python_buf, 'runner dispatch stays buffer specific')
set_ft('text')
check(map(',cl').lhs == nil and map(',cf').lhs == nil, 'runner keys do not leak to another filetype')
set_ft('python')

local ran
local native = {
    run = function(config)
        ran = config.name
    end,
    step_into = function() end,
}
local wrapper = {
    backend = function()
        return native
    end,
    registry = function()
        return {
            configurations = {
                python = { { name = 'Python only', type = 'python', request = 'launch' } },
                rust = { { name = 'Rust must not appear', type = 'lldb', request = 'launch' } },
            },
        }
    end,
}
require('mappings.ddxmap').setup({ wrapper = wrapper, termdebug = false })
local real_select = vim.ui.select
local mock_select_items = function(items, _, callback)
    check(#items == 1 and items[1].label == 'Python only', 'DAP choices are filetype filtered')
    callback(items[1])
end
vim.ui.select = mock_select_items
press(',dr')
check(ran == 'Python only', 'debug launch receives the selected Python configuration')
vim.ui.select = real_select
require('mappings.ddxmap').setup({ termdebug = false })
check(map(',dr').lhs == nil, 'missing backend does not leave broken debug mappings')

local query
api.nvim_create_user_command('SfSoqlRun', function()
    query = 'soql'
end, {})
api.nvim_create_user_command('SfSoslRun', function()
    query = 'sosl'
end, {})
set_ft('soql')
press(',tr')
check(query == 'soql', 'SOQL generic run dispatch')
set_ft('sosl')
press(',tr')
check(query == 'sosl', 'SOSL generic run dispatch')
set_ft('python')

local language = require('mappings.langmap')
local real_system = vim.system
local spawned = 0
local mock_system_count = function(...)
    spawned = spawned + 1
    return real_system(...)
end
vim.system = mock_system_count
local choose
local mock_select_choose = function(_, _, callback)
    choose = callback
end
vim.ui.select = mock_select_choose
language.setup()
language.run('r', python_buf)
check(type(choose) == 'function', 'untrusted execution requests review')
language.cancel(python_buf)
choose('Run once')
check(spawned == 0, 'cancelled authorization cannot run')
language.run('r', python_buf)
api.nvim_buf_set_lines(python_buf, 0, -1, false, { 'print("changed")' })
choose('Run once')
check(spawned == 0, 'modified source cannot run from stale authorization')
vim.cmd.write()
vim.ui.select = real_select
language.setup({
    is_trusted = function()
        return true
    end,
})
language.run('r', python_buf)
check(
    vim.wait(5000, function()
        return table.concat(notices, '\n'):find('exit 0, signal 0', 1, true) ~= nil
    end, 10),
    'real Python subprocess completes'
)
check(spawned == 1, 'one action launches exactly one subprocess')
language.output()
local output = table.concat(api.nvim_buf_get_lines(0, 0, -1, false), '\n')
check(output:find('changed', 1, true) ~= nil, 'task output is retained')
api.nvim_set_current_buf(python_buf)
vim.system = real_system

local completion
local signals = {}
local mock_system_overflow = function(_, opts, callback)
    completion = callback
    vim.schedule(function()
        opts.stdout(nil, string.rep('x', 1024 * 1024 + 1))
    end)
    return {
        kill = function(_, signal)
            signals[#signals + 1] = signal
        end,
    }
end
vim.system = mock_system_overflow
language.run('r', python_buf)
check(
    vim.wait(1000, function()
        return #signals > 0
    end, 10),
    'output overflow cancels task'
)
completion({ code = 143, signal = 15 })
vim.wait(20)
language.output()
output = table.concat(api.nvim_buf_get_lines(0, 0, -1, false), '\n')
check(output:find('Output limit reached', 1, true) ~= nil, 'output overflow is reported')
api.nvim_set_current_buf(python_buf)
vim.system = real_system

set_ft('markdown')
api.nvim_buf_set_lines(0, 0, -1, false, { '$$x + y$$' })
press(',ml')
local namespace = api.nvim_get_namespaces().native_mapping_math
local marks = api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
check(#marks == 1 and marks[1][4].virt_text[1][1] == ' math: x + y', 'display math annotation')
set_ft('python')
check(map(',ml').lhs == nil, 'math mappings are removed for Python')
check(#api.nvim_buf_get_extmarks(0, namespace, 0, -1, {}) == 0, 'math extmarks are cleared')
vim.bo.modified = false
vim.cmd('runtime plugin/dir.lua')
check(map('-').rhs == '<Plug>(nvim-dir-up)', 'native parent key remains installed')
api.nvim_exec_autocmds('VimEnter', {})
press(' e')
api.nvim_feedkeys('', 'x', false)
vim.wait(50)
check(vim.bo.filetype == 'directory', 'action opens real native dir buffer')
check(map(',tt').lhs == nil, 'directory buffers receive no Python test mappings')

vim.cmd.enew()
local terminal = require('mappings.cicdmap')
terminal.toggle('horizontal')
local terminal_buf = api.nvim_get_current_buf()
check(vim.bo[terminal_buf].buftype == 'terminal', 'real native terminal starts')
terminal.toggle('horizontal')
terminal.toggle('horizontal')
check(api.nvim_get_current_buf() == terminal_buf, 'terminal reuses the same session')
terminal.toggle('horizontal')
api.nvim_buf_delete(terminal_buf, { force = true })
loader.teardown()
check(groups_count() == 0, 'teardown removes owned autocmds')
check(#errors == 0, 'unexpected errors: ' .. table.concat(errors, '\n'))
vim.fn.delete(root, 'rf')
print(('PASS: %d checks on %s'):format(passed, vim.inspect(vim.version())))
