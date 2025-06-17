-- ~/.config/nvim/lua/config/lspconfig.lua
local M = {}
function M.capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
  capabilities.textDocument.foldingRange = {
    dynamicRegistration = true,
    lineFoldingOnly = true,
  }
  capabilities.workspace = {
    fileOperations = {
      didRename = true,
      willRename = true,
    },
  }
  return capabilities
end
function M.on_attach(client, bufnr)
  local bufmap = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end
  bufmap("n", "K", vim.lsp.buf.hover, "Hover Documentation")
  bufmap("n", "gd", vim.lsp.buf.definition, "Goto Definition")
  bufmap("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
  bufmap("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
  bufmap("n", "gr", vim.lsp.buf.references, "Goto References")
  bufmap("n", "<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
  bufmap("n", "<leader>ca", vim.lsp.buf.code_action, "Code Actions")
  bufmap("n", "<leader>fd", vim.diagnostic.open_float, "Show Diagnostic")
  bufmap("n", "[d", vim.diagnostic.goto_prev, "Previous Diagnostic")
  bufmap("n", "]d", vim.diagnostic.goto_next, "Next Diagnostic")

  if client.supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(bufnr, true)
  end

  if client.supports_method("textDocument/formatting") then
    bufmap("n", "<leader>fm", function()
      vim.lsp.buf.format({ async = true })
    end, "Format Buffer")
  end
end

function M.setup(opts)
  opts = opts or {}
  local lspconfig = require("lspconfig")
  local util = require("lspconfig.util")

  local default_config = {
    on_attach = M.on_attach,
    capabilities = M.capabilities(),
    root_dir = util.root_pattern(".git", ".svn", ".hg"),
  }

  local servers = {
    ansiblels = {},
    bashls = {},
    clangd = {
      capabilities = {
        offsetEncoding = "utf-8",
      },
    },
    cssls = {},
    dockerls = {},
    elmls = {},
    gopls = {},
    graphql = {},
    html = {},
    jdtls = {},
    jsonls = {
      settings = {
        json = {
          schemas = require("schemastore").json.schemas(),
        },
      },
    },
    lua_ls = require("config.lang.lua").get_config(),
    metals = require("config.lang.scala").get_config(),
    rust_analyzer = require("config.lang.rust").get_config(),
    sqlls = {},
    tailwindcss = {},
    taplo = {},
    vimls = {},
    yamlls = {},
    zls = require("config.lang.zig").get_config(),
  }

  local has_deno = util.root_pattern("deno.json", "deno.jsonc")(vim.fn.getcwd())
  local has_python = util.root_pattern("pyproject.toml", "setup.py", "requirements.txt")(vim.fn.getcwd())

  if has_deno then
    servers.denols = require("config.lang.js").get_config()
  else
    servers.tsserver = require("config.lang.js").get_config()
  end

  if has_python then
    servers.pyright = {
      settings = {
        python = {
          analysis = {
            typeCheckingMode = "basic",
            diagnosticMode = "workspace",
            inlayHints = {
              variableTypes = true,
              functionReturnTypes = true,
            },
          },
        },
      },
    }
  end

  for server, config in pairs(servers) do
    local merged_config = vim.tbl_deep_extend("force", default_config, config)
    lspconfig[server].setup(merged_config)
  end

  vim.diagnostic.config({
    virtual_text = {
      prefix = "●",
      spacing = 4,
    },
    float = {
      border = "rounded",
      source = "always",
      format = function(diagnostic)
        return string.format("%s (%s) [%s]", diagnostic.message, diagnostic.source, diagnostic.code or diagnostic.user_data.lsp.code)
      end,
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
  })

  require("config.lang.go").setup(M.on_attach, M.capabilities())
  require("config.lang.scala").setup(M.on_attach, M.capabilities())
  require("config.lang.zig").setup(M.on_attach, M.capabilities())
end

return M
