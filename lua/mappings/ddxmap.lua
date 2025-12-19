-- /qompassai/Diver/lua/mappings/ddxmap.lua
-- Qompass AI Diver Diag/debug (ddx) Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.setup_ddxmap()
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- ======================
    -- Nerd Legend --
    -- ======================

    -- Breakpoint: Pause the execution of the code at a specified line.
    -- Continue: Resume the execution of a paused debugging session.
    -- DAP REPL: A console to interact with the debugger, similar to an interactive shell.
    -- Diagnostics: Messages that provide information about issues in the code.
    -- In-file: Refers to actions that apply only to the current file or buffer.
    -- LSP: Language Server Protocol, provides editor features like code completion, diagnostics, etc.
    -- Location List: A window showing errors or search results specific to the current file.
    -- None-ls: A plugin used for handling diagnostics, formatting, and other editor actions.
    -- Quickfix List: A list containing errors or search results across multiple files.
    -- REPL: A tool to interactively run code line by line (Read-Eval-Print Loop).
    -- Step Into: Step into a function or block to see its internal execution.
    -- Step Out: Step out of the current function or block to return to the caller.
    -- Step Over: Step over a line, executing it without going into functions.
    -- Symbol: Elements in your code like functions, variables, or classes.
    -- Toggle: Turn a feature on or off.
    -- Trouble: A plugin for managing diagnostics, errors, and quickfix lists visually.
    -- UI: User Interface, components that visually represent information.

    -- ========================
    -- NEOVIM NATIVE DIAGNOSTIC MAPPINGS
    -- ========================

    -- Toggle LSP diagnostic virtual_lines and virtual_text
    map(
        'n',
        '<leader>dl',
        function() -- In normal mode, press 'Space' + 'd' + 'l' to toggle virtual lines for the current buffer
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
            vim.notify('Diagnostic virtual_lines: ' .. (new_state and 'enabled' or 'disabled'), vim.log.levels.INFO)
        end,
        vim.tbl_extend('force', opts, {
            desc = 'Toggle diagnostic virtual_lines',
        })
    )

    -- Toggle diagnostics for the entire project (quickfix list)
    map('n', '<leader>dq', vim.diagnostic.setqflist, { desc = 'Show project diagnostics' })
    -- In normal mode, press 'Space' + 'd' + 'q' to show diagnostics for the entire project

    -- ========================
    -- NONE-LS-DIAGNOSTIC MAPPINGS
    -- ========================

    -- Toggle null-ls diagnostics
    map(
        'n',
        '<leader>dn',
        function() -- In normal mode, press 'Space' + 'd' + 'n' to toggle diagnostics for the current buffer
            local null_ls = require('null-ls')
            local method = require('null-ls').methods.DIAGNOSTICS
            local active_sources = null_ls.get_sources()
            local diagnostics_enabled = false
            for _, source in ipairs(active_sources) do
                if source.method == method and source.enabled then
                    diagnostics_enabled = true
                    break
                end
            end
            if diagnostics_enabled then
                null_ls.disable({ method = method })
                print('null-ls diagnostics disabled')
            else
                null_ls.enable({ method = method })
                print('null-ls diagnostics enabled')
            end
        end,
        vim.tbl_extend('force', opts, {
            desc = 'None-ls [d]iagnostic [n]ull-ls toggle on or off',
        })
    )

    -- ========================
    -- TROUBLE.NVIM
    -- ========================

    -- Toggle main diagnostics window
    map('n', '<leader>xd', '<cmd>Trouble diagnostics toggle<cr>', { desc = 'Toggle Diagnostics' })
    -- In normal mode, press 'Space' + 'x' + 'd' to toggle the Trouble diagnostics window

    -- Toggle diagnostics for current buffer only
    map('n', '<leader>xb', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', { desc = 'Buffer Diagnostics' })
    -- In normal mode, press 'Space' + 'x' + 'b' to toggle Trouble diagnostics for current buffer

    -- Toggle symbols window without focus change
    map('n', '<leader>xs', '<cmd>Trouble symbols toggle focus=false<cr>', { desc = 'Document Symbols' })
    -- In normal mode, press 'Space' + 'x' + 's' to toggle symbols window (keep focus)

    -- Toggle LSP references on right side
    map('n', '<leader>xw', '<cmd>Trouble lsp toggle focus=false win.position=right<cr>', { desc = 'LSP References' })
    -- In normal mode, press 'Space' + 'x' + 'w' for right-aligned LSP references

    -- Toggle location list (e.g. search results)
    map('n', '<leader>xl', '<cmd>Trouble loclist toggle<cr>', { desc = 'Location List' })
    -- In normal mode, press 'Space' + 'x' + 'l' to toggle location list

    -- Toggle quickfix list (build errors etc)
    map('n', '<leader>xq', '<cmd>Trouble qflist toggle<cr>', { desc = 'Quickfix List' })
    -- In normal mode, press 'Space' + 'x' + 'q' to toggle quickfix list

    -- Master toggle for all Trouble windows
    map('n', '<leader>xt', '<cmd>Trouble toggle<cr>', { desc = 'Toggle Trouble' })
    -- In normal mode, press 'Space' + 'x' + 't' to toggle any active Trouble window

    -- ==================
    -- NVIM-DAP MAPPINGS
    -- ==================

    -- Start or continue debugging session
    map('n', '<leader>ds', '<cmd>lua require\'dap\'.continue()<CR>', { desc = 'Start/Continue Debug' })
    -- Press <Space> d s to start or continue debugging

    -- Toggle breakpoint at current line
    map('n', '<leader>db', '<cmd>lua require\'dap\'.toggle_breakpoint()<CR>', { desc = 'Toggle Breakpoint' })
    -- Press <Space> d b to toggle breakpoint

    -- Step over the current line
    map('n', '<leader>dS', '<cmd>lua require\'dap\'.step_over()<CR>', { desc = 'Step Over' })
    -- Press <Space> d S to step over

    -- Step into the current function call
    map('n', '<leader>di', '<cmd>lua require\'dap\'.step_into()<CR>', { desc = 'Step Into' })
    -- Press <Space> d i to step into

    -- Step out of the current function
    map('n', '<leader>do', '<cmd>lua require\'dap\'.step_out()<CR>', { desc = 'Step Out' })
    -- Press <Space> d o to step out

    -- Toggle the DAP REPL
    map('n', '<leader>dr', '<cmd>lua require\'dap\'.repl.toggle()<CR>', { desc = 'Toggle REPL' })
    -- Press <Space> d r to toggle the debug REPL

    -- Toggle the DAP UI (if using nvim-dap-ui)
    map('n', '<leader>du', '<cmd>lua require\'dapui\'.toggle()<CR>', { desc = 'Toggle DAP UI' })
    -- In normal mode, Press <Space> d u to toggle the DAP UI

    -- Select debug adapter interactively
    map('n', '<leader>da', function()
        vim.ui.select({ 'python', 'cpp', 'rust', 'rust' }, {
            prompt = 'Select debug adapter:',
            format_item = function(item)
                return ' ' .. item:upper()
            end,
        }, function(choice)
            if choice then
                require('dap').adapters[choice]()
            end
        end)
    end, { desc = 'Select Debug Adapter' })
    -- Press <Space> d a to choose and activate a debug adapter

    -- Toggle verbose debug logging mode
    map('n', '<leader>dv', function()
        require('dap').set_log_level('DEBUG')
        vim.notify('Debug verbosity increased', vim.log.levels.INFO)
    end, { desc = 'Verbose Debug Mode' })
    -- Press <Space> d v to enable verbose debug logging
end

return M
