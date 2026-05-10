#!/usr/bin/env lua
-- ~/.config/nvim/after/plugin/hyprlua.lua
-- Qompass AI HyprLua - Neovim integration
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- SPDX-License-Identifier: Apache-2.0
local ADDON_LIB = vim.fn.expand('~/.local/share/nvim/hyprlua/library')
local function resolve_lib()
    local candidates = {
        ADDON_LIB,
        vim.fn.expand('~/.config/lua-language-server/addons/hyprlua/library'),
        vim.fn.expand('~/.local/share/lua-language-server/addons/hyprlua/library'),
    }
    local ok, rocks_path = pcall(function()
        return vim.fn.system('luarocks path --lr-dir'):gsub('%s+$', '') .. '/lua-language-server/addons/hyprlua/library'
    end)
    if ok then
        candidates[#candidates + 1] = rocks_path
    end

    for _, p in ipairs(candidates) do
        if vim.fn.isdirectory(p) == 1 then
            return p
        end
    end
    return nil
end
local function is_hypr_lua(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name:match('hypr.*%.lua$') then
        return true
    end
    local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
    return first:match('^%-%-.*hypr') ~= nil
end
local function apply_hyprlua(client, bufnr)
    local lib = resolve_lib()
    if not lib then
        vim.notify(
            '[hyprlua] addon library not found — run: luarocks install hyprlua\n'
                .. 'or copy the library/ folder to: '
                .. ADDON_LIB,
            vim.log.levels.WARN,
            { title = 'hyprlua' }
        )
        return
    end
    local settings = client.config.settings or {}
    local lua = settings.Lua or {}
    local ws = lua.workspace or {}
    local diag = lua.diagnostics or {}
    local existing = ws.library or {}
    local seen = {}
    for _, v in ipairs(existing) do
        seen[v] = true
    end
    if not seen[lib] then
        existing[#existing + 1] = lib
    end
    ws.library = existing
    local globals = diag.globals or {}
    local has_hl = false
    for _, g in ipairs(globals) do
        if g == 'hl' then
            has_hl = true
            break
        end
    end
    if not has_hl then
        globals[#globals + 1] = 'hl'
    end
    diag.globals = globals
    lua.workspace = ws
    lua.diagnostics = diag
    settings.Lua = lua
    client.config.settings = settings
    client:notify('workspace/didChangeConfiguration', { settings = settings })

    vim.notify(
        '[hyprlua] hl API annotations enabled for ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t'),
        vim.log.levels.INFO,
        { title = 'hyprlua' }
    )
end

vim.api.nvim_create_augroup('hyprlua_attach', {
    clear = true,
})

vim.api.nvim_create_autocmd('LspAttach', {
    group = 'hyprlua_attach',
    pattern = '*.lua',
    desc = 'hyprlua: inject hl addon when lua_ls opens a Hyprland config',
    callback = function(args)
        local bufnr = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= 'lua_ls' then
            return
        end
        if not is_hypr_lua(bufnr) then
            return
        end
        apply_hyprlua(client, bufnr)
    end,
})

vim.api.nvim_create_user_command('HyprLuaEnable', function()
    local bufnr = vim.api.nvim_get_current_buf()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = 'lua_ls' })) do
        apply_hyprlua(client, bufnr)
    end
end, {
    desc = 'Inject hyprlua hl annotations into the current lua_ls session',
})