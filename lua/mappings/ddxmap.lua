-- /qompassai/Diver/lua/mappings/ddxmap.lua
-- Qompass AI Diver Diag/debug (ddx) Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.ddxmap'
local M = {}
local api = vim.api
local map = vim.keymap.set
local ddx_group = api.nvim_create_augroup('QompassDDXMappings', {
    clear = true,
})
local function buf_map(bufnr, mode, lhs, rhs, desc)
    map(mode, lhs, rhs, {
        noremap = true,
        silent = true,
        buffer = bufnr,
        desc = desc,
    })
end
local function safe_require(mod)
    local ok, result = pcall(require, mod)
    if ok then
        return result
    end

    vim.notify(
        ('Failed to require %s: %s'):format(mod, tostring(result)),
        vim.log.levels.ERROR,
        { title = 'ddx mappings' }
    )
    return nil
end

function M.setup_ddxmap()
    map('n', '<leader>S', '<cmd>ConfigSelfCheck<CR>', {
        noremap = true,
        silent = true,
        desc = 'Run Neovim config self-check',
    })

    map('n', '<leader>SL', '<cmd>ConfigSelfCheckLog<CR>', {
        noremap = true,
        silent = true,
        desc = 'Open config self-check log',
    })
    map('n', '<leader>SS', '<cmd>ConfigSyntaxCheck<CR>', {
        noremap = true,
        silent = true,
        desc = 'Run config syntax check',
    })
    api.nvim_create_autocmd('FileType', {
        group = ddx_group,
        pattern = 'python',
        callback = function(args)
            local bufnr = args.buf
            buf_map(bufnr, 'n', '<leader>dpm', function()
                local dap_python = safe_require('dap-python')
                if dap_python and type(dap_python.test_method) == 'function' then
                    dap_python.test_method()
                end
            end, '[d]ebug [p]ython [m]ethod')

            buf_map(bufnr, 'n', '<leader>dpc', function()
                local dap_python = safe_require('dap-python')
                if dap_python and type(dap_python.test_class) == 'function' then
                    dap_python.test_class()
                end
            end, '[d]ebug [p]ython [c]lass')

            buf_map(bufnr, 'n', '<leader>dps', function()
                local dap_python = safe_require('dap-python')
                if dap_python and type(dap_python.debug_selection) == 'function' then
                    dap_python.debug_selection()
                end
            end, '[d]ebug [p]ython [s]election')
        end,
    })

    api.nvim_create_autocmd('LspAttach', {
        group = ddx_group,
        callback = function(ev)
            local bufnr = ev.buf

            buf_map(bufnr, 'n', '<leader>dl', function()
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

                vim.api.nvim_echo({
                    { 'Diagnostic virtual_lines: ' .. (new_state and 'enabled' or 'disabled'), 'None' },
                }, false, {})
            end, 'Toggle diagnostic virtual_lines')

            buf_map(bufnr, 'n', '<leader>dq', function()
                vim.diagnostic.setqflist()
            end, 'Show project diagnostics')

            buf_map(bufnr, 'n', '<leader>xd', '<cmd>Trouble diagnostics toggle<CR>', 'Toggle Diagnostics')
            buf_map(bufnr, 'n', '<leader>xb', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', 'Buffer Diagnostics')
            buf_map(bufnr, 'n', '<leader>xs', '<cmd>Trouble symbols toggle focus=false<CR>', 'Document Symbols')

            buf_map(bufnr, 'n', '<leader>mp', '<cmd>MarkdownPreview<CR>', 'Markdown Preview')
            buf_map(bufnr, 'n', '<leader>ms', '<cmd>MarkdownPreviewStop<CR>', 'Stop Markdown Preview')
            buf_map(bufnr, 'n', '<leader>mt', '<cmd>TableModeToggle<CR>', 'Toggle Table Mode')
            buf_map(bufnr, 'n', '<leader>mi', '<cmd>KittyScrollbackGenerateImage<CR>', 'Generate image from code block')
            buf_map(bufnr, 'v', '<leader>mr', ':SnipRun<CR>', 'Run selected code')
        end,
    })

    map('n', '<leader>xw', '<cmd>Trouble lsp toggle focus=false win.position=right<CR>', {
        noremap = true,
        silent = true,
        desc = 'LSP References',
    })

    map('n', '<leader>xl', '<cmd>Trouble loclist toggle<CR>', {
        noremap = true,
        silent = true,
        desc = 'Location List',
    })

    map('n', '<leader>xq', '<cmd>Trouble qflist toggle<CR>', {
        noremap = true,
        silent = true,
        desc = 'Quickfix List',
    })

    map('n', '<leader>xt', '<cmd>Trouble toggle<CR>', {
        noremap = true,
        silent = true,
        desc = 'Toggle Trouble',
    })

    map('n', '<leader>ds', function()
        local dap = safe_require('dap')
        if dap and type(dap.continue) == 'function' then
            dap.continue()
        end
    end, {
        noremap = true,
        silent = true,
        desc = 'Start/Continue Debug',
    })

    map('n', '<leader>db', function()
        local dap = safe_require('dap')
        if dap and type(dap.toggle_breakpoint) == 'function' then
            dap.toggle_breakpoint()
        end
    end, {
        noremap = true,
        silent = true,
        desc = 'Toggle Breakpoint',
    })

    map('n', '<leader>dS', function()
        local dap = safe_require('dap')
        if dap and type(dap.step_over) == 'function' then
            dap.step_over()
        end
    end, {
        noremap = true,
        silent = true,
        desc = 'Step Over',
    })

    map('n', '<leader>di', function()
        local dap = safe_require('dap')
        if dap and type(dap.step_into) == 'function' then
            dap.step_into()
        end
    end, {
        noremap = true,
        silent = true,
        desc = 'Step Into',
    })

    map('n', '<leader>do', function()
        local dap = safe_require('dap')
        if dap and type(dap.step_out) == 'function' then
            dap.step_out()
        end
    end, {
        noremap = true,
        silent = true,
        desc = 'Step Out',
    })

    map('n', '<leader>dr', function()
        local dap = safe_require('dap')
        if dap and dap.repl and type(dap.repl.toggle) == 'function' then
            dap.repl.toggle()
        end
    end, {
        noremap = true,
        silent = true,
        desc = 'Toggle REPL',
    })

    map('n', '<leader>du', function()
        local dapui = safe_require('dapui')
        if dapui and type(dapui.toggle) == 'function' then
            dapui.toggle()
        end
    end, {
        noremap = true,
        silent = true,
        desc = 'Toggle DAP UI',
    })

    map('n', '<leader>da', function()
        local dap = safe_require('dap')
        if not dap or type(dap.adapters) ~= 'table' then
            return
        end

        vim.ui.select({
            'python',
            'cpp',
            'rust',
        }, {
            prompt = 'Select debug adapter:',
            format_item = function(item)
                return ' ' .. item:upper()
            end,
        }, function(choice)
            if not choice then
                return
            end

            local adapter = dap.adapters[choice]
            if type(adapter) == 'function' then
                adapter()
            elseif adapter ~= nil then
                vim.notify(
                    ('DAP adapter %s is configured but not callable'):format(choice),
                    vim.log.levels.WARN,
                    { title = 'ddx mappings' }
                )
            else
                vim.notify(
                    ('DAP adapter %s is not configured'):format(choice),
                    vim.log.levels.WARN,
                    { title = 'ddx mappings' }
                )
            end
        end)
    end, {
        noremap = true,
        silent = true,
        desc = 'Select Debug Adapter',
    })

    map('n', '<leader>dv', function()
        local dap = safe_require('dap')
        if dap and type(dap.set_log_level) == 'function' then
            dap.set_log_level('DEBUG')
        end
        if vim.lsp and vim.lsp.log and vim.lsp.log.set_level then
            vim.lsp.log.set_level('debug')
        end
        vim.api.nvim_echo({
            { 'Debug verbosity increased (DAP + LSP)', 'None' },
        }, false, {})
    end, {
        noremap = true,
        silent = true,
        desc = 'Verbose Debug Mode',
    })
end

return M
