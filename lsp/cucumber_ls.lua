-- /qompassai/Diver/lsp/cucumber_ls.lua
-- Qompass AI Cucumber Diver LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['cucumber_ls'] = {
    cmd = {
        'cucumber-language-server',
        '--stdio',
    },
    filetypes = {
        'cucumber',
    },
    root_markers = {
        '.git',
    },
}
