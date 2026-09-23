-- Run from this bundle: nvim --headless -u NONE -i NONE -l tests/dir.lua
local api, fn = vim.api, vim.fn
local bundle = fn.getcwd()
vim.opt.runtimepath:prepend(bundle)
local count = 0
local function check(value, label)
  assert(value, label)
  count = count + 1
end
local notices = {}
vim.notify = function(message)
  notices[#notices + 1] = message
end
for _, path in ipairs({ 'init.lua', 'lua/config/nav/init.lua', 'lua/config/nav/nt.lua', 'plugin/dir.lua' }) do
  check(loadfile(path), 'Lua syntax: ' .. path)
end
check(dofile('plugin/dir.lua') ~= nil, 'Compatibility shim can be explicitly loaded')
check(vim.g.loaded_nvim_dir_plugin == nil, 'Compatibility shim leaves the native guard unset')
local nt = require('config.nav.nt')
vim.g.loaded_nvim_dir_plugin = false
check(nt.setup() == false, 'Defined false guard is reported as blocked')
check(nt.setup() == false and #notices == 1, 'Repeated failure reports once')
vim.g.loaded_nvim_dir_plugin = nil
local runtime = vim.env.VIMRUNTIME
vim.env.VIMRUNTIME = bundle .. '/missing-runtime'
check(nt.setup() == false and notices[#notices]:find('missing:', 1, true), 'Missing runtime is identified')
vim.env.VIMRUNTIME = runtime
check(nt.setup({ width = 35 }), 'Loads the active native runtime before normal plugin startup')
check(
  type(fn.maparg('<Plug>(nvim-dir-reload)', 'n', false, true).callback) == 'function',
  'Native reload callback exists'
)
local handlers = #api.nvim_get_autocmds({ group = 'nvim.dir' })
check(nt.setup(), 'Repeated successful setup')
check(#api.nvim_get_autocmds({ group = 'nvim.dir' }) == handlers, 'Native handlers are not duplicated')
check(#api.nvim_get_autocmds({ group = 'NativeExplorerConfig', event = 'User' }) == 1, 'One rendering hook')
check(#api.nvim_get_autocmds({ group = 'nvim.dir', event = 'BufReadCmd' }) == 0, 'No wildcard file-read shim')
vim.cmd('runtime! plugin/dir.lua')
check(#api.nvim_get_autocmds({ group = 'nvim.dir' }) == handlers, 'Automatic plugin pass stays idempotent')
api.nvim_exec_autocmds('VimEnter', {})
local root = fn.tempname() .. ' directory space'
fn.mkdir(root .. '/subdirectory', 'p')
fn.writefile({ 'real file contents' }, root .. '/alpha.txt')
fn.writefile({ 'hidden' }, root .. '/.hidden')
api.nvim_cmd({ cmd = 'edit', args = { root .. '/alpha.txt' } }, {})
check(api.nvim_get_current_line() == 'real file contents', 'Ordinary files retain their contents')
local source = api.nvim_get_current_buf()
nt.open(root)
check(
  vim.wait(3000, function()
    return vim.bo.filetype == 'directory'
  end, 10),
  'Native directory opens'
)
vim.wait(30, function()
  return false
end, 5)
local listing = api.nvim_get_current_buf()
check(vim.b.nvim_dir ~= nil and vim.bo.buftype == 'nowrite', 'Real native directory state')
check(not vim.bo.modifiable, 'Read-only listing')
local lines = api.nvim_buf_get_lines(0, 0, -1, false)
check(vim.deep_equal(lines, { 'subdirectory/', 'alpha.txt' }), 'Directories sorted first and hidden entries filtered')
check(fn.getcwd() == root, 'Native buffer-local working directory')
check(fn.bufnr('#') == source, 'Alternate file preserved')
check(fn.maparg('-', 'n', false, true).buffer == 1, 'Parent mapping stays buffer-local')
fn.writefile({ 'new file' }, root .. '/beta.txt')
nt.refresh()
api.nvim_feedkeys('', 'x', false)
check(
  vim.wait(3000, function()
    return vim.tbl_contains(api.nvim_buf_get_lines(listing, 0, -1, false), 'beta.txt')
  end, 10),
  'Refresh discovers new files'
)
fn.search('^alpha.txt$', 'w')
nt.open_selected()
check(api.nvim_get_current_line() == 'real file contents', 'Opening a selected file reads actual contents')
nt.close()
api.nvim_cmd({ cmd = 'edit', args = { root } }, {})
check(
  vim.wait(3000, function()
    return vim.bo.filetype == 'directory'
  end, 10),
  ':edit directory works'
)
local loaded = {}
for _, name in ipairs({ 'fzf', 'nt', 'ripgrep', 'searxng' }) do
  package.loaded['config.nav.' .. name] = {
    setup = function()
      loaded[#loaded + 1] = name
    end,
  }
end
package.preload['config.nav.neotree'] = function()
  error('Neo-tree must not be loaded')
end
require('config.nav').nav_config({ debug = true })
check(vim.deep_equal(loaded, { 'fzf', 'nt', 'ripgrep', 'searxng' }), 'Alphabetical native navigation modules')
vim.cmd.enew()
fn.delete(root, 'rf')
print(('PASS: %d directory checks on %s'):format(count, tostring(vim.version())))
vim.cmd('qa!')
