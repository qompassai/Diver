-- /qompassai/Diver/lua/mappings/lintmap.lua
-- Qompass AI Diver Linter Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.lintmap'
local M = {}

function M.setup_lintmap()
    local map = vim.keymap.set
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
            local bufnr = ev.buf
            local opts = {
                noremap = true,
                silent = true,
                buffer = bufnr,
            }
            map(
                'n',
                '<leader>cd',
                function()
                    vim.diagnostic.reset()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Clear diagnostics',
                })
            )
        end,
    })
end

return M
