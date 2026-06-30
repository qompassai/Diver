-- /qompassai/Diver/lua/utils/ddx.lua
-- Qompass AI Diver Util Differential Diagnosis (DDX) config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local fn = vim.fn
local notify = vim.notify
local uv = vim.uv
local levels = vim.log.levels
local M = {}
local ddx_group = api.nvim_create_augroup('QompassDDX', {
  clear = true,
})
local function strip_ansi(bufnr)
  local cur = api.nvim_get_current_buf()
  if bufnr and api.nvim_buf_is_valid(bufnr) and bufnr ~= cur then
    api.nvim_set_current_buf(bufnr)
  end
  vim.cmd([[%s/\%x1b\[[0-9;]*m//g]])
  if bufnr and api.nvim_buf_is_valid(cur) and api.nvim_get_current_buf() ~= cur then
    api.nvim_set_current_buf(cur)
  end
end

local function scandir(root)
  local handle = uv.fs_scandir(root)
  if not handle then
    return {}
  end

  local results = {}
  while true do
    local name, t = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    results[#results + 1] = {
      name = name,
      type = t,
    }
  end
  return results
end

local function to_module(root, path)
  local rel = path:gsub('^' .. vim.pesc(root) .. '/?', '')
  rel = rel:gsub('%.lua$', '')
  rel = rel:gsub('/', '.')
  rel = rel:gsub('%.init$', '')
  return rel
end

local function collect_lua_files(root)
  local files = {}

  local function walk(dir)
    for _, entry in ipairs(scandir(dir)) do
      local full = dir .. '/' .. entry.name
      if entry.type == 'file' and entry.name:match('%.lua$') then
        files[#files + 1] = full
      elseif entry.type == 'directory' then
        walk(full)
      end
    end
  end

  walk(root)
  table.sort(files)
  return files
end

local function make_qf_item(file, text, lnum, col)
  return {
    filename = file,
    lnum = lnum or 1,
    col = col or 1,
    text = text,
  }
end

local function write_log(fh, msg)
  if fh then
    fh:write(msg .. '\n')
  end
end

local function syntaxcheck_file(file)
  local chunk, err = loadfile(file)
  if not chunk then
    return false, tostring(err)
  end
  return true, nil
end

local function parse_lua_error(err)
  if type(err) ~= 'string' then
    return nil, nil
  end

  local lnum, msg = err:match(':(%d+):%s*(.+)$')
  if lnum then
    return tonumber(lnum), msg
  end

  return nil, err
end

local function safe_require(mod)
  return pcall(require, mod)
end

local function check_lazy_state(qf_items, fh)
  local lazy_loaded = package.loaded['lazy'] ~= nil

  write_log(fh, ('[probe] lazy loaded: %s'):format(tostring(lazy_loaded)))
  write_log(fh, ('[probe] g:lazy_did_setup: %s'):format(tostring(vim.g.lazy_did_setup)))

  if vim.g.lazy_did_setup and not lazy_loaded then
    qf_items[#qf_items + 1] = make_qf_item(
      fn.stdpath('config') .. '/init.lua',
      "[lazy] g:lazy_did_setup is set but package.loaded['lazy'] is nil"
    )
  end
end

local function check_pack_state(qf_items, fh)
  local has_pack = type(vim.pack) == 'table'
  local has_add = type(vim.pack and vim.pack.add) == 'function'
  local has_update = type(vim.pack and vim.pack.update) == 'function'

  write_log(fh, ('[probe] vim.pack available: %s'):format(tostring(has_pack)))
  write_log(fh, ('[probe] vim.pack.add available: %s'):format(tostring(has_add)))
  write_log(fh, ('[probe] vim.pack.update available: %s'):format(tostring(has_update)))

  if not has_pack then
    qf_items[#qf_items + 1] =
      make_qf_item(fn.stdpath('config') .. '/init.lua', '[vim.pack] vim.pack table is unavailable')
    return
  end

  if not has_add then
    qf_items[#qf_items + 1] =
      make_qf_item(fn.stdpath('config') .. '/init.lua', '[vim.pack] vim.pack.add is unavailable')
  end

  if not has_update then
    qf_items[#qf_items + 1] =
      make_qf_item(fn.stdpath('config') .. '/init.lua', '[vim.pack] vim.pack.update is unavailable')
  end
end

local function check_lualine_state(qf_items, fh)
  local config_file = fn.stdpath('config') .. '/lua/config/ui/line.lua'
  local loaded = package.loaded['lualine'] ~= nil
  local ok_line, line_mod = safe_require('config.ui.line')
  local ok_lualine, lualine_mod = safe_require('lualine')
  local statusline = vim.o.statusline

  write_log(fh, ("[probe:lualine] package.loaded['lualine'] = %s"):format(tostring(loaded)))
  write_log(fh, ("[probe:lualine] require('config.ui.line') = %s"):format(tostring(ok_line)))
  write_log(fh, ("[probe:lualine] require('lualine') = %s"):format(tostring(ok_lualine)))
  write_log(fh, ('[probe:lualine] vim.o.statusline = %s'):format(statusline == '' and '<empty>' or statusline))

  if not ok_line then
    qf_items[#qf_items + 1] =
      make_qf_item(config_file, '[lualine] failed to require config.ui.line: ' .. tostring(line_mod))
    return
  end

  if type(line_mod) ~= 'table' or type(line_mod.setup) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(config_file, '[lualine] config.ui.line.setup missing or invalid')
  end

  if not ok_lualine then
    qf_items[#qf_items + 1] =
      make_qf_item(config_file, '[lualine] plugin module could not be required: ' .. tostring(lualine_mod))
  end

  if not loaded then
    qf_items[#qf_items + 1] = make_qf_item(config_file, '[lualine] plugin module is not loaded at runtime')
  end

  if statusline == '' then
    qf_items[#qf_items + 1] = make_qf_item(config_file, '[lualine] vim.o.statusline is empty')
  end
end

local function check_luarocks_state(qf_items, fh)
  local file = fn.stdpath('config') .. '/lua/config/lang/lua.lua'
  local ok_cfg, cfg = safe_require('config.lang.lua')

  write_log(fh, ("[probe:luarocks] require('config.lang.lua') = %s"):format(tostring(ok_cfg)))

  if not ok_cfg then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] failed to require config.lang.lua: ' .. tostring(cfg))
    return
  end

  if type(cfg.lua_luarocks) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] config.lang.lua.lua_luarocks is missing')
    return
  end

  local ok_opts, opts = pcall(cfg.lua_luarocks, {})
  write_log(fh, ('[probe:luarocks] lua_luarocks({}) = %s'):format(tostring(ok_opts)))

  if not ok_opts then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] lua_luarocks() failed: ' .. tostring(opts))
    return
  end

  if type(opts) ~= 'table' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] lua_luarocks() did not return a table')
    return
  end

  if type(opts.rocks) ~= 'table' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] lua_luarocks() returned no rocks table')
  end

  local ok_lr, lr = safe_require('luarocks-nvim')
  write_log(fh, ("[probe:luarocks] require('luarocks-nvim') = %s"):format(tostring(ok_lr)))

  if not ok_lr then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] luarocks-nvim module missing: ' .. tostring(lr))
    return
  end

  if type(lr.setup) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[luarocks] luarocks-nvim.setup missing or invalid')
  end
end

local function check_lsp_state(qf_items, fh)
  local file = fn.stdpath('config') .. '/lua/config/core/lsp.lua'
  local ok, result = safe_require('config.core.lsp')

  write_log(fh, ("[probe:lsp] require('config.core.lsp') = %s"):format(tostring(ok)))
  write_log(fh, ('[probe:lsp] active clients = %d'):format(#vim.lsp.get_clients()))

  if not ok then
    qf_items[#qf_items + 1] = make_qf_item(file, '[lsp] failed to require config.core.lsp: ' .. tostring(result))
  end
end

local function check_mapping_modules(qf_items, fh)
  local checks = {
    {
      mod = 'mappings.ddxmap',
      file = fn.stdpath('config') .. '/lua/mappings/ddxmap.lua',
    },
  }

  for _, item in ipairs(checks) do
    local ok, result = safe_require(item.mod)
    write_log(fh, ("[probe:mappings] require('%s') = %s"):format(item.mod, tostring(ok)))

    if not ok then
      qf_items[#qf_items + 1] =
        make_qf_item(item.file, ('[mappings] failed to require %s: %s'):format(item.mod, tostring(result)))
    end
  end
end

local function check_plugin_specs(qf_items, fh)
  local file = fn.stdpath('config') .. '/lua/plugins/init.lua'
  local ok, plugins_mod = safe_require('plugins')

  write_log(fh, ("[probe:plugins] require('plugins') = %s"):format(tostring(ok)))

  if not ok then
    qf_items[#qf_items + 1] =
      make_qf_item(file, '[plugins] failed to require plugins module: ' .. tostring(plugins_mod))
    return
  end

  if type(plugins_mod.validate_specs) ~= 'function' then
    qf_items[#qf_items + 1] = make_qf_item(file, '[plugins] validate_specs() missing')
    return
  end

  local ok_validate, valid, errors = pcall(plugins_mod.validate_specs)
  if not ok_validate then
    qf_items[#qf_items + 1] = make_qf_item(file, '[plugins] validate_specs() crashed: ' .. tostring(valid))
    return
  end

  write_log(fh, ('[probe:plugins] validate_specs() = %s'):format(tostring(valid)))

  if not valid and type(errors) == 'table' then
    for _, err in ipairs(errors) do
      qf_items[#qf_items + 1] = make_qf_item(file, '[plugins] ' .. err)
    end
  end
end

local function syntaxcheck_all(lua_root, files, qf_items, fh)
  local ok_count = 0
  local err_count = 0

  for _, file in ipairs(files) do
    local mod = to_module(lua_root, file)
    local ok, err = syntaxcheck_file(file)

    if ok then
      ok_count = ok_count + 1
      write_log(fh, ('[syntax] OK: %s | %s'):format(mod, file))
    else
      err_count = err_count + 1
      local short_file = file:gsub('^' .. vim.pesc(lua_root) .. '/?', '')
      local lnum, msg = parse_lua_error(err)

      qf_items[#qf_items + 1] = make_qf_item(file, ('[syntax:%s] %s'):format(mod, msg or err), lnum or 1, 1)

      write_log(fh, ('[syntax] FAILED: %s | %s'):format(mod, short_file))
      write_log(fh, err)
      write_log(fh, string.rep('-', 80))
    end
  end

  return ok_count, err_count
end

local function check_modules_in_root(root, prefix, qf_items, fh, expect_table)
  if fn.isdirectory(root) == 0 then
    write_log(fh, ('[probe:%s] root missing: %s'):format(prefix, root))
    return
  end

  local files = collect_lua_files(root)
  for _, file in ipairs(files) do
    local mod = to_module(root, file)
    local full_mod = prefix .. '.' .. mod
    local ok, result = safe_require(full_mod)

    write_log(fh, ("[probe:%s] require('%s') = %s"):format(prefix, full_mod, tostring(ok)))

    if not ok then
      qf_items[#qf_items + 1] =
        make_qf_item(file, ('[%s] failed to require %s: %s'):format(prefix, full_mod, tostring(result)))
    elseif expect_table and type(result) ~= 'table' then
      qf_items[#qf_items + 1] = make_qf_item(file, ('[%s] %s did not return a table'):format(prefix, full_mod))
    end
  end
end

local function parse_luacheck_line(line)
  local file, lnum, col, code, msg = line:match('^([^:]+):(%d+):(%d+): %(([%w%d]+)%) (.+)$')
  if file then
    return {
      filename = file,
      lnum = tonumber(lnum),
      col = tonumber(col),
      text = ('[luacheck:%s] %s'):format(code, msg),
    }
  end

  file, lnum, col, msg = line:match('^([^:]+):(%d+):(%d+): (.+)$')
  if file then
    return {
      filename = file,
      lnum = tonumber(lnum),
      col = tonumber(col),
      text = '[luacheck] ' .. msg,
    }
  end
end
local function run_luacheck(paths, qf_items, fh)
  if fn.executable('luacheck') ~= 1 then
    write_log(fh, '[probe:luacheck] luacheck not found in PATH')
    return
  end
  local cmd = vim.list_extend({
    'luacheck',
    '--formatter',
    'plain',
    '--codes',
  }, paths)

  local result = vim.system(cmd, { text = true }):wait()

  write_log(fh, ('[probe:luacheck] exit_code=%s'):format(tostring(result.code)))

  local output = {}
  if result.stdout and result.stdout ~= '' then
    vim.list_extend(output, vim.split(result.stdout, '\n', { trimempty = true }))
  end
  if result.stderr and result.stderr ~= '' then
    vim.list_extend(output, vim.split(result.stderr, '\n', { trimempty = true }))
  end
  for _, line in ipairs(output) do
    write_log(fh, '[probe:luacheck] ' .. line)
    local item = parse_luacheck_line(line)
    if item then
      qf_items[#qf_items + 1] = item
    end
  end
end
local function runtimecheck(qf_items, fh)
  write_log(fh, '')
  write_log(fh, '[runtime] starting targeted probes')
  write_log(fh, string.rep('=', 80))
  check_lazy_state(qf_items, fh)
  check_pack_state(qf_items, fh)
  check_lualine_state(qf_items, fh)
  check_luarocks_state(qf_items, fh)
  check_lsp_state(qf_items, fh)
  check_mapping_modules(qf_items, fh)
  check_plugin_specs(qf_items, fh)
  check_modules_in_root(fn.stdpath('config') .. '/lsp', 'lsp', qf_items, fh, true)
  run_luacheck({
    fn.stdpath('config') .. '/lua',
    fn.stdpath('config') .. '/lsp',
  }, qf_items, fh)
end

local function finish_qf(qf_items)
  if #qf_items > 0 then
    fn.setqflist({}, 'r', {
      title = 'ConfigSelfCheck',
      items = qf_items,
    })
    vim.cmd('copen')
  else
    fn.setqflist({}, 'r', {
      title = 'ConfigSelfCheck',
      items = {},
    })
  end
end

function M.buffer_diagnostics(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  vim.diagnostic.setloclist({
    open = false,
    title = 'Buffer Diagnostics',
  })
  vim.cmd('lopen')
end
function M.workspace_diagnostics()
  vim.diagnostic.setqflist({
    open = true,
    title = 'Workspace Diagnostics',
  })
end
--- @param bufnr? integer
function M.buffer_diagnostics(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  vim.diagnostic.setloclist({
    open = false,
    title = 'Buffer Diagnostics',
  })
  vim.cmd('lopen')
end
function M.document_symbols()
  vim.lsp.buf.document_symbol()
end
function M.workspace_symbols()
  vim.ui.input({
    prompt = 'Workspace symbols query: ',
  }, function(query)
    if not query or query == '' then
      return
    end
    vim.lsp.buf.workspace_symbol(query)
  end)
end
function M.toggle_quickfix()
  for _, win in ipairs(api.nvim_list_wins()) do
    local info = fn.getwininfo(api.nvim_win_get_number(win))[1]
    if info and info.quickfix == 1 and info.loclist == 0 then
      vim.cmd('cclose')
      return
    end
  end
  vim.cmd('copen')
end
function M.toggle_loclist()
  local wins = fn.getwininfo()
  local current = api.nvim_get_current_win()
  for _, win in ipairs(wins) do
    if win.winid == current and win.loclist == 1 then
      vim.cmd('lclose')
      return
    end
  end
  vim.cmd('lopen')
end
function M.enable_workspace_diagnostics_handler()
  vim.diagnostic.handlers.qompass_qf = {
    show = function(_, _, _, _)
      vim.schedule(function()
        vim.diagnostic.setqflist({
          open = false,
          title = 'Workspace Diagnostics',
        })
      end)
    end,
    hide = function()
      vim.schedule(function()
        fn.setqflist({}, 'r', { title = 'Workspace Diagnostics', items = {} })
      end)
    end,
  }
  notify('Enabled native workspace diagnostics quickfix handler', levels.INFO)
end
function M.disable_workspace_diagnostics_handler()
  vim.diagnostic.handlers.qompass_qf = nil
  notify('Disabled native workspace diagnostics quickfix handler', levels.INFO)
end
function M.selfcheck()
  local lua_root = fn.stdpath('config') .. '/lua'
  local files = collect_lua_files(lua_root)
  local qf_items = {}
  local state_dir = fn.stdpath('state')
  fn.mkdir(state_dir, 'p')
  local log_path = state_dir .. '/selfcheck.log'
  local fh = io.open(log_path, 'w')
  write_log(fh, ('[selfcheck] %s'):format(os.date('%Y-%m-%d %H:%M:%S')))
  write_log(fh, ('[selfcheck] lua_root=%s'):format(lua_root))
  write_log(fh, ('[selfcheck] state_dir=%s'):format(state_dir))
  write_log(fh, ('[selfcheck] log_path=%s'):format(log_path))
  write_log(fh, '')
  local syntax_ok, syntax_err = syntaxcheck_all(lua_root, files, qf_items, fh)
  runtimecheck(qf_items, fh)
  finish_qf(qf_items)
  local runtime_err = math.max(#qf_items - syntax_err, 0)
  local summary = ('[selfcheck] syntax: %d OK, %d FAILED | runtime issues: %d | log: %s'):format(
    syntax_ok,
    syntax_err,
    runtime_err,
    log_path
  )
  notify(summary, #qf_items == 0 and levels.INFO or levels.ERROR)
  write_log(fh, '')
  write_log(fh, ('[selfcheck] syntax_ok=%d syntax_err=%d runtime_issues=%d'):format(syntax_ok, syntax_err, runtime_err))
  if fh then
    fh:close()
  end
end
function M.syntaxcheck()
  local lua_root = fn.stdpath('config') .. '/lua'
  local files = collect_lua_files(lua_root)
  local qf_items = {}
  local state_dir = fn.stdpath('state')
  fn.mkdir(state_dir, 'p')
  local log_path = state_dir .. '/selfcheck.log'
  local fh = io.open(log_path, 'w')
  write_log(fh, ('[syntaxcheck] %s'):format(os.date('%Y-%m-%d %H:%M:%S')))
  write_log(fh, ('[syntaxcheck] lua_root=%s'):format(lua_root))
  write_log(fh, '')
  local syntax_ok, syntax_err = syntaxcheck_all(lua_root, files, qf_items, fh)
  finish_qf(qf_items)
  local summary = ('[syntaxcheck] %d OK, %d FAILED | log: %s'):format(syntax_ok, syntax_err, log_path)
  notify(summary, syntax_err == 0 and levels.INFO or levels.ERROR)
  write_log(fh, '')
  write_log(fh, ('[syntaxcheck] syntax_ok=%d syntax_err=%d'):format(syntax_ok, syntax_err))
  if fh then
    fh:close()
  end
end
M.run = M.selfcheck
api.nvim_create_user_command('ConfigSelfCheck', M.selfcheck, {
  desc = 'Syntax-check all Lua config files and run safe runtime probes',
})
api.nvim_create_user_command('ConfigSyntaxCheck', M.syntaxcheck, {
  desc = 'Syntax-check all Lua config files without requiring modules',
})
api.nvim_create_user_command('ConfigSelfCheckLog', function()
  vim.cmd(('edit %s'):format(fn.fnameescape(fn.stdpath('state') .. '/selfcheck.log')))
end, {
  desc = 'Open the ConfigSelfCheck log file',
})
api.nvim_create_user_command('DiagnosticsWorkspace', M.workspace_diagnostics, {
  desc = 'Populate quickfix with workspace diagnostics',
})
api.nvim_create_user_command('DiagnosticsBuffer', function()
  M.buffer_diagnostics(api.nvim_get_current_buf())
end, {
  desc = 'Populate location list with current-buffer diagnostics',
})
api.nvim_create_user_command('DiagnosticsToggleQuickfix', M.toggle_quickfix, {
  desc = 'Toggle quickfix window',
})
api.nvim_create_user_command('DiagnosticsToggleLoclist', M.toggle_loclist, {
  desc = 'Toggle location list window',
})
api.nvim_create_user_command('LspDocumentSymbols', M.document_symbols, {
  desc = 'Show document symbols with native LSP',
})

api.nvim_create_user_command('LspWorkspaceSymbols', M.workspace_symbols, {
  desc = 'Search workspace symbols with native LSP',
})

api.nvim_create_user_command('DiagnosticsEnableWorkspaceHandler', M.enable_workspace_diagnostics_handler, {
  desc = 'Enable native quickfix sync for workspace diagnostics',
})

api.nvim_create_user_command('DiagnosticsDisableWorkspaceHandler', M.disable_workspace_diagnostics_handler, {
  desc = 'Disable native quickfix sync for workspace diagnostics',
})

api.nvim_create_autocmd('BufReadPost', {
  group = ddx_group,
  pattern = '*',
  callback = function(args)
    if vim.bo[args.buf].filetype == 'nvimpager' then
      strip_ansi(args.buf)
    end
  end,
})

if vim.lsp and vim.lsp.log and vim.lsp.log.set_level then
  vim.lsp.set_log_level = function(...)
    return vim.lsp.log.set_level(...)
  end
end

return M