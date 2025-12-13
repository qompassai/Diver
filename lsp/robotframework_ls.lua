-- /qompassai/Diver/lsp/robotframework_ls.lua
-- Qompass AI Robot Framework LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- https://github.com/robocorp/robotframework-lsp
vim.lsp.config['robotframework_ls'] = {
    cmd = { 'robotframework_ls' },
    filetypes = { 'robot' },
    root_markers = {
        'robotidy.toml',
        'pyproject.toml',
        'conda.yaml',
        'robot.yaml',
        '.git',
    },
}
