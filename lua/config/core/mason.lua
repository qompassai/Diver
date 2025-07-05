-- /qompassai/Diver/lua/config/core/mason.lua
-- Qompass AI Diver Mason Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}

local function configure_env()
  local uv = vim.uv or vim.loop
  vim.env.CARGO_BUILD_JOBS  = tostring(uv.available_parallelism() or 10)
  vim.env.CARGO_INCREMENTAL = '1'
  vim.env.CARGO_NET_RETRY   = '2'
  if not vim.env.CARGO_TARGET_DIR or vim.env.CARGO_TARGET_DIR == '' then
    vim.env.CARGO_TARGET_DIR = vim.fn.expand('~/.cache/cargo/target')
  end
  if not vim.env.CARGO_HOME or vim.env.CARGO_HOME == '' then
    vim.env.CARGO_HOME = vim.fn.expand('~/.cargo')
  end
  vim.fn.mkdir(vim.env.CARGO_TARGET_DIR, 'p')
  vim.fn.mkdir(vim.env.CARGO_HOME,       'p')
  local py_venvs = {
    vim.fn.expand('~/.diver/python/.venv313/bin'),
    vim.fn.expand('~/.diver/python/.venv312/bin'),
    vim.fn.expand('~/.diver/python/.venv311/bin'),
  }
  vim.env.PATH = table.concat(py_venvs, ':') .. ':' .. vim.env.PATH
end
local function setup_autocmds()
  local mason_au = vim.api.nvim_create_augroup('Mason', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
    group = mason_au,
    pattern = { '*.json', '*.jsonc', '*.json5', '*.jsonl' },
    callback = function()
      pcall(vim.lsp.buf.document_highlight)
      vim.diagnostic.reset()

      local refresh = vim.lsp.buf.semantic_tokens_refresh
          or (vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.refresh)
      if refresh then pcall(refresh) end
    end,
  })
  for _, evt in ipairs({ 'MasonInstallComplete', 'MasonUpdateComplete' }) do
    vim.api.nvim_create_autocmd('User', {
      group = mason_au,
      pattern = evt,
      callback = function(args)
        local name = args.data.package.name
        local icon = evt == 'MasonInstallComplete' and '✅' or '🔄'
        vim.notify(string.format('%s Mason %s: %s', icon,
            evt == 'MasonInstallComplete' and 'installed' or 'updated', name),
          vim.log.levels.INFO)
      end,
    })
  end
end
function M.mason_setup()
  configure_env()
  setup_autocmds()
    require("mason").setup({
    install_root_dir          = vim.fn.stdpath('data') .. '/mason',
    PATH                      = 'append',
    log_level                 = vim.log.levels.INFO,
    max_concurrent_installers = 10,
    registries                = { 'github:mason-org/mason-registry' },
    providers                 = { 'mason.providers.registry-api', 'mason.providers.client' },
    github                    = {
      download_url_template = 'https://github.com/%s/releases/download/%s/%s',
    },
    ui                        = {
      check_outdated_packages_on_open = true,
      border                          = 'none',
      backdrop                        = 60,
      width                           = 0.8,
      height                          = 0.9,
      icons                           = {
        package_installed   = '✓',
        package_pending     = '➜',
        package_uninstalled = '✗',
        keymaps             = {
          apply_language_filter      = '<C-f>',
          cancel_installation        = '<C-c>',
          check_outdated_packages    = 'C',
          check_package_version      = 'c',
          install_package            = 'i',
          toggle_help                = 'g?',
          toggle_package_expand      = '<CR>',
          toggle_package_install_log = '<CR>',
          update_package             = 'u',
          update_all_packages        = 'U',
          uninstall_package          = 'X',
        },
      },
    },
    pip                       = {
      install_args = {
        '--no-warn-script-location',
        '--isolated',
        '--disable-pip-version-check'},
    }
    })
end

  function M.mason_tools()
    return {
    ensure_installed = {},
    auto_update      = true,
    run_on_start     = false,
    debounce_hours   = 5,
    integrations     = {
      ['mason-lspconfig'] = true,
      ['mason-null-ls']   = true,
      ['mason-nvim-dap']  = true,
    },
  }
  end
  function M.mason_lspconfig()
    return { ensure_installed = {},
    automatic_enable       = { "lua_ls", 'nil_ls', "vimls", 'bashls', 'pyright', 'zls', 'yamlls' },
    exclude                = {
      "rust_analyzer",
      "ts_ls",
      "harper-ls",
      'tailwindcss'
    },
    automatic_installation = true,
  }
end
function M.mason_dap()
  return {
    ensure_installed       = {},
    automatic_installation = true,
  }
end
M.mason_env      = configure_env
M.mason_autocmds = setup_autocmds
return M
