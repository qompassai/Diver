-- /qompassai/Diver/lua/config/core/plenary.lua
-- Qompass AI Diver Core Plenary Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {
        '*.sh',
        '*.bash',
        '*.zsh',
    },
    callback = function()
        vim.lsp.buf.format()
    end,
})
return M