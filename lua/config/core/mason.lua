-- /qompassai/Diver/lua/config/core/mason.lua
-- Qompass AI Diver Mason Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
---@return boolean
local function is_neovim_12_plus() return vim.fn.has('nvim-0.12') == 1 end
---@return boolean
local function is_neovim_11_plus() return vim.fn.has('nvim-0.11') == 1 end
---@return nil
local function setup_cargo_optimization()
    vim.env.CARGO_TARGET_DIR = vim.fn.stdpath('cache') .. '/mason-cargo-target'
    vim.env.CARGO_HOME = vim.fn.stdpath('cache') .. '/cargo'
    local uv = vim.uv or vim.loop
    vim.env.CARGO_BUILD_JOBS = tostring(uv.available_parallelism() or 10)
    vim.fn.mkdir(vim.env.CARGO_TARGET_DIR, 'p')
    vim.fn.mkdir(vim.env.CARGO_HOME, 'p')
    vim.env.CARGO_INCREMENTAL = '1'
    vim.env.CARGO_NET_RETRY = '2'
end
require('mason.settings').set({
    PATH = table.concat({
        vim.env.PATH, vim.fn.expand('~/.diver/python/.venv313/bin'),
        vim.fn.expand('~/.diver/python/.venv312/bin'),
        vim.fn.expand('~/.diver/python/.venv311/bin')
    }, ':')
})
vim.env.VIRTUAL_ENV = vim.fn.expand('~/.diver/python/.venv313')
function M.setup_mason()
    setup_cargo_optimization()
    ---@type table<string, any>
    local opts = {
        install_root_dir = vim.fn.stdpath('data') .. '/mason',
        PATH = 'append',
        log_level = vim.log.levels.INFO,
        max_concurrent_installers = 10,
        registries = {'github:mason-org/mason-registry'},
        providers = {'mason.providers.registry-api', 'mason.providers.client'},
        github = {
            download_url_template = 'https://github.com/%s/releases/download/%s/%s'
        },
        ui = {
            check_outdated_packages_on_open = true,
            border = 'none',
            backdrop = 60,
            width = 0.8,
            height = 0.9,
            icons = {
                package_installed = '✓',
                package_pending = '➜',
                package_uninstalled = '✗',
                keymaps = {
                    apply_language_filter = '<C-f>',
                    cancel_installation = '<C-c>',
                    check_outdated_packages = 'C',
                    check_package_version = 'c',
                    install_package = 'i',
                    toggle_help = 'g?',
                    toggle_package_expand = '<CR>',
                    toggle_package_install_log = '<CR>',
                    update_package = 'u',
                    update_all_packages = 'U',
                    uninstall_package = 'X'
                }
            }
        },
        pip = {
            install_args = {
                '--no-warn-script-location', '--isolated',
                '--disable-pip-version-check', '--use-uv'
            }
        }
    }
    if is_neovim_12_plus() then
        opts.registries = {'github:mason-org/mason-registry'}
    elseif is_neovim_11_plus() then
        opts.sources = {'mason.sources.registry'}
    else
        opts.registries = {'github:mason-org/mason-registry'}
        opts.providers = {
            'mason.providers.registry-api', 'mason.providers.client'
        }
    end
    require('mason').setup(opts)
    ---@type table<string, any>
    local installer_opts = {
        ensure_installed = {
            'eslint_d', 'markdownlint', 'prettierd', 'shellcheck', 'stylua',
            'taplo', 'cssls', 'dockerls', 'gopls', 'html', 'jsonls', 'lua_ls',
            'pyright', 'rust_analyzer', 'terraformls', 'ts_ls', 'yamlls', 'zls',
            'ansible-language-server', 'asm-lsp', 'bacon-ls',
            {'bash-language-server', auto_update = true},
            'beancount-language-server', 'editorconfig-checker', 'gofumpt',
            {'golangci-lint', version = 'v1.47.0'}, 'golines', 'gomodifytags',
            'gotests', 'hadolint', 'impl', 'json-to-struct',
            'kotlin-language-server', 'latexindent', 'luacheck', 'misspell',
            'revive', 'rubocop', 'shfmt', 'sql-formatter', 'staticcheck',
            'typstfmt', 'vim-language-server', 'vint'
        },
        auto_update = true,
        run_on_start = true,
        start_delay = 3000,
        debounce_hours = 5,
        integrations = {
            ['mason-lspconfig'] = true,
            ['mason-null-ls'] = true,
            ['mason-nvim-dap'] = true
        }
    }
    require('mason-tool-installer').setup(installer_opts)
    ---@type table<string, any>
    require('mason-lspconfig').setup({
        automatic_enable = true,
        ensure_installed = {
            'cssls', 'dockerls', 'gopls', 'html', 'jsonls', 'lua_ls', 'pyright',
            'rust_analyzer', 'terraformls', 'ts_ls', 'yamlls', 'zls'
        },
        automatic_installation = true
    })
end
return M
