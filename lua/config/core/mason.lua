-- ~/.config/nvim/lua/config/core/mason.lua

local M = {}

local function is_neovim_11_plus()
  return vim.fn.has('nvim-0.11') == 1
end

M.setup_all_mason = function()
  M.setup_mason()
  M.setup_masontools()
end

M.setup_mason = function()
  local mason = require("mason")
  local opts = {
    install_root_dir = require("mason-core.path").concat({ vim.fn.stdpath("data"), "mason" }),
    PATH = "prepend",
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 10,
    ui = {
      check_outdated_packages_on_open = true,
      border = "none",
      backdrop = 60,
      width = 0.8,
      height = 0.9,
      icons = {
        package_installed = "◍",
        package_pending = "◍",
        package_uninstalled = "◍",
      },
      keymaps = {
        toggle_package_expand = "<CR>",
        install_package = "i",
        update_package = "u",
        check_package_version = "c",
        update_all_packages = "U",
        check_outdated_packages = "C",
        uninstall_package = "X",
        cancel_installation = "<C-c>",
        apply_language_filter = "<C-f>",
        toggle_package_install_log = "<CR>",
        toggle_help = "g?",
      },
    },
    github = {
      download_url_template = "https://github.com/%s/releases/download/%s/%s",
    },
    pip = {
      upgrade_pip = true,
      install_args = { "--break-system-packages", "--no-cache-dir" },
    },
  }
  if is_neovim_11_plus() then
    opts.sources = {
      "mason.sources.registry",
    }
  else
    opts.registries = {
      "github:mason-org/mason-registry",
    }
    opts.providers = {
      "mason.providers.registry-api",
      "mason.providers.client",
    }
  end
  mason.setup(opts)
end

M.setup_masontools = function()
  local mason_tool_installer = require("mason-tool-installer")
  local mason_lspconfig = require("mason-lspconfig")

  mason_tool_installer.setup({
    ensure_installed = {
      { "bash-language-server", auto_update = true },
      "editorconfig-checker",
      "gofumpt",
      { "golangci-lint", version = "v1.47.0" },
      "golines",
      "gomodifytags",
      "gopls",
      "black",
      "codespell",
      "eslint_d",
      "gotests",
      "impl",
      "isort",
      "json-to-struct",
      "latexindent",
      "leptosfmt",
      "lua-language-server",
      "luacheck",
      "markdownlint",
      "misspell",
      "prettierd",
      "revive",
      "shellcheck",
      "shfmt",
      "sql-formatter",
      "staticcheck",
      "stylua",
      "taplo",
      "typstfmt",
      "vim-language-server",
      "vint",
    },
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
    ensure_installed = {
      "lua_ls",
      "gopls",
      "intelephense",
      "pyright",
      "zls",
      "jsonls",
    },
    automatic_installation = true,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    pattern = { "*.json", "*.jsonc", "*.json5", "*.jsonl" },
    callback = function()
      vim.lsp.buf.document_highlight()
      vim.diagnostic.reset()
      local semantic_token_refresh = function()
        local refresh_func
        if vim.lsp.buf.semantic_tokens_refresh then
          refresh_func = vim.lsp.buf.semantic_tokens_refresh
        elseif vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.refresh then
          refresh_func = vim.lsp.semantic_tokens.refresh
        end
        if refresh_func then
          pcall(refresh_func)
        end
      end
      semantic_token_refresh()
    end,
  })

  pcall(function()
    local fzf_lua = require("fzf-lua")
    if not fzf_lua.zoxide then
      require("fzf-lua-zoxide")
    end
  end)
end

return M

