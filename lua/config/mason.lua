---@class MasonSettings
local M = {}

local has_go, go = pcall(require, "config.go")
local has_js, js = pcall(require, "config.js")
local has_lua, lua = pcall(require, "config.lua")
local has_python, python = pcall(require, "config.python")
local has_rust, rust = pcall(require, "config.rust")
local has_scala, scala = pcall(require, "config.scala")
local has_zig, zig = pcall(require, "config.zig")
local mason = require("mason")
local path = require("mason-core.path")

M.get_cmd = function(system_cmd, mason_cmd)
  local system_path = vim.fn.exepath(system_cmd)
  if system_path ~= "" then
    return { system_cmd, "--stdio" }
  else
    local mason_path = vim.fn.stdpath("data") .. "/mason/bin/" .. mason_cmd
    if vim.fn.executable(mason_path) == 1 then
      return { mason_path, "--stdio" }
    else
      vim.notify("No suitable executable found for " .. system_cmd, vim.log.levels.WARN)
      return nil
    end
  end
end

M.setup = function()
  mason.setup({
    install_root_dir = path.concat({ vim.fn.stdpath("data"), "mason" }),
    PATH = "prepend",
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 4,
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
    pip = {
      upgrade_pip = true,
      install_args = {},
    },
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
  })

  require("mason-tool-installer").setup({
    ensure_installed = {
      { "bash-language-server", auto_update = true },
      "editorconfig-checker",
      "gofumpt",
      { "golangci-lint", version = "v1.47.0" },
      "golines",
      "gomodifytags",
      {
        "gopls",
        condition = function()
          return not os.execute("go version")
        end,
      },
      "gotests",
      "impl",
      "json-to-struct",
      "lua-language-server",
      "luacheck",
      "misspell",
      "revive",
      "shellcheck",
      "shfmt",
      "staticcheck",
      "stylua",
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

  if has_go then
    go.setup(M.on_attach, M.capabilities())
  end
  if has_js then
    js.setup(M.on_attach, M.capabilities())
  end
  if has_lua then
    lua.setup(M.on_attach, M.capabilities())
  end
  if has_python then
    python.setup(M.on_attach, M.capabilities())
  end
  if has_rust then
    rust.setup(M.on_attach, M.capabilities())
  end
  if has_scala then
    scala.setup(M.on_attach, M.capabilities())
  end
  if has_zig then
    zig.setup(M.on_attach, M.capabilities())
  end

  local lspconfig = require("lspconfig")
  local mason_lspconfig = require("mason-lspconfig")

  local servers = {
    "lua_ls",
    "gopls",
    "pyright",
    "rust-analyzer",
    "zls",
    "metals",
  }

  mason_lspconfig.setup({
    ensure_installed = servers,
    automatic_installation = true,
  })

  mason_lspconfig.setup_handlers({
    function(server_name)
      lspconfig[server_name].setup({
        on_attach = M.on_attach,
        capabilities = M.capabilities(),
        autostart = true,
      })
    end,
  })

  pcall(function()
    require("telescope").load_extension("zoxide")
  end)
end

function M.capabilities()
  return require("blink.cmp").get_lsp_capabilities()
end

function M.on_attach(_, bufnr)
  local bufmap = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
  end
  bufmap("n", "K", vim.lsp.buf.hover)
  bufmap("n", "gd", vim.lsp.buf.definition)
end



return M
