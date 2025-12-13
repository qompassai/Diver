-- /qompassai/Diver/lsp/robotcode.lua
-- Qompass AI RobotCode LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pip install "robotcode[all]"
vim.lsp.config['robotcode_ls'] = {
    cmd = {
        'robotcode',
        'language-server',
    },
    filetypes = {
        'robot',
        'resource',
    },
    root_markers = {
        'robot.toml',
        'pyproject.toml',
        'Pipfile',
        '.git',
    },
    get_language_id = function(_, _)
        return 'robotframework'
    end,
}
