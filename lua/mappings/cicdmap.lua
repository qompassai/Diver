-- /qompassai/Diver/lua/mappings/cicdmap.lua
-- Qompass AI Diver CICD Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.cicdmap'
local M = {}
function M.setup_cicdmap()
    local map = vim.keymap.set
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
            local bufnr = ev.buf
            local opts = {
                noremap = true,
                silent = true,
                buffer = bufnr,
            }
            -- map("n", "<leader>nt", "<cmd>NvimTreeToggle<CR>", vim.tbl_extend("force", opts, { desc = "NvimTree toggle window" }))
            -- In normal mode, press 'Space' + 'n' + 't' to open or close the NvimTree window

            map('n', '<leader>e', ':Neotree toggle<CR>', {
                desc = 'Toggle Explorer',
            }) --- In normal mode, press 'Space' + 'e' to focus on the NvimTree window
            map('n', '<C-n>', ':Neotree toggle<CR>', {
                desc = 'Toggle Explorer',
            })
            map(
                'n',
                '<leader>h',
                function()
                    require('toggleterm.terminal').Terminal
                        :new({
                            direction = '[h]orizontal toggleterm',
                        })
                        :toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'TT: new horizontal terminal',
                }) --- In normal mode, press 'Space' + 'h' to open a new horizontal terminal
            )

            map(
                'n',
                '<leader>v',
                function()
                    require('toggleterm.terminal').Terminal
                        :new({
                            direction = 'vertical toggleterm',
                        })
                        :toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'TT: new vertical terminal',
                })
            )
            -- In normal mode, press 'Space' + 'v' to open a new vertical terminal
            map(
                {
                    'n',
                    't',
                },
                '<A-v>',
                function()
                    require('toggleterm.terminal').Terminal
                        :new({
                            direction = 'vertical',
                            --   id = 'vtoggleTerm',
                        })
                        :toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'TT: toggle vertical terminal',
                })
            )
            -- In normal or terminal mode, press 'Alt' + 'v' to toggle a vertical terminal on and off
            map(
                { 'n', 't' },
                '<A-h>',
                function()
                    require('toggleterm.terminal').Terminal
                        :new({
                            direction = 'horizontal',
                            --      id = 'htoggleTerm',
                        })
                        :toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'TT: toggle horizontal terminal',
                })
            )
            -- In normal or terminal mode, press 'Alt' + 'h' to toggle a horizontal terminal
            map(
                { 'n', 't' },
                '<A-i>',
                function()
                    require('toggleterm.terminal').Terminal
                        :new({
                            direction = 'float',
                            --      id = 'floatTerm',
                        })
                        :toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'TT: toggle floating terminal',
                })
            )
            -- In normal or terminal mode, press 'Alt' + 'i' to toggle a floating terminal

            map(
                'n',
                '<leader>zi',
                '<cmd>:Zi<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide interactive',
                }) --- In normal mode, press 'Space' + 'z' + 'i' to interactively navigate with Zoxide
            )
            map(
                'n',
                '<leader>zq',
                ':Z ',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide query',
                }) --- In normal mode, press 'Space' + 'z' + 'q' followed by a directory name to query Zoxide
            )
            map(
                'n',
                '<leader>zs',
                '<cmd>:Telescope zoxide list<CR><C-s>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide split window',
                }) --- In normal mode, press 'Space' + 'z' + 's' to open selected directory in split
            )
            map(
                'n',
                '<leader>zv',
                '<cmd>:Telescope zoxide list<CR><C-v>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide vertical split',
                }) --- In normal mode, press 'Space' + 'z' + 'v' to open in vertical split
            )
            map(
                'n',
                '<leader>zl',
                '<cmd>:Lz ',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide local to window',
                }) --- In normal mode, press 'Space' + 'z' + 'l' to change directory local to window
            )
            map(
                'n',
                '<leader>zt',
                '<cmd>:Tz ',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide local to tab',
                }) --- In normal mode, press 'Space' + 'z' + 't' to change directory local to tab
            )

            map(
                'n',
                '<leader>zli',
                '<cmd>:Lzi<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide interactive local to window',
                }) --- In normal mode, press 'Space' + 'z' + 'l' + 'i' for interactive window-local navigation
            )
            map(
                'n',
                '<leader>zti',
                '<cmd>:Tzi<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide interactive local to tab',
                }) --- In normal mode, press 'Space' + 'z' + 't' + 'i' for interactive tab-local navigation
            )

            map(
                'n',
                '<leader>za',
                '<cmd>:lua require(\'telescope\').extensions.zoxide.add()<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide add current directory',
                }) --- In normal mode, press 'Space' + 'z' + 'a' to add current directory to zoxide database
            )
        end,
    })
end

return M