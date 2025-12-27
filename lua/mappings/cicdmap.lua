-- /qompassai/Diver/lua/mappings/cicdmap.lua
-- Qompass AI Diver CICD Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
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

            -- Nerd Translate Legend:
            --
            -- 'Alt': The alternate key on your keyboard, usually next to the space bar.
            -- 'Buffer': A temporary place to keep an open file. In Neovim buffer=file more or less.
            -- 'Ctrl': The control key, usually at the bottom of the keyboard.
            -- 'Directory': A digital storage place for your files, aka "folder".
            -- 'File': A document or piece of information saved on your computer, like a drawing that you store in a drawer.
            -- 'Fuzzy Finding': Search for things your memory's a little "fuzzy" on.
            -- 'Grep': A tool to quickly find words or phrases in files. It's like looking through your documents with a magnifying glass to find specific words.
            -- 'Leader/Leader key': The 'Space' key, which you press in normal mode before other keys to run commands.
            -- 'Mappings': Custom keyboard shortcuts unique to each Diver tool. TLDR: Type less, do more.
            -- 'Mark': A virtual bookmark in your text that lets you quickly jump back to important spots in your code or document.
            -- 'NvimTree': A file explorer to see all the folders and files in a "tree"-like structure. Think file explorer in Windows.
            -- 'Telescope': A free & open-source tool to search and find your data on your computer.
            -- 'ToggleTerm': A way to open new windows in your terminal.
            -- 'Zoxide': A tool to quickly jump to the places you visit most often.

            -- NvimTree mappings

            -- NvimTree: Toggle NvimTree file explorer window (open or close the file manager window)
            -- map("n", "<leader>nt", "<cmd>NvimTreeToggle<CR>", vim.tbl_extend("force", opts, { desc = "NvimTree toggle window" }))
            -- In normal mode, press 'Space' + 'n' + 't' to open or close the NvimTree window

            -- NeoTree: Focus the NvimTree file explorer window
            map('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'Toggle Explorer' })
            -- In normal mode, press 'Space' + 'e' to focus on the NvimTree window

            map('n', '<C-n>', ':Neotree toggle<CR>', { desc = 'Toggle Explorer' })

            -- ToggleTerm (TT) mappings

            -- ToggleTerm: Creates a new horizontal terminal
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
                })
            )
            -- In normal mode, press 'Space' + 'h' to open a new horizontal terminal

            -- ToggleTerm: Creates a new vertical terminal
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

            -- ToggleTerm: Toggles the vertical terminal
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

            -- ToggleTerm: Toggles a horizontal terminal
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

            -- ToggleTerm: Toggles a floating terminal
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

            -- Zoxide mappings

            -- Zoxide: Interactively suggests directories to zoom into based on what you type without the list
            map(
                'n',
                '<leader>zi',
                '<cmd>:Zi<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide interactive',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 'i' to interactively navigate with Zoxide

            -- Zoxide: Query lets you zoom directly into where you want to go when you know the name
            map(
                'n',
                '<leader>zq',
                ':Z ',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide query',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 'q' followed by a directory name to query Zoxide

            -- Zoxide: Open in split window
            map(
                'n',
                '<leader>zs',
                '<cmd>:Telescope zoxide list<CR><C-s>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide split window',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 's' to open selected directory in split

            -- Zoxide: Open in vertical split
            map(
                'n',
                '<leader>zv',
                '<cmd>:Telescope zoxide list<CR><C-v>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide vertical split',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 'v' to open in vertical split

            -- Zoxide: Local to window
            map(
                'n',
                '<leader>zl',
                '<cmd>:Lz ',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide local to window',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 'l' to change directory local to window

            -- Zoxide: Local to tab
            map(
                'n',
                '<leader>zt',
                '<cmd>:Tz ',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide local to tab',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 't' to change directory local to tab

            -- Zoxide: Interactive local to window
            map(
                'n',
                '<leader>zli',
                '<cmd>:Lzi<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide interactive local to window',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 'l' + 'i' for interactive window-local navigation

            -- Zoxide: Interactive local to tab
            map(
                'n',
                '<leader>zti',
                '<cmd>:Tzi<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide interactive local to tab',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 't' + 'i' for interactive tab-local navigation

            -- Zoxide: Add current directory to database
            map(
                'n',
                '<leader>za',
                '<cmd>:lua require(\'telescope\').extensions.zoxide.add()<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Zoxide add current directory',
                })
            )
            -- In normal mode, press 'Space' + 'z' + 'a' to add current directory to zoxide database
        end,
    })
end

return M
