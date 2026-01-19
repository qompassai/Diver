-- /qompassai/Diver/lua/mappings/genmap.lua
-- Qompass AI Diver General Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'mappings.genmap'
local M = {}
function M.setup_genmap()
    local map = vim.keymap.set
    map('n', '<leader>U', function()
        vim.pack.update(nil, { force = true })
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
            -- Move to the beginning of the line while in insert mode
            map(
                'i',
                '<C-b>',
                '<ESC>^i',
                vim.tbl_extend('force', opts, {
                    desc = 'Move to the beginning of the line',
                })
            )
            -- Move to the end of the line while in insert mode
            map(
                'i',
                '<C-e>',
                '<End>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move to the end of the line',
                })
            )

            -- Move left by one character while in insert mode
            map(
                'i',
                '<C-h>',
                '<Left>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move left by one character',
                })
            )
            -- Move right by one character while in insert mode
            map(
                'i',
                '<C-l>',
                '<Right>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move right by one character',
                })
            )
            -- Move down by one line while in insert mode
            map(
                'i',
                '<C-j>',
                '<Down>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move down by one line',
                })
            )
            -- Move up by one line while in insert mode
            map(
                'i',
                '<C-k>',
                '<Up>',
                vim.tbl_extend('force', opts, {
                    desc = 'Move up by one line',
                })
            )

            -- Clear search highlights by pressing Escape in normal mode
            map(
                'n',
                '<Esc>',
                '<cmd>noh<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Clear search highlights',
                })
            )
            -- Switch to the window on the left in normal mode
            map(
                'n',
                '<C-h>',
                '<C-w>h',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window on the left',
                })
            )

            -- Switch to the window on the right in normal mode
            map(
                'n',
                '<C-l>',
                '<C-w>l',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window on the right',
                })
            )

            -- Switch to the window below in normal mode
            map(
                'n',
                '<C-j>',
                '<C-w>j',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window below',
                })
            )

            -- Switch to the window above in normal mode
            map(
                'n',
                '<C-k>',
                '<C-w>k',
                vim.tbl_extend('force', opts, {
                    desc = 'Switch to the window above',
                })
            )

            -- Save the current file by pressing Control + s in normal mode
            map(
                'n',
                '<C-s>',
                '<cmd>w<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Save the current file',
                })
            )
            -- Copy the entire file to the system clipboard in normal mode
            map(
                'n',
                '<C-c>',
                '<cmd>%y+<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Copy the entire file to the clipboard',
                })
            )
            map('n', '<leader>F', function()
                if #vim.lsp.get_clients({
                    bufnr = 0,
                }) > 0 then
                    vim.lsp.buf.format({
                        async = true,
                    })
                else
                    vim.echo('No active LSP client with formatting support.', vim.log.levels.WARN)
                end
            end, {
                desc = 'Global Format (LSP if available)',
                noremap = true,
                silent = true,
            })
        end,
    })
end

return M