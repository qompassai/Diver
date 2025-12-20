-- /qompassai/Diver/lua/config/lang/rust.lua
-- Qompass AI Diver Rust Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------------
local U = require('utils.lang.rust')
U.rust_env()
local M = {}

function M.rust_autocmds()
    local aug = vim.api.nvim_create_augroup('RustAutocmds', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = aug,
        pattern = '*.rs',
        callback = function()
            vim.lsp.buf.format({ async = false })
        end,
    })
    vim.api.nvim_create_autocmd('FileType', {
        group = aug,
        pattern = 'rust',
        callback = function()
            local ok, rustmap = pcall(require, 'mappings.rustmap')
            if ok and rustmap and type(rustmap.setup) == 'function' then
                rustmap.setup()
            end
        end,
    })
end

function M.rust_cfg(opts)
    opts = opts or {}
    U.rust_auto_toolchain()
    require('null-ls').setup({ sources = M.nls(opts) })
    M.rust_dap()
    M.rust_crates()
    vim.api.nvim_create_user_command('RustEdition', function(o)
        U.rust_edition(o.args)
    end, {
        nargs = 1,
        complete = function()
            return vim.tbl_keys(U.rust_editions)
        end,
    })
    vim.api.nvim_create_user_command('RustToolchain', function(o)
        U.rust_set_toolchain(o.args)
    end, {
        nargs = 1,
        complete = function()
            return vim.tbl_keys(U.rust_toolchains)
        end,
    })
    vim.keymap.set('n', '<leader>rd', M.rust_refresh_diagnostics, { desc = 'Rust: refresh diagnostics' })
    vim.keymap.set('n', '<leader>re', function()
        vim.ui.select(vim.tbl_keys(U.rust_editions), { prompt = 'Select Rust edition' }, U.rust_edition)
    end, { desc = 'Rust: select edition' })
    vim.keymap.set('n', '<leader>rt', function()
        vim.ui.select(vim.tbl_keys(U.rust_toolchains), { prompt = 'Select Rust toolchain' }, U.rust_set_toolchain)
    end, { desc = 'Rust: select toolchain' })
end

function M.rust_crates()
    local crates = require('crates')
    crates.setup({
        smart_insert = true,
        insert_closing_quote = true,
        autoload = true,
        autoupdate = true,
        autoupdate_throttle = 250,
        loading_indicator = true,
        date_format = '%Y-%m-%d',
        thousands_separator = '.',
        notification_title = 'crates.nvim',
        popup = {
            autofocus = false,
            hide_on_select = false,
            border = 'none',
            show_version_date = true,
        },
        lsp = {
            enabled = true,
            name = 'crates.nvim',
            actions = true,
            completion = true,
        },
    })
    vim.api.nvim_create_autocmd('BufRead', {
        pattern = 'Cargo.toml',
        callback = function()
            vim.defer_fn(crates.show, 300)
        end,
    })
end

function M.rust_dap()
    local dap = require('dap')
    local dapui = require('dapui')
    dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
            command = vim.fn.exepath('codelldb') or '/usr/bin/codelldb',
            args = { '--port', '${port}' },
        },
    }
    dap.configurations.rust = {
        {
            name = 'Launch',
            type = 'codelldb',
            request = 'launch',
            program = function()
                return vim.fn.input('Path to executable: ' .. vim.fn.getcwd() .. '/')
            end,
            cwd = '${workspaceFolder}',
            stopOnEntry = false,
            args = {},
        },
    }

    dap.listeners.after.event_exited.dapui_config = function()
        dapui.close()
    end
end

function M.nls(opts)
    opts = opts or {}
    local null_ls = require('null-ls')
    local b = null_ls.builtins
    local sources = {
        b.formatting.dxfmt.with({
            ft = { 'rust' },
            command = 'dx',
            extra_args = { 'fmt', '--file', '$FILENAME' },
        }),
        b.diagnostics.ltrs.with({
            method = null_ls.methods.DIAGNOSTICS,
            ft = { 'text', 'markdown' },
            command = 'ltrs',
            extra_args = { 'check', '-m', '-r', '--text', '$TEXT' },
        }),
        b.formatting.leptosfmt.with({
            method = null_ls.methods.FORMATTING,
            ft = { 'rust' },
            command = 'leptosfmt',
            extra_args = { '--quiet', '--stdin' },
        }),
    }
    return sources
end

function M.rust_on_attach(client, bufnr)
    local map_opts = { noremap = true, silent = true, buffer = bufnr }
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, map_opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, map_opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, map_opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, map_opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, map_opts)
    local ih_ok, ih = pcall(require, 'vim.lsp.inlay_hint')
    if ih_ok and client.server_capabilities.inlayHintProvider then
        ih.enable(true, { bufnr = bufnr })
    elseif vim.lsp.inlay_hint then
        vim.lsp.inlay_hint(bufnr, true)
    end
end

function M.rust_refresh_diagnostics()
    vim.cmd('write')
    vim.defer_fn(function()
        vim.diagnostic.enable(false, nil)
    end, 200)
end

function M.rust_rustacean(capabilities)
    return {
        tools = { float_win_config = { border = 'rounded' } },
        server = U.rust_lsp(M.rust_on_attach, capabilities or U.rust_cmp()),
    }
end

return M
