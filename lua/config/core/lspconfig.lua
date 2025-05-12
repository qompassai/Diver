-- ~/.config/nvim/lua/config/lsp.lua

local M = {}
local go = require("config.lang.go")
local js = require("config.lang.js")
local lua = require("config.lang.lua")
local python = require("config.lang.python")
local rust = require("config.lang.rust")
local scala = require("config.lang.scala")
local zig = require("config.lang.zig")
local util = require("lspconfig.util")

function M.capabilities()
  local ok, blink_cmp = pcall(require, "blink.cmp")
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  
  if ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  capabilities.textDocument.foldingRange = {
    dynamicRegistration = true,
    lineFoldingOnly = true
  }
  
  capabilities.workspace = {
    fileOperations = {
      didRename = true,
      willRename = true
    }
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
  bufmap("n", "]d", vim.diagnostic.goto_next)
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
function M.setup()
  local lspconfig = require("lspconfig")
  local default_config = lspconfig.util.default_config
  default_config.handlers = {
    ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
    ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
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
    lua_ls = lua.get_config(),
    marksman = {},
    pyright = {},
    rust_analyzer = rust.get_config(),
    sqlls = {},
    tailwindcss = {},
    taplo = {},
    vimls = {},
    yamlls = {},
    zls = {},
  }
  if util.root_pattern("deno.json", "deno.jsonc")(vim.fn.getcwd()) then
    servers.denols = js.get_config()
  else
    servers.tsserver = js.get_config()
  end

  for server, config in pairs(servers) do
    lspconfig[server].setup(vim.tbl_deep_extend("force", {
      on_attach = M.on_attach,
      capabilities = M.capabilities(),
      flags = {
        debounce_text_changes = 150,
      },
    }, config))
  end
  go.setup(M.on_attach, M.capabilities())
  scala.setup(M.on_attach, M.capabilities())
  zig.setup(M.on_attach, M.capabilities())
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
    vim.lsp.diagnostic.on_publish_diagnostics, {
      update_in_insert = true,
      severity_sort = true,
    }
  )
end

return M

