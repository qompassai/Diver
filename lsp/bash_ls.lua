-- /qompassai/Diver/lsp/bashls.lua
-- Qompass AI Bash LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'bash-language-server',
        'start',
    },
    filetypes = {
        'sh',
        'bash',
    },
    root_markers = {
        '.git',
    },
    settings = {
        bashIde = {
            globPattern = vim.env.GLOB_PATTERN or '*@(.sh|.inc|.bash|.command)',
            maxNumberOfProblems = 200,
            shellcheck = {
                enable = true,
                executablePath = 'shellcheck',
                severity = {
                    error = 'error',
                    warning = 'warning',
                    info = 'info',
                    style = 'info',
                },
            },
            completion = {
                enabled = true,
                includeDirs = {
                    '$XDG_CONFIG_HOME/bash-completion',
                    '$XDG_CONFIG_HOME/bash-completion.d',
                },
            },
            diagnostics = {
                enabled = true,
            },
        },
    },
}
