-- ~/.config/nvim/lua/config/core/mason.lua
local M = {}
local function is_neovim_12_plus()
  return vim.fn.has("nvim-0.12") == 1
end
local function is_neovim_11_plus()
  return vim.fn.has("nvim-0.11") == 1
end
local function setup_cargo_optimization()
  vim.env.CARGO_TARGET_DIR = vim.fn.stdpath("cache") .. "/mason-cargo-target"
  vim.env.CARGO_HOME = vim.fn.stdpath("cache") .. "/cargo"
  local uv = vim.uv or vim.loop
  vim.env.CARGO_BUILD_JOBS = tostring(uv.available_parallelism() or 10)
  vim.fn.mkdir(vim.env.CARGO_TARGET_DIR, "p")
  vim.fn.mkdir(vim.env.CARGO_HOME, "p")
  vim.env.CARGO_INCREMENTAL = "1"
  vim.env.CARGO_NET_RETRY = "2"
end
function M.setup_mason()
  setup_cargo_optimization()
  local mason = require("mason")
  local opts = {
    install_root_dir = vim.fn.stdpath("data") .. "/mason",
    PATH = "prepend",
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 10,
    registries = {
      "github:mason-org/mason-registry",
    },
    providers = {
      "mason.providers.registry-api",
      "mason.providers.client",
    },
    github = {
      download_url_template = "https://github.com/%s/releases/download/%s/%s",
    },
    ui = {
      check_outdated_packages_on_open = true,
      border = "none",
      backdrop = 60,
      width = 0.8,
      height = 0.9,
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗",
        keymaps = {
          apply_language_filter = "<C-f>",
          cancel_installation = "<C-c>",
          check_outdated_packages = "C",
          check_package_version = "c",
          install_package = "i",
          toggle_help = "g?",
          toggle_package_expand = "<CR>",
          toggle_package_install_log = "<CR>",
          update_package = "u",
          update_all_packages = "U",
          uninstall_package = "X",
        },
      },
    },
    pip = {
      upgrade_pip = true,
      install_args = {
        "--break-system-packages",
        "--user",
        "--no-cache-dir",
      },
    },
  }
  if is_neovim_12_plus() then
    opts.registries = { "github:mason-org/mason-registry" }
  elseif is_neovim_11_plus() then
    opts.sources = { "mason.sources.registry" }
  else
    opts.registries = { "github:mason-org/mason-registry" }
    opts.providers = { "mason.providers.registry-api", "mason.providers.client" }
  end
  mason.setup(opts)
  local mason_tool_installer = require("mason-tool-installer")
  local mason_lspconfig = require("mason-lspconfig")
  local dev_tools = {
    "black",
    "eslint_d",
    "isort",
    "markdownlint",
    "prettierd",
    "shellcheck",
    "stylua",
    "taplo",
  }
  local lsp_servers = {
    "clangd",
    "cssls",
    "dockerls",
    "gopls",
    "html",
    "jsonls",
    "lua_ls",
    "pyright",
    "rust_analyzer",
    "terraformls",
    "ts_ls",
    "yamlls",
    "zls",
  }
  local specialty_tools = {
    "ansible-language-server",
    "asm-lsp",
    "bacon-ls",
    { "bash-language-server", auto_update = true },
    "beancount-language-server",
    "cairo-language-server",
    "codespell",
    "editorconfig-checker",
    "gofumpt",
    { "golangci-lint", version = "v1.47.0" },
    "golines",
    "gomodifytags",
    "gotests",
    "hadolint",
    "impl",
    "json-to-struct",
    "kotlin-language-server",
    "latexindent",
    "leptosfmt",
    "luacheck",
    "misspell",
    "revive",
    "rubocop",
    "shfmt",
    "sql-formatter",
    "staticcheck",
    "typstfmt",
    "vim-language-server",
    "vint",
  }
  local all_tools = vim.iter({ dev_tools, lsp_servers, specialty_tools }):flatten():totable()
  mason_tool_installer.setup({
    ensure_installed = all_tools,
    auto_update = true,
    run_on_start = true,
    start_delay = 3000,
    debounce_hours = 5,
    integrations = {
      ["mason-lspconfig"] = true,
      ["mason-null-ls"] = true,
      ["mason-nvim-dap"] = true,
    },
  })
  mason_lspconfig.setup({
    ensure_installed = lsp_servers,
    automatic_installation = true,
  })
end
return M
