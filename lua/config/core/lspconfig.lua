-- /qompassai/Diver/lua/config/core/lspconfig.lua
-- Qompass AI Diver Lsp Core Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------
local M = {}
local css = require('config.ui.css')
local go = require('config.lang.go')
local lua = require('config.lang.lua')
local nix = require('config.lang.nix')
local rust = require('config.lang.rust')
local scala = require('config.lang.scala')
local ts = require('config.lang.ts')
local zig = require('config.lang.zig')
function M.lsp_autocmds()
  local lsp_group = vim.api.nvim_create_augroup('LspAutocmds', { clear = true })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = lsp_group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        vim.notify(string.format('LSP attached: %s', client.name),
          vim.log.levels.DEBUG)
      end
    end
  })
  vim.api.nvim_create_autocmd('LspDetach', {
    group = lsp_group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        vim.notify(string.format('LSP detached: %s', client.name),
          vim.log.levels.DEBUG)
      end
    end
  })
end

function M.lsp_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.foldingRange = {
    dynamicRegistration = true,
    lineFoldingOnly = true
  }
  capabilities.workspace = {
    fileOperations = { didRename = true, willRename = true }
  }
  local blink_ok, blink = pcall(require, 'blink.cmp')
  if blink_ok and blink.capabilities then
    return vim.tbl_deep_extend('force', capabilities, blink.capabilities())
  end
  return capabilities
end

function M.lsp_config(opts)
  opts = opts or {}
  local lspconfig = require("lspconfig")
  local util = require("lspconfig.util")
  local capabilities = opts.capabilities or M.lsp_capabilities()
  local default_config = {
    on_attach = M.lsp_on_attach,
    capabilities = capabilities,
    root_dir = util.root_pattern('.git', '.svn', '.hg'),
  }
  local servers = {
    ansiblels = {},
    bashls = {},
    clangd = { capabilities = { offsetEncoding = 'utf-8' } },
    cssls = css.css_lsp(),
    dockerls = {},
    elmls = {},
    graphql = {},
    gopls = go.go_lsp(),
    html = {},
    jdtls = {},
    jsonls = {
      settings = {
        json = {
          schemas = require("schemastore").json.schemas(),
          validate = { enable = true }
        }
      },
      filetypes = { "json", "jsonc", "json5" }
    },
    lua_ls = lua.lua_lsp(opts),
    metals = scala.scala_lsp(opts),
    nil_ls = nix.nix_lsp(opts),
    rust_analyzer = rust.rust_lsp(),
    sqlls = {},
    tailwindcss = {},
    taplo = {},
    ts_ls = ts.ts_lsp(opts),
    vimls = {
      settings = {
        isNeovim = true
      }
    },
    yamlls = {
      settings = {
        yaml = {
          schemas = require("schemastore").yaml.schemas(),
          keyOrdering = false,
          validate = true
        }
      }
    },
    zls = zig.zig_lsp(),
  }
  for name, config in pairs(servers) do
    local merged_config = vim.tbl_deep_extend("force", {}, default_config, config)
    lspconfig[name].setup(merged_config)
  end
  vim.diagnostic.config({
    virtual_text = { prefix = '●', spacing = 4 },
    float = {
      border = 'rounded',
      source = 'always',
      format = function(diagnostic)
        return string.format('%s (%s) [%s]', diagnostic.message,
          diagnostic.source, diagnostic.code or
          diagnostic.user_data.lsp.code)
      end
    },
    signs = true,
    severity_sort = true,
    underline = true,
    update_in_insert = true,
  })
end

function M.lsp_on_attach(client, bufnr)
  local bufmap = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end
  bufmap('n', 'K', vim.lsp.buf.hover, 'Hover Documentation')
  bufmap('n', 'gd', vim.lsp.buf.definition, 'Goto Definition')
  bufmap('n', 'gD', vim.lsp.buf.declaration, 'Goto Declaration')
  bufmap('n', 'gi', vim.lsp.buf.implementation, 'Goto Implementation')
  bufmap('n', 'gr', vim.lsp.buf.references, 'Goto References')
  bufmap('n', '<leader>rn', vim.lsp.buf.rename, 'Rename Symbol')
  bufmap('n', '<leader>ca', vim.lsp.buf.code_action, 'Code Actions')
  bufmap('n', '<leader>fd', vim.diagnostic.open_float, 'Show Diagnostic')
  bufmap('n', '[d', vim.diagnostic.goto_prev, 'Previous Diagnostic')
  bufmap('n', ']d', vim.diagnostic.goto_next, 'Next Diagnostic')
  if client.supports_method('textDocument/inlayHint') then
    vim.lsp.inlay_hint.enable(bufnr, true)
  end
  if client.supports_method('textDocument/formatting') then
    bufmap('n', '<leader>fm',
      function() vim.lsp.buf.format({ async = true }) end,
      'Format Buffer')
  end
end

---@param opts? table
function M.lsp_cfg(opts)
  opts = opts or {}
  local lspconfig = require("lspconfig")
  local capabilities = M.lsp_capabilities()
  return {
    autocmds = M.lsp_autocmds,
    lspconfig = lspconfig,
    capabilities = capabilities,
    config = function()
      M.lsp_config(vim.tbl_deep_extend("force", {
        capabilities = capabilities,
      }, opts or {}))
    end,
    on_attach = M.lsp_on_attach,
  }
end
