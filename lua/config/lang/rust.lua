-- /qompassai/Diver/lua/config/lang/rust.lua
-- Qompass AI Diver Rust Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------------
vim.env.PATH = vim.env.PATH .. ':' .. vim.fn.expand('~/.cargo/bin')
local M = {}
vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = true,
    severity_sort = true
})
function M.rust_autocmds()
    local augroup = vim.api.nvim_create_augroup('RustAutocmds', {clear = true})
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = augroup,
        pattern = '*.rs',
        callback = function() vim.lsp.buf.format({async = true}) end
    })
    vim.api.nvim_create_autocmd('FileType', {
        group = augroup,
        pattern = 'rust',
        callback = function()
            local ok, rustmap = pcall(require, 'mappings.rustmap')
            if ok and rustmap and type(rustmap.setup) == 'function' then
                rustmap.setup()
            end
        end
    })
end
M.rust_editions = {['2021'] = '2021', ['2024'] = '2024'}
M.rust_toolchains = {stable = 'stable', nightly = 'nightly', beta = 'beta'}
M.rust_default_edition = '2024'
M.rust_default_toolchain = 'nightly'
function M.rust_auto_detect_toolchain()
    local toolchain_file = vim.fn.findfile('rust-toolchain.toml', '.;')
    if toolchain_file ~= '' then
        local content = vim.fn.readfile(toolchain_file)
        for _, line in ipairs(content) do
            local edition = line:match('edition%s*=%s*"(%d+)"')
            local toolchain = line:match('channel%s*=%s*"([%w%-]+)"')
            if edition and M.rust_editions[edition] then
                M.rust_set_edition(edition)
            end
            if toolchain and M.rust_toolchains[toolchain] then
                M.rust_set_toolchain(toolchain)
            end
        end
    end
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
            show_version_date = true
        },
        lsp = {
            enabled = true,
            name = 'crates.nvim',
            actions = true,
            completion = true
        }
    })
    vim.api.nvim_create_autocmd('BufRead', {
        pattern = 'Cargo.toml',
        callback = function() vim.defer_fn(crates.show, 300) end
    })
end
function M.rust_dap()
    local dap = require('dap')
    local dapui = require('dapui')
    dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
            command = '/usr/bin/codelldb',
            args = {'--port', '${port}'}
        }
    }
    dap.configurations.rust = {
        {
            name = 'Launch',
            type = 'codelldb',
            request = 'launch',
            program = function()
                return vim.fn.input('Path to executable: ' .. vim.fn.getcwd() ..
                                        '/')
            end,
            cwd = '${workspaceFolder}',
            stopOnEntry = false,
            args = {}
        }
    }
    dap.listeners.after.event_exited.dapui_config = function() dapui.close() end
end
function M.rust_lsp(capabilities)
    vim.g.rustaceanvim = {
        tools = {float_win_config = {border = 'rounded'}},
        server = {
            on_attach = M.rust_on_attach,
            capabilities = capabilities,
            settings = {['rust-analyzer'] = M.rust_settings()}
        }
    }
    return {
        rust_analyzer = {
            on_attach = M.rust_on_attach,
            capabilities = capabilities,
            settings = {['rust-analyzer'] = M.rust_settings()}
        }
    }
end
function M.rust_nls()
    local null_ls = require('null-ls')
    return {
        null_ls.builtins.formatting.dxfmt.with({
            ft = {'rust'},
            command = 'dx',
            extra_args = {'fmt', '--file', '$FILENAME'}
        }), null_ls.builtins.diagnostics.ltrs.with({
            method = null_ls.methods.DIAGNOSTICS,
            ft = {'text', 'markdown'},
            command = 'ltrs',
            extra_args = {'check', '-m', '-r', '--text', '$TEXT'}
        }), null_ls.builtins.formatting.leptosfmt.with({
            method = null_ls.methods.FORMATTING,
            ft = {'rust'},
            command = 'leptosfmt',
            extra_args = {'--quiet', '--stdin'}
        })
    }
end
function M.rust_on_attach(client, bufnr)
    local opts = {noremap = true, silent = true, buffer = bufnr}
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    if client.server_capabilities.inlayHintProvider then
        vim.lsp.inlay_hint.enable(true, {bufnr = bufnr})
    end
end
function M.rust_refresh_diagnostics()
    vim.cmd('write')
    vim.diagnostic.disable()
    vim.defer_fn(function() vim.diagnostic.enable() end, 200)
end
function M.rust_set_edition(edition)
    if M.rust_editions[edition] then
        M.current_edition = edition
        vim.notify('Rust edition set to ' .. edition, vim.log.levels.INFO)
        vim.cmd('LspRestart')
    else
        vim.notify('Invalid Rust edition: ' .. tostring(edition),
                   vim.log.levels.ERROR)
    end
end
function M.rust_set_toolchain(toolchain)
    if M.rust_toolchains[toolchain] then
        M.current_toolchain = toolchain
        vim.notify('Rust toolchain set to ' .. toolchain, vim.log.levels.INFO)
        vim.cmd('LspRestart')
    else
        vim.notify('Invalid Rust toolchain: ' .. tostring(toolchain),
                   vim.log.levels.ERROR)
    end
end
function M.rust_settings()
    return {
        cargo = {
            allFeatures = true,
            loadOutDirsFromCheck = true,
            runBuildScripts = true
        },
        checkOnSave = true,
        check = {
            command = 'clippy',
            extraArgs = {'--target-dir=target/analyzer'}
        },
        diagnostics = {
            enable = true,
            experimental = {enable = true},
            disabled = {'unresolved-proc-macro', 'macro-error'}
        },
        procMacro = {enable = true, attributes = {enable = true}},
        files = {
            excludeDirs = {
                '.direnv', '.git', 'target', 'node_modules', 'tests/generated',
                '.zig-cache'
            },
            watcher = 'client'
        },
        inlayHints = {
            typeHints = true,
            parameterHints = true,
            chainingHints = true,
            closingBraceHints = true
        },
        rustc = {
            source = M.rust_default_toolchain,
            edition = M.rust_default_edition
        }
    }
end
function M.rust_cfg()
    M.rust_auto_detect_toolchain()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    M.rust_lsp(capabilities)
    require('null-ls').setup({sources = M.rust_nls()})
    M.rust_dap()
    M.rust_crates()
    vim.api.nvim_create_user_command('RustEdition', function(opts)
        M.rust_set_edition(opts.args)
    end, {
        nargs = 1,
        complete = function() return vim.tbl_keys(M.rust_editions) end
    })
    vim.api.nvim_create_user_command('RustToolchain', function(opts)
        M.rust_set_toolchain(opts.args)
    end, {
        nargs = 1,
        complete = function() return vim.tbl_keys(M.rust_toolchains) end
    })
    vim.keymap.set('n', '<leader>rd', M.rust_refresh_diagnostics,
                   {desc = 'Refresh Diagnostics'})
    vim.keymap.set('n', '<leader>re', function()
        vim.ui.select(vim.tbl_keys(M.rust_editions),
                      {prompt = 'Select Rust Edition'}, M.rust_set_edition)
    end, {desc = 'Select Rust Edition'})

    vim.keymap.set('n', '<leader>rst', function()
        vim.ui.select(vim.tbl_keys(M.rust_toolchains),
                      {prompt = 'Rust Select Toolchain'}, M.rust_set_toolchain)
    end, {desc = 'Select Rust Toolchain'})
end
return M
