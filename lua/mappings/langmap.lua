-- /qompassai/Diver/lua/mappings/langmap.lua
-- Qompass AI Diver Python Lang Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.langmap'
local M = {}
function M.setup_langmap()
    local map = vim.keymap.set
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
            local bufnr = ev.buf
            local opts = {
                noremap = true,
                silent = true,
                buffer = bufnr,
            }
            vim.api.nvim_create_autocmd('FileType', {
                pattern = {
                    'mojo',
                },
                callback = function(args)
                    if vim.bo[args.buf].filetype ~= 'mojo' then
                        return
                    end
                    vim.opt_local.tabstop = 4
                    vim.opt_local.shiftwidth = 4
                    vim.opt_local.expandtab = true
                    map('n', '<leader>mr', ':MojoRun<CR>', {
                        buffer = args.buf,
                        desc = 'Run Mojo file',
                    })
                    map('n', '<leader>dmf', ':MojoDebug<CR>', {
                        buffer = args.buf,
                        desc = 'Debug Mojo file',
                    })
                end,
            })

            map(
                'n',
                '<leader>pl',
                function()
                    vim.cmd('PythonLint')
                end,
                vim.tbl_extend('force', opts, {
                    desc = '[p]ython [l]int',
                })
            )
            map(
                'n',
                '<leader>ptF',
                function()
                    vim.cmd('PyTestFile')
                end,
                vim.tbl_extend('force', opts, {
                    desc = '🐍 [p]ython [t]est [F]ile',
                })
            )
            map(
                'n',
                '<leader>ptf',
                function()
                    vim.cmd('PyTestFunc')
                end,
                vim.tbl_extend('force', opts, {
                    desc = '🐍 [p]ython [t]est [f]unction',
                })
            )
            map(
                'n',
                '<leader>ppi',
                function()
                    vim.cmd('PoetryInstall')
                end,
                vim.tbl_extend('force', opts, {
                    desc = '🐍 [p]ython [p]oetry [i]nstall',
                })
            )
            map(
                'n',
                '<leader>pu',
                function()
                    vim.cmd('PoetryUpdate')
                end,
                vim.tbl_extend('force', opts, {
                    desc = '🐍 [p]ython [p]oetry Update',
                })
            )
            map(
                'n',
                '<leader>ja',
                '<cmd>JupyniumAttachToRunningNotebook<CR>',
                vim.tbl_extend('force', opts, {
                    desc = '[j]upyter [a]ttach to running jupyter notebook',
                })
            )
            map(
                'n',
                '<leader>jc',
                '<cmd>IronReplClear<CR>',
                vim.tbl_extend('force', opts, {
                    desc = '[j]upyter [c]lear REPL output',
                })
            )
            map(
                'n',
                '<leader>jel',
                function()
                    vim.cmd('MoltenEvaluateLine')
                end,
                vim.tbl_extend('force', opts, {
                    desc = '[j]upter [e]valuate [l]ine',
                }) --- In normal mode, press 'Space' + 'j' + 'c' to clear the current REPL output.
            )
            map(
                'v',
                '<leader>jev',
                function()
                    vim.cmd('MoltenEvaluateVisual')
                end,
                vim.tbl_extend('force', opts, {
                    desc = '[j]upyter [e]valuate [v]isual selection',
                })
            )
            map(
                'n',
                '<leader>ji',
                '<cmd>JupyniumKernelInterrupt<CR>',
                vim.tbl_extend('force', opts, {
                    desc = '[j]upyter [i]nterrupt kernel',
                })
            )
            map(
                'n',
                '<leader>jl',
                function()
                    require('toggleterm.terminal').Terminal
                        :new({
                            cmd = 'jupyter lab',
                            direction = 'float',
                        })
                        :toggle()
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'start [j]upyter [l]ab terminal',
                })
            )
        end,
    })
end

return M