-- /qompassai/Diver/lua/mappings/genmap.lua
-- Qompass AI Diver General Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.genmap'
local M = {}
function M.setup_genmap()
    local map = vim.keymap.set
    map('n', '<leader>U', function()
        vim.pack.update(nil, {
            force = true,
        })
    end, {
        desc = 'Force update vim.pack plugins',
        noremap = true,
        silent = true,
    })
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
            local bufnr = ev.buf
            local opts = {
                noremap = true,
                silent = true,
                buffer = bufnr,
            }
            map(
                'i',
                '<C-b>',
                '<ESC>^i',
                vim.tbl_extend('force', opts, {
                    desc = 'Move to the beginning of the line',
                })
            )
            map(
                'i',
                '<C-e>',
                '<End>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move to the end of the line',
                })
            )
            map(
                'i',
                '<C-h>',
                '<Left>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move left by one character',
                })
            )
            map(
                'i',
                '<C-l>',
                '<Right>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move right by one character',
                })
            )
            map(
                'i',
                '<C-j>',
                '<Down>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move down by one line',
                })
            )
            map(
                'i',
                '<C-k>',
                '<Up>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move up by one line',
                })
            )
            map(
                'n',
                '<Esc>',
                '<cmd>noh<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Clear search highlights',
                })
            )
            map(
                'n',
                '<C-h>',
                '<C-w>h',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window on the left',
                })
            )
            map(
                'n',
                '<C-l>',
                '<C-w>l',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window on the right',
                })
            )
            map(
                'n',
                '<C-j>',
                '<C-w>j',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window below',
                })
            )
            map(
                'n',
                '<C-k>',
                '<C-w>k',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window above',
                })
            )
            map(
                'n',
                '<C-s>',
                '<cmd>w<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Save the current file',
                })
            )
            map(
                'n',
                '<C-c>',
                '<cmd>%y+<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Copy the entire file to the clipboard',
                })
            )
        end,
    })
end

return M
