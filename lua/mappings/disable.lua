-- /qompassai/Diver/lua/mappings/disable.lua
-- Qompass AI Diver Disabled Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'mappings.disable'
local M = {}

M.setup_disable = function()
    local map = vim.keymap.set
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
            local bufnr = ev.buf
            local opts = {
                noremap = true,
                silent = true,
                buffer = bufnr,
            }
            map('n', 'gc', '<Nop>', opts)
            map('n', 'gcc', '<Nop>', opts)
            map('x', 'gc', '<Nop>', opts)
            map('o', 'gc', '<Nop>', opts)
        end,
    })
end

return M
