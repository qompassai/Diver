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
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, blink_cmp = pcall(require, "blink.cmp")
  if ok then
    capabilities = blink_cmp.get_lsp_capabilities(capabilities)
  end
  return capabilities
end
function M.on_attach(_, bufnr)
  local bufmap = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr })
  end
  bufmap("n", "K", vim.lsp.buf.hover)
  bufmap("n", "gd", vim.lsp.buf.definition)
end
function M.setup()
  local lspconfig = require("lspconfig")
  local servers = {
    "ansiblels", -- Ansible
    "bashls", -- Bash
    "clangd", -- C/C++
    "cssls", -- CSS
    "denols", -- Deno
    "dockerls", -- Docker
    "elmls", -- Elm
    "eslint_d", -- JavaScript/TypeScript linting
    "gopls", -- Go
    "graphql", -- GraphQL
    "html", -- HTML
    "jdtls", -- Java
    "jsonls", -- JSON
    "lemminx", -- XML
    "lua_ls", -- Lua
    "marksman", -- Markdown
    "matlab_ls", -- MATLAB
    "metals", --Scala
    "pyright", -- Python
    "r_language_server", -- R
    "solargraph", -- Ruby
    "sqlls", -- SQL
    "tailwindcss", -- Tailwind CSS
    "taplo", -- TOML
    "tsserver", -- TypeScript/JavaScript
    "vimls", -- Vimscript
    "yamlls", -- YAML
    "zls", -- Zig
  }
  if util.root_pattern("deno.json", "deno.jsonc")(vim.fn.getcwd()) then
    table.insert(servers, "denols")
  else
    table.insert(servers, "tsserver")
  end
  local capabilities = M.capabilities()
  for _, lsp in ipairs(servers) do
    if lspconfig[lsp] then
      lspconfig[lsp].setup({
        on_attach = M.on_attach,
        capabilities = capabilities,
      })
    else
      vim.notify("LSP: Server configuration for " .. lsp .. " not found!", vim.log.levels.WARN)
    end
  end
  go.setup(M.on_attach, capabilities)
  js.setup(M.on_attach, capabilities)
  lua.setup(M.on_attach, capabilities)
  python.setup(M.on_attach, capabilities)
  rust.setup(M.on_attach, capabilities)
  scala.setup(M.on_attach, capabilities)
  zig.setup(M.on_attach, capabilities)
end
return M
