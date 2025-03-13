local M = {}

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
  local lspconfig = require("lspconfig")
  local mason_lspconfig = require("mason-lspconfig")
  local on_attach = require("plugins.configs.lspconfig").on_attach
  local capabilities = require("plugins.configs.lspconfig").capabilities

  require("mason").setup({
    PATH = "prepend",
    ui = {
      border = "rounded",
    },
  })

  mason_lspconfig.setup({
    ensure_installed = {
      "bashls",
      "clangd",
      "cmake",
      "denols",
      "dockerls",
      "gitlabci_lint",
      "gopls",
      "hyprls",
      "jdtls",
      "jsonls",
      "lua_ls",
      "marksman",
      "neocmake",
      "pylsp",
      "taplo",
      "tsserver",
      "yamlls",
    },
    automatic_installation = false,
  })

  mason_lspconfig.setup_handlers({
    function(server_name)
      local cmd = M.get_cmd(server_name, server_name)
      if cmd then
        lspconfig[server_name].setup({
          cmd = cmd,
          on_attach = on_attach,
          capabilities = capabilities,
          autostart = false,
        })
      else
        vim.notify("Could not start server " .. server_name .. ": No suitable executable found.", vim.log.levels.INFO)
      end
    end,
    ["lua_ls"] = function()
      local cmd = M.get_cmd("lua-language-server", "lua-language-server")
      if cmd then
        lspconfig.lua_ls.setup({
          cmd = cmd,
          on_attach = function(client, bufnr)
            on_attach(client, bufnr)
            vim.api.nvim_create_autocmd("CursorHold", {
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.hover()
              end,
            })
          end,
          capabilities = capabilities,
          settings = {
            Lua = {
              runtime = {
                version = "LuaJIT",
              },
              diagnostics = {
                globals = { "vim", "jit" },
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = true,
              },
              telemetry = {
                enable = false,
              },
            },
          },
        })
      else
        vim.notify("Could not start Lua language server: No suitable executable found.", vim.log.levels.INFO)
      end
    end,
  })
end

return M
