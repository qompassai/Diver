-- /qompassai/Diver/lua/config/lang/lua.lua
-- Qompass AI Diver Lua Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------

---@module 'config.lang.lua'
local M = {}

local api = vim.api
local fn = vim.fn
local bo = vim.bo
local keymap = vim.keymap.set
local notify = vim.notify
local levels = vim.log.levels
local create_autocmd = api.nvim_create_autocmd
local create_augroup = api.nvim_create_augroup
local create_user_command = api.nvim_create_user_command

local group = create_augroup('QompassLua', { clear = true })
local header = require('utils.docs.docs')

M.luarocks = {
  'bit32',
  'busted',
  'lua-cjson',
  'dkjson',
  'fzy',
  'httpclient',
  'htmlparser',
  'lpeg',
  'lpugl',
  'lua-lru',
  'luautf8',
  'luacheck',
  'lua-csnappy',
  'luadbi',
  'luafilesystem',
  'luafilesystem-ffi',
  'lua-genai',
  'httprequestparser',
  'luamark',
  'luaproc',
  'luar',
  'luarocks-build-rust-mlua',
  'lua-rtoml',
  'luasocket',
  'luaossl',
  'luasql-postgres',
  'luastruct',
  'lua-resty-http',
  'lua-sdl2',
  'luasql-sqlite3',
  'lua-term',
  'lua-toml',
  'luv',
  'lzlib',
  'magick',
  'opengl',
  'penlight',
  'penlight-ffi',
  'phplua',
  'rapidjson',
  'quantum',
  'typecheck',
}

local function get_buf_text(bufnr)
  return table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

local function set_buf_text(bufnr, text)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, '\n', { plain = true }))
end

local function is_lua_buffer(bufnr)
  return bo[bufnr].filetype == 'lua'
end

local function stylua_available()
  return fn.executable('stylua') == 1
end

local function modernize_lua_text(content)
  local original = content

  local replacements = {
    { 'client%.cancel_request%(', 'client:cancel_request(' },
    { 'client%.is_stopped%(', 'client:is_stopped(' },
    { 'client%.notify%(', 'client:notify(' },
    { 'client%.on_attach%(', 'client:on_attach(' },
    { 'client%.request%(', 'client:request(' },
    { 'client%.stop%(', 'client:stop(' },
    {
      'client[%.:]supports_method%s*%(%s*["\']textDocument/formatting["\']%s*%)',
      'client.server_capabilities.documentFormattingProvider',
    },
    {
      'client[%.:]supports_method%s*%(%s*["\']textDocument/rangeFormatting["\']%s*%)',
      'client.server_capabilities.documentRangeFormattingProvider',
    },
    {
      'client[%.:]supports_method%s*%(%s*["\']textDocument/rename["\']%s*%)',
      'client.server_capabilities.renameProvider',
    },
    { 'health%.report_error', 'vim.health.error' },
    { 'health%.report_info', 'vim.health.info' },
    { 'health%.report_ok', 'vim.health.ok' },
    { 'health%.report_start', 'vim.health.start' },
    { 'health%.report_warn', 'vim.health.warn' },
    { 'nvim_exec%(', 'nvim_exec2(' },
    {
      'api%.nvim_buf_get_option%s*%(%s*([^,]+),%s*["\']([^"\']+)["\']%s*%)',
      'vim.bo[%1].%2',
    },
    {
      'api%.nvim_buf_set_option%s*%(%s*([^,]+),%s*["\']([^"\']+)["\'],%s*(.-)%)',
      'vim.bo[%1].%2 = %3',
    },
    {
      'api%.nvim_get_option%s*%(%s*["\']([^"\']+)["\']%s*%)',
      'vim.opt.%1:get()',
    },
    {
      'api%.nvim_set_option%s*%(%s*["\']([^"\']+)["\'],%s*(.-)%)',
      'vim.opt.%1 = %2',
    },
    {
      'api%.nvim_win_get_option%s*%(%s*([^,]+),%s*["\']([^"\']+)["\']%s*%)',
      'vim.wo[%1].%2',
    },
    {
      'api%.nvim_win_set_option%s*%(%s*([^,]+),%s*["\']([^"\']+)["\'],%s*(.-)%)',
      'vim.wo[%1].%2 = %3',
    },
    {
      'vim%.diagnostic%.goto_next%s*%(%s*%)',
      'vim.diagnostic.jump({ count = 1, float = true })',
    },
    {
      'vim%.diagnostic%.goto_prev%s*%(%s*%)',
      'vim.diagnostic.jump({ count = -1, float = true })',
    },
    { 'vim%.highlight%.', 'vim.hl.' },
    { 'vim%.loop', 'vim.uv' },
    { 'vim%.lsp%.buf%.formatting%s*%(%s*%)', 'vim.lsp.buf.format({ async = true })' },
    { 'vim%.lsp%.buf%.formatting_sync%s*%(%s*%)', 'vim.lsp.buf.format({ async = false })' },
    { 'vim%.lsp%.diagnostic%.([%w_]+)', 'vim.diagnostic.%1' },
    { 'vim%.lsp%.get_active_clients', 'vim.lsp.get_clients' },
    { 'vim%.pretty_print', 'vim.print' },
    { 'vim%.tbl_islist', 'vim.islist' },
  }

  for _, item in ipairs(replacements) do
    content = content:gsub(item[1], item[2])
  end

  return content, content ~= original
end

local function modernize_current_buffer()
  local bufnr = api.nvim_get_current_buf()
  if not is_lua_buffer(bufnr) then
    notify('Current buffer is not a Lua file', levels.WARN)
    return
  end

  local content = get_buf_text(bufnr)
  local updated, changed = modernize_lua_text(content)

  if not changed then
    notify('No deprecated Lua/Neovim API patterns found', levels.INFO)
    return
  end

  local view = fn.winsaveview()
  set_buf_text(bufnr, updated)
  fn.winrestview(view)
  notify('Modernized deprecated Lua/Neovim API patterns', levels.INFO)
end

local function format_with_stylua(bufnr)
  if not stylua_available() then
    notify('stylua not found in PATH', levels.WARN)
    return false
  end

  local file = api.nvim_buf_get_name(bufnr)
  if file == '' then
    file = fn.getcwd() .. '/untitled.lua'
  end
  local input = get_buf_text(bufnr)
  local cmd = {
    'stylua',
    '--indent-type',
    'Tabs',
    '--quote-style',
    'AutoPreferSingle',
    '--stdin-filepath',
    file,
    '-',
  }
  local result = vim.system(cmd, { text = true, stdin = input }):wait()
  if result.code ~= 0 then
    local err = (result.stderr and result.stderr ~= '') and result.stderr or 'unknown stylua error'
    notify('stylua failed: ' .. err, levels.ERROR)
    return false
  end
  if result.stdout and result.stdout ~= '' and result.stdout ~= input then
    local view = fn.winsaveview()
    set_buf_text(bufnr, result.stdout:gsub('\n$', ''))
    fn.winrestview(view)
  end
  return true
end
local function insert_lua_header()
  if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
    return
  end
  local filepath = fn.expand('%:p')
  local shebang = '#!/usr/bin/env lua'
  local hdr = header.make_header(filepath, '--')
  local lines = { shebang, '' }
  vim.list_extend(lines, hdr)
  api.nvim_buf_set_lines(0, 0, 0, false, lines)
  vim.cmd('normal! G')
end

local function lua_range_action()
  local bufnr = 0
  local diagnostics = vim.diagnostic.get(bufnr)
  local start_pos = api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = api.nvim_buf_get_mark(bufnr, '>')
  vim.lsp.buf.code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
        'refactor.extract',
      },
    },
    range = {
      start = {
        start_pos[1],
        start_pos[2],
      },
      ['end'] = {
        end_pos[1],
        end_pos[2],
      },
    },
    filter = function(_, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and client.name == 'lua_ls'
    end,
    apply = false,
  })
end

function M.lua_luarocks(opts)
  return vim.tbl_deep_extend('force', {
    rocks = M.luarocks,
  }, opts or {})
end
function M.setup()
  create_autocmd('BufNewFile', {
    group = group,
    pattern = '*.lua',
    callback = insert_lua_header,
    desc = 'Insert Lua shebang and header for new files',
  })
  create_autocmd('BufWritePre', {
    group = group,
    pattern = '*.lua',
    callback = function(args)
      format_with_stylua(args.buf)
    end,
    desc = 'Format Lua buffers with StyLua before save',
  })
  create_user_command('LuaRangeAction', lua_range_action, {
    range = true,
    desc = 'Run Lua LSP code action on selected range',
  })
  create_user_command('LuaModernize', modernize_current_buffer, {
    desc = 'Modernize deprecated Neovim/Lua API usage in current buffer',
  })
  keymap('n', '<leader>md', modernize_current_buffer, {
    desc = 'Modernize deprecated Neovim APIs',
    silent = true,
  })
end
M.setup()
if vim.lsp and vim.lsp.log and vim.lsp.log.set_level and not vim.lsp.set_log_level then
  vim.lsp.set_log_level = function(...)
    return vim.lsp.log.set_level(...)
  end
end

return M