-- /qompassai/Diver/lsp/arduino_ls.lua
-- Qompass AI Arduino LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local cli_config = vim.fn.expand('~/.arduino15/arduino-cli.yaml')
local cli_bin = 'arduino-cli'
vim.lsp.config['arduino_ls'] = {
    cmd = {
        'arduino-language-server',
        '-cli-config',
        cli_config,
        '-cli',
        cli_bin,
        '-clangd',
        '-fqbn',
        'arduino:avr:uno',
    },
    filetypes = {
        'arduino',
        'ino',
        'cpp',
    },
    codeActionProvider = {
        codeActionKinds = {
            '',
            'quickfix',
            'refactor.extract',
            'refactor.rewrite',
        },
        resolveProvider = true,
    },
    colorProvider = false,
    semanticTokensProvider = nil,
    init_options = {},
    settings = {
        arduino = {},
    },
}
