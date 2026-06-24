-- /qompassai/Diver/lua/mappings/genmap.lua
-- Qompass AI Diver General Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.genmap'

local M = {}

function M.setup_genmap()
    local map = vim.keymap.set

    local cmd_opts = {
        expr = true,
        noremap = true,
        silent = true,
    }

    map(
        'c',
        '<C-j>',
        function()
            if vim.fn.pumvisible() == 1 then
                return '<C-n>'
            end
            return '<C-j>'
        end,
        vim.tbl_extend('force', cmd_opts, {
            desc = 'Next command-line completion item',
        })
    )

    map(
        'c',
        '<C-k>',
        function()
            if vim.fn.pumvisible() == 1 then
                return '<C-p>'
            end
            return '<C-k>'
        end,
        vim.tbl_extend('force', cmd_opts, {
            desc = 'Previous command-line completion item',
        })
    )

    map(
        'c',
        '<Down>',
        function()
            if vim.fn.pumvisible() == 1 then
                return '<C-n>'
            end
            return '<Down>'
        end,
        vim.tbl_extend('force', cmd_opts, {
            desc = 'Next command-line completion item',
        })
    )

    map(
        'c',
        '<Up>',
        function()
            if vim.fn.pumvisible() == 1 then
                return '<C-p>'
            end
            return '<Up>'
        end,
        vim.tbl_extend('force', cmd_opts, {
            desc = 'Previous command-line completion item',
        })
    )

    map(
        'c',
        'j',
        function()
            if vim.fn.pumvisible() == 1 then
                return '<C-n>'
            end
            return 'j'
        end,
        vim.tbl_extend('force', cmd_opts, {
            desc = 'Next command-line completion item',
        })
    )

    map(
        'c',
        'k',
        function()
            if vim.fn.pumvisible() == 1 then
                return '<C-p>'
            end
            return 'k'
        end,
        vim.tbl_extend('force', cmd_opts, {
            desc = 'Previous command-line completion item',
        })
    )

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
                buffer = bufnr,
                noremap = true,
                silent = true,
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
                'n',
                '<C-c>',
                '<cmd>%y+<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Copy the entire file to the clipboard',
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
                'n',
                '<Esc>',
                '<cmd>noh<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Clear search highlights',
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
                'n',
                '<C-h>',
                '<C-w>h',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window on the left',
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
                'n',
                '<C-j>',
                '<C-w>j',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window below',
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
                '<C-k>',
                '<C-w>k',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window above',
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
                'n',
                '<C-l>',
                '<C-w>l',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window on the right',
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
        end,
    })
end

return M
