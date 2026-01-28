-- /qompassai/Diver/lua/mappings/ddxmap.lua
-- Qompass AI Diver Diag/debug (ddx) Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.ddxmap'
local M = {}
function M.setup_ddxmap()
    local map = vim.keymap.set
    map('n', '<leader>S', function()
        require('tests.selfcheck').run()
    end, {
        desc = 'Run Neovim config selfcheck',
    })
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'python',
        callback = function(args)
            local bufnr = args.buf
            local opts = {
                noremap = true,
                silent = true,
                buffer = bufnr,
            }
            map(
                'n',
                '<leader>dpm',
                function()
                    require('dap-python').test_method()
                end,
                vim.tbl_extend('force', opts, {
                    desc = '[d]ebug [p]ython [m]ethod',
                })
            )

            map(
                'n',
                '<leader>dpc',
                function()
                    require('dap-python').test_class()
                end,
                vim.tbl_extend('force', opts, {
                    desc = '[d]ebug [p]ython [c]lass',
                })
            )

            map(
                'n',
                '<leader>dps',
                function()
                    require('dap-python').debug_selection()
                end,
                vim.tbl_extend('force', opts, {
                    desc = '[d]ebug [p]ython [s]election',
                })
            )
        end,
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
                'n',
                '<leader>dl',
                function()
                    local cfg = vim.diagnostic.config() or {}
                    local lines = cfg.virtual_lines
                    if lines == nil then
                        lines = false
                    end
                    local new_state = not lines
                    vim.diagnostic.config({
                        virtual_lines = new_state,
                        virtual_text = not new_state,
                    })
                    local msg = 'Diagnostic virtual_lines: ' .. (new_state and 'enabled' or 'disabled')
                    vim.api.nvim_echo({
                        {
                            msg,
                            'None',
                        },
                    }, false, {})
                end,
                vim.tbl_extend('force', opts, {
                    desc = 'Toggle diagnostic virtual_lines',
                }) --- In normal mode, press 'Space' + 'd' + 'l' to toggle virtual lines
            )
            map('n', '<leader>dq', vim.diagnostic.setqflist, {
                desc = 'Show project diagnostics',
            })

            map('n', '<leader>xd', '<cmd>Trouble diagnostics toggle<cr>', {
                desc = 'Toggle Diagnostics',
            })
            map('n', '<leader>xb', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', {
                desc = 'Buffer Diagnostics',
            }) --- In normal mode, press 'Space' + 'x' + 'b' to toggle Trouble diagnostics for current buffer
            map('n', '<leader>xs', '<cmd>Trouble symbols toggle focus=false<cr>', {
                desc = 'Document Symbols',
            }) --- In normal mode, press 'Space' + 'x' + 's' to toggle symbols window
            vim.keymap.set('n', '<leader>mp', ':MarkdownPreview<CR>', {
                buffer = bufnr,
                desc = 'Markdown Preview',
            })
            vim.keymap.set('n', '<leader>ms', ':MarkdownPreviewStop<CR>', {
                buffer = bufnr,
                desc = 'Stop Markdown Preview',
            })
            vim.keymap.set('n', '<leader>mt', ':TableModeToggle<CR>', {
                buffer = bufnr,
                desc = 'Toggle Table Mode',
            })
            vim.keymap.set('n', '<leader>mi', ':KittyScrollbackGenerateImage<CR>', {
                buffer = bufnr,
                desc = 'Generate image from code block',
            })
            vim.keymap.set('v', '<leader>mr', ':SnipRun<CR>', {
                buffer = bufnr,
                desc = 'Run selected code',
            })
        end,
    })
    map('n', '<leader>xw', '<cmd>Trouble lsp toggle focus=false win.position=right<cr>', {
        desc = 'LSP References',
    }) --- In normal mode, press 'Space' + 'x' + 'w' for right-aligned LSP references
    map(
        'n',
        '<leader>xl', --- In normal mode, press 'Space' + 'x' + 'l' to toggle location list
        '<cmd>Trouble loclist toggle<cr>',
        {
            desc = 'Location List',
        }
    )
    map(
        'n',
        '<leader>xq', --- In normal mode, press 'Space' + 'x' + 'q' to toggle quickfix list
        '<cmd>Trouble qflist toggle<cr>',
        {
            desc = 'Quickfix List',
        }
    )
    map(
        'n',
        '<leader>xt', --- In normal mode, press 'Space' + 'x' + 't' to toggle any active Trouble window
        '<cmd>Trouble toggle<cr>',
        {
            desc = 'Toggle Trouble',
        }
    )
    map(
        'n',
        '<leader>ds', -- Press <Space> d s to start or continue debugging
        '<cmd>lua require\'dap\'.continue()<CR>',
        {
            desc = 'Start/Continue Debug',
        }
    )
    map(
        'n',
        '<leader>db', -- Press <Space> d b to toggle breakpoint
        '<cmd>lua require\'dap\'.toggle_breakpoint()<CR>',
        {
            desc = 'Toggle Breakpoint',
        }
    )
    map(
        'n',
        '<leader>dS', -- Press <Space> d S to step over
        '<cmd>lua require\'dap\'.step_over()<CR>',
        {
            desc = 'Step Over',
        }
    )
    map(
        'n',
        '<leader>di', -- Press <Space> d i to step into
        '<cmd>lua require\'dap\'.step_into()<CR>',
        {
            desc = 'Step Into',
        }
    )
    map(
        'n',
        '<leader>do', --- Press <Space> d o to step out
        '<cmd>lua require\'dap\'.step_out()<CR>',
        {
            desc = 'Step Out',
        }
    )
    map('n', '<leader>dr', '<cmd>lua require\'dap\'.repl.toggle()<CR>', {
        desc = 'Toggle REPL',
    }) --- Press <Space> d r to toggle the debug REPL
    map('n', '<leader>du', '<cmd>lua require\'dapui\'.toggle()<CR>', {
        desc = 'Toggle DAP UI',
    }) --- In normal mode, Press <Space> d u to toggle the DAP UI
    map('n', '<leader>da', function()
        vim.ui.select({
            'python',
            'cpp',
            'rust',
            'rust',
        }, {
            prompt = 'Select debug adapter:',
            format_item = function(item)
                return ' ' .. item:upper()
            end,
        }, function(choice)
            if choice then
                require('dap').adapters[choice]()
            end
        end)
    end, {
        desc = 'Select Debug Adapter',
    }) --- Press <Space> d a to choose and activate a debug adapter
    map('n', '<leader>dv', function()
        require('dap').set_log_level('DEBUG')
        vim.api.nvim_echo({
            {
                'Debug verbosity increased',
                'None',
            },
        }, false, {})
    end, {
        desc = 'Verbose Debug Mode',
    }) --- Press <Space> d v to enable verbose debug logging
end

return M
