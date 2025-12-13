-- /qompassai/Diver/lsp/rubocop_ls.lua
-- Qompass AI Ruby RuboCop LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['rubocop_ls'] = {
    cmd = {
        'bundle',
        'exec',
        'rubocop',
        '--lsp',
    },
    filetypes = { 'ruby' },
    codeActionProvider = {
        codeActionKinds = { '', 'quickfix', 'refactor', 'source.fixAll' },
        resolveProvider = true,
    },
    colorProvider = false,
    semanticTokensProvider = nil,
    init_options = {
        safeAutocorrect = true,
        lintMode = true,
        layoutMode = true,
    },
    settings = {
        rubocop = {},
    },
    single_file_support = true,
}
