-- /qompassai/Diver/lua/mappings/navmap.lua
-- Qompass AI Diver Nav Plugin Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.navmap'
local M = {}
function M.setup_navmap()
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
                '<leader>oof',
                ':Oil<CR>',
                vim.tbl_extend('force', opts, {
                    desc = '[o]il [o]pen [f]ile explorer',
                })
            )
            map(
                'n',
                '<leader>omu',
                ':Oil -<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Oil Move Up to Parent Directory',
                }) --- In normal mode, press 'Space' + 'o' + 'f' to open the Oil file explorer
            )

            map(
                'n',
                '<leader>ooh',
                ':Oil ~/ <CR>',
                vim.tbl_extend('force', opts, {
                    desc = '[o]il [o]pen in [h]ome Directory',
                }) -- In normal mode, press 'Space' + 'o' + 'm' +'u' to move up a directory in Oil.
            )
            map(
                'n',
                '<leader>op',
                ':Oil preview<CR>',
                vim.tbl_extend('force', opts, { desc = 'Oil Preview File' }) --- In normal mode, press 'Space' + 'o' + 'h' to open Oil in the home directory.
            )
            -- In normal mode, press 'Space' + 'o' + 'p' to preview a file with Oil.
            map(
                'n',
                '<leader>oc',
                ':Oil close<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'Oil Close Buffer',
                }) --- In normal mode, press 'Space' + 'o' + 'c' to close the Oil buffer.
            )
            map(
                'n',
                '<leader>lc',
                function()
                    require('ibl').refresh(0)
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'IB[l] Refresh Indent Context',
                })
            )
            map(
                'n',
                '<leader>lg',
                function()
                    require('ibl').toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'IB[l] toggle indent [g]uides',
                })
            )
            map(
                'n',
                '<leader>ls',
                function()
                    require('ibl').toggle_scope_highlighting()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'IB[l] toggle [s]cope highlighting',
                })
            )
            map(
                'n',
                '<leader>lr',
                function()
                    require('ibl').refresh(0)
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'IB[l] [r]efresh Indent Guides',
                })
            )
            map(
                'n',
                '<leader>lt',
                function()
                    local current_value = vim.g.indent_blankline_enabled or false
                    vim.g.indent_blankline_enabled = not current_value
                    if vim.g.indent_blankline_enabled then
                        require('ibl').setup()
                        require('ibl').refresh(0)
                    else
                        require('ibl').setup({
                            indent = {
                                char = '',
                            },
                        })
                        require('ibl').refresh(0)
                    end
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'IB[l] Toggle Indent Blankline visibility',
                })
            )
            map(
                'n',
                '<leader>e',
                '<cmd>Neotree toggle<cr>',
                vim.tbl_extend('force', opts, {
                    desc = 'Toggle Neo-tree',
                })
            )
            map(
                'n',
                '<leader>E',
                '<cmd>Neotree focus<cr>',
                vim.tbl_extend('force', opts, {
                    desc = 'Focus Neo-tree',
                })
            )
            map(
                'n',
                '<leader>qs',
                function()
                    require('persistence').load()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Restore Session',
                })
            )
            map(
                'n',
                '<leader>ql',
                function()
                    require('persistence').load({
                        last = true,
                    })
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Restore Last Session',
                })
            )
            map(
                'n',
                '<leader>qd',
                function()
                    require('persistence').stop()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Don\'t Save Current Session',
                })
            )
            map(
                {
                    'n',
                    'x',
                    'o',
                },
                's',
                function()
                    require('flash').jump()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Flash jump',
                })
            )
            map(
                {
                    'n',
                    'x',
                    'o',
                },
                'S',
                function()
                    require('flash').jump({
                        search = {
                            forward = false,
                        },
                    })
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Flash jump backward',
                })
            )
            map(
                'o',
                'r',
                function()
                    require('flash').remote()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Remote Flash',
                })
            )
            map(
                {
                    'o',
                    'x',
                },
                'R',
                function()
                    require('flash').treesitter_search()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Treesitter Search',
                })
            )
            map(
                'c',
                '<C-s>',
                function()
                    require('flash').toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Toggle Flash Search',
                })
            )
            map(
                'n',
                '<leader>TEI',
                ':TSNodeIncremental<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS [E]xpand Selection [I]ncrementally',
                })
            )
            map(
                'n',
                '<leader>TIS',
                ':TSNodeDecremental<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS [I]ncrementally [S]hrink Selection',
                })
            )

            map(
                'n',
                '<leader>Tss',
                ':TSScopeIncremental<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Expand Selection to Next Larger Code Block',
                }) -- In normal mode, press 'Space' + 'I' + 'S' to shrink selection step by step.
            )

            map(
                'n',
                'TsF',
                '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@function.outer")<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Select Entire Function',
                }) --- In normal mode, press 'Space' + 's' + 's' to expand selection to the next larger code block.
            )
            map(
                'o',
                'Tsf',
                '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@function.inner")<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Select Function Body Only',
                }) --- In operator-pending mode, press 'a' + 'f' to select the entire function (including definition and body).
            )
            -- In operator-pending mode, press 'i' + 'f' to select only the body of the function.
            map(
                'n',
                'TSC',
                '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@class.outer")<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Select Entire Class',
                })
            )
            -- In operator-pending mode, press 'a' + 'c' to select the entire class (including definition and body).
            map(
                'o',
                'Tsc',
                '<cmd>lua require"nvim-treesitter.textobjects.select".select_textobject("@class.inner")<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Select Class Body Only',
                })
            )
            -- In operator-pending mode, press 'T' + 's' + c' to select only the body of the class.
            map(
                'n',
                '<leader>Tnf',
                ':TSGotoNextFunction<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Navigate to Next Function Start',
                })
            )
            map(
                'n',
                '<leader>TpF',
                ':TSGotoPreviousFunction<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Navigate to Previous Function Start',
                }) -- In normal mode, press 'Space' + 'T' + 'n' + 'f' to go to the start of the next function.
            )
            map(
                'n',
                '<leader>Tsh',
                ':TSToggleHighlight<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Toggle Syntax Highlighting',
                }) -- In normal mode, press 'Space' + 't' + 'p' to go to the start of the previous function.
            )
            -- In normal mode, press 'Space' + 't' + 's' to turn syntax highlighting on or off.
            map(
                'n',
                '<leader>Tp',
                ':TSTogglePlayground<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Toggle Playground',
                })
            )
            -- Show Syntax Info Under Cursor (Treesitter Captures)
            map(
                'n',
                '<leader>Tu',
                ':TSShowCaptures<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Show Syntax Info Under Cursor',
                })
            )

            map(
                'n',
                '<leader>Tsn',
                ':TSSwapNextParameter<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Swap with Next Parameter', -- In normal mode, press 'Space' + 'T' + 'u' to show syntax information under the cursor.
                })
            )
            -- In normal mode, press 'Space' + 'T' 's' + 'n' to swap the current parameter with the next one.
            -- Swap with Previous Parameter (Treesitter)
            map(
                'n',
                '<leader>Tsp',
                ':TSSwapPreviousParameter<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Swap with Previous Parameter',
                })
            )
            -- In normal mode, press 'Space' + 'T' + 's' + 'p' to swap the current parameter with the previous one.
            map(
                'n',
                '<leader>Tcf',
                ':TSToggleFold<CR>',
                vim.tbl_extend('force', opts, {
                    desc = 'TS Toggle [c]ode Folding',
                }) -- In normal mode, press 'Space' + 'T' + 'c' + 'f' to fold or unfold code blocks.
            )
        end,
    })
end

return M
--[[
local ts_repeat_move = require('nvim-treesitter.textobjects.repeatable_move')
vim.keymap.set({ 'n', 'x', 'o' }, ';', ts_repeat_move.repeat_last_move)
vim.keymap.set({ 'n', 'x', 'o' }, ',', ts_repeat_move.repeat_last_move_opposite)
vim.keymap.set({ 'n', 'x', 'o' }, 'f', ts_repeat_move.builtin_f)
vim.keymap.set({ 'n', 'x', 'o' }, 'F', ts_repeat_move.builtin_F)
vim.keymap.set({ 'n', 'x', 'o' }, 't', ts_repeat_move.builtin_t)
vim.keymap.set({ 'n', 'x', 'o' }, 'T', ts_repeat_move.builtin_T)

--]]
