-- /qompassai/Diver/lsp/tflint.lua
-- Qompass AI Terraform Lint (TFLint) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['tflint_ls'] = {
    cmd = {
        'tflint',
        '--langserver',
    },
    filetypes = {
        'terraform',
    },
    root_markers = {
        '.terraform',
        '.git',
        '.tflint.hcl',
    },
}
