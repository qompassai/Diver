-- /qompassai/Diver/lsp/stylua_ls.lua
-- Qompass AI Stylua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['stylua_ls'] = {
    cmd = {
        'stylua',
        '--lsp',
        '--search-parent-directories',
        '--sort-requires',
        '--respect-ignores',
        '--syntax=LuaJit',
    },
    filetypes = {
        'lua',
        'luau',
    },
    root_markers = {
        '.editorconfig',
        '.stylua.toml',
        'stylua.toml',
    },
    on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = true
        client.server_capabilities.documentRangeFormattingProvider = true
        client.server_capabilities.completionProvider = nil
        client.server_capabilities.hoverProvider = false
        client.server_capabilities.definitionProvider = false
        client.server_capabilities.referencesProvider = false
        client.server_capabilities.renameProvider = false
        client.server_capabilities.codeActionProvider = false
    end,
}
