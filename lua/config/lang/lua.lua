-- /qompassai/Diver/lua/config/lang/lua.lua
-- Qompass AI Diver Lua Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
local autocmd = vim.api.nvim_create_autocmd
local code_action = vim.lsp.buf.code_action
local fn = vim.fn
local header = require('utils.docs.docs')
local group = api.nvim_create_augroup('Lua', {
    clear = true,
})
local usercmd = vim.api.nvim_create_user_command
api.nvim_create_autocmd('BufNewFile', {
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
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})
autocmd('LspAttach', {
    group = group,
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'lua_ls' then
            vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        end
    end,
})
usercmd('LuaRangeAction', function()
    local bufnr = 0
    local diagnostics = vim.diagnostic.get(bufnr)
    local start_pos = api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = api.nvim_buf_get_mark(bufnr, '>')
    code_action({
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
end, {
    range = true,
})

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
