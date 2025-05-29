-- ~/.config/nvim/lua/config/lspconfig.lua

local M = {}

function M.capabilities()
  local ok, blink_cmp = pcall(require, "blink.cmp")
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  if ok then
    capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
  end

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
  local bufmap = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "LSP: " .. rhs })
  end
  bufmap("n", "K", vim.lsp.buf.hover)
  bufmap("n", "gd", vim.lsp.buf.definition)
  bufmap("n", "gD", vim.lsp.buf.declaration)
  bufmap("n", "gi", vim.lsp.buf.implementation)
  bufmap("n", "gr", vim.lsp.buf.references)
  bufmap("n", "<leader>rn", vim.lsp.buf.rename)
  bufmap("n", "<leader>ca", vim.lsp.buf.code_action)
  bufmap("n", "<leader>fd", vim.diagnostic.open_float)
  bufmap("n", "[d", vim.diagnostic.goto_prev)
  bufmap("]d", vim.diagnostic.goto_next)

  if client.supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(bufnr, true)
  end
  if client.supports_method("textDocument/semanticTokens") then
    vim.lsp.semantic_tokens.start(bufnr)
  end
  if client.supports_method("textDocument/formatting") then
    bufmap("n", "<leader>fm", function()
      vim.lsp.buf.format({ async = true })
    end)
  end
end

function M.setup(opts)
  opts = opts or {}
  opts.servers = opts.servers or {}

  local util = require("lspconfig.util")
  local has_deno = util.root_pattern("deno.json", "deno.jsonc")(vim.fn.getcwd())
  local has_python = util.root_pattern("pyproject.toml", "setup.py", "requirements.txt")(vim.fn.getcwd())

  opts.servers = vim.tbl_deep_extend("force", opts.servers, {
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
    marksman = {},
    rust_analyzer = require("config.lang.rust").get_config(),
    sqlls = {},
    tailwindcss = {},
    taplo = {},
    vimls = {},
    yamlls = {},
    zls = {},
    ast_grep = false,
  })

  if has_deno then
    opts.servers.denols = require("config.lang.js").get_config()
  else
    opts.servers.tsserver = require("config.lang.js").get_config()
  end

  -- Only define the pyright config; let mason-lspconfig handle starting it
  if has_python then
    opts.servers.pyright = {
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

  require("config.lang.go").setup(M.on_attach, M.capabilities())
  require("config.lang.scala").setup(M.on_attach, M.capabilities())
  require("config.lang.zig").setup(M.on_attach, M.capabilities())

  vim.diagnostic.config({
    virtual_text = {
      prefix = "●",
      spacing = 4,
    },
    float = {
      border = "rounded",
      source = "always",
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.supports_method("textDocument/semanticTokens") then
        vim.lsp.semantic_tokens.start(args.buf)
      end
    end,
  })

  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    {
      update_in_insert = true,
      severity_sort = true,
    }
  )

  return opts
end

return M

