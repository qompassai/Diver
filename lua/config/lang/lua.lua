-- /qompassai/Diver/lua/config/lang/lua.lua
-- Qompass AI Diver Lua Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT
local api = vim.api
local autocmd = vim.api.nvim_create_autocmd
local bufgm = vim.api.nvim_buf_get_mark
local bufsl = vim.api.nvim_buf_set_lines
local code_action = vim.lsp.buf.code_action
local fn = vim.fn
local group = api.nvim_create_augroup('Lua', {
  clear = true,
})
local header = require('utils.docs.docs')
local map = vim.keymap.set
local usercmd = vim.api.nvim_create_user_command
autocmd('BufNewFile', {
  group = group,
  pattern = { '*.lua' },
  callback = function()
    if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
      return
    end
    local filepath = fn.expand('%:p')
    local shebang = '#!/usr/bin/env lua'
    local hdr = header.make_header(filepath, '--')
    local lines = { shebang, '' }
    vim.list_extend(lines, hdr)
    bufsl(0, 0, 0, false, lines)
    vim.cmd('normal! G')
  end,
})
autocmd('BufWritePre', {
  group = group,
  pattern = '*.lua',
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local changed = false
    for i, line in ipairs(lines) do
      local original = line
      line = line:gsub('api%.nvim_buf_set_option%(([^,]+),%s*["\']([^"\']+)["\'],%s*(.+)%)', 'vim.bo[%1].%2 = %3')
      line = line:gsub('api%.nvim_win_set_option%(([^,]+),%s*["\']([^"\']+)["\'],%s*(.+)%)', 'vim.wo[%1].%2 = %3')
      line = line:gsub('api%.nvim_buf_get_option%(([^,]+),%s*["\']([^"\']+)["\']%)', 'vim.bo[%1].%2')
      line = line:gsub('api%.nvim_win_get_option%(([^,]+),%s*["\']([^"\']+)["\']%)', 'vim.wo[%1].%2')
      if line ~= original then
        lines[i] = line
        changed = true
      end
    end
    if changed then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
  end,
})
usercmd('LuaRangeAction', function()
  local bufnr = 0
  local diagnostics = vim.diagnostic.get(bufnr)
  local start_pos = bufgm(bufnr, '<')
  local end_pos = bufgm(bufnr, '>')
  code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
        'refactor.extract',
      },
    },
    range = {
      start = { start_pos[1], start_pos[2] },
      ['end'] = { end_pos[1], end_pos[2] },
    },
    filter = function(_, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and client.name == 'lua_ls'
    end,
    apply = false,
  })
end, {
  range = true,
})
map('n', '<leader>md', function()
  local bufnr = vim.api.nvim_get_current_buf()
  local INFO = vim.log.levels.INFO
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local count = 0
  for i, line in ipairs(lines) do
    local original = line
    line = line:gsub('api%.nvim_buf_set_option%(([^,]+),%s*["\']([^"\']+)["\'],%s*(.+)%)', 'vim.bo[%1].%2 = %3')
    line = line:gsub('api%.nvim_win_set_option%(([^,]+),%s*["\']([^"\']+)["\'],%s*(.+)%)', 'vim.wo[%1].%2 = %3')
    line = line:gsub('api%.nvim_buf_get_option%(([^,]+),%s*["\']([^"\']+)["\']%)', 'vim.bo[%1].%2')
    line = line:gsub('api%.nvim_win_get_option%(([^,]+),%s*["\']([^"\']+)["\']%)', 'vim.wo[%1].%2')
    if line ~= original then
      lines[i] = line
      count = count + 1
    end
  end
  if count > 0 then
    bufsl(bufnr, 0, -1, false, lines)
    vim.notify(string.format('Modernized %d deprecated API calls', count), INFO)
  else
    vim.notify('No deprecated APIs found', INFO)
  end
end, { desc = 'Modernize deprecated Neovim APIs' })
M.rocks = {
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
  'luasql-postgres',
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
return M