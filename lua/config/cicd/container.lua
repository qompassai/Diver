-- container.lua
-- Qompass AI Diver CICD Container Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd({
    'BufRead',
    'BufNewFile',
}, {
    pattern = {
        'Dockerfile.*',
        '*.Dockerfile',
        'Containerfile',
        '*.containerfile',
    },
    callback = function()
        vim.bo.filetype = 'dockerfile'
    end,
})
vim.api.nvim_create_autocmd({
    'BufNewFile',
    'BufRead',
}, {
    pattern = {
        '*docker-compose*.yml',
        '*docker-compose*.yaml',
    },
    callback = function()
        vim.bo.filetype = 'yaml'
    end,
})