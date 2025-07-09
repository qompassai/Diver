-- /qompassai/Diver/lua/config/core/lspconfig.lua
-- Qompass AI Diver Lsp Core Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------

---@class LspModule
local M = {}
local css_lang = require('config.ui.css')
local go_lang = require('config.lang.go')
local lua_lang = require('config.lang.lua')
local md_lang = require('config.ui.md')
local nix_lang = require('config.lang.nix')
local rust_lang = require('config.lang.rust')
local zig_lang = require('config.lang.zig')

---@return nil
function M.lsp_autocmds()
  local lsp_group = vim.api.nvim_create_augroup('LspAutocmds', { clear = true })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = lsp_group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        vim.notify(string.format('LSP attached: %s', client.name), vim.log.levels.DEBUG)
      end
    end
  })
  vim.api.nvim_create_autocmd('LspDetach', {
    group = lsp_group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        vim.notify(string.format('LSP detached: %s', client.name), vim.log.levels.DEBUG)
      end
    end
  })
end

---@return LspCapabilities
function M.lsp_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.foldingRange = {
    dynamicRegistration = true,
    lineFoldingOnly = true,
    snippetSupport = true
  }
  capabilities.workspace = {
    fileOperations = { didRename = true, willRename = true }
  }
  return capabilities
end

---@return table

---@class LspServersOpts
---@field capabilities? LspCapabilities
---@param opts LspServersOpts|nil
---@return nil
function M.lsp_servers(opts)
  opts = opts or {}
  local lspconfig = require('lspconfig')
  local util = require('lspconfig.util')
  local capabilities = opts.capabilities or M.lsp_capabilities()
  local default_config = {
    on_attach = M.lsp_on_attach,
    capabilities = capabilities,
    root_dir = util.root_pattern('.git', '.svn', '.hg'),
  }
  local servers = {
    ansiblels = {},
    bashls = {},
    clangd = {
      capabilities = vim.tbl_deep_extend(
        "force",
        capabilities,
        { offsetEncoding = { "utf-8" } }
      ),
    },
    dockerls = {},
    elmls = {},
    graphql = {},
    gopls = go_lang.go_lsp(),
    html = { filetypes = { 'html', 'markdown', 'md' } },
    jdtls = {},
    jsonls = {
      settings = {
        json = {
          schemas = require('schemastore').json.schemas(),
          validate = { enable = true }
        }
      },
      filetypes = { 'json', 'jsonc', 'json5' }
    },
    lua_ls = lua_lang.lua_lsp(),
    marksman = {
			{ md_lang.md_lsp(),
			filetypes = { 'markdown', 'md' }
		}
	},
    metals =  { filetypes = {'sbt', 'java', 'scala' }},
    nil_ls = nix_cfg.nix_lsp(),
    rust_analyzer = rust_cfg.rust_lsp(),
    sqlls = { filetypes = {'sql'} },
    tailwindcss = css_cfg.css_lsp(),
    taplo = { filetypes = {'toml'} },
    texlab = { filetypes = { 'tex', 'latex', 'markdown', 'md' } },
    ts_ls = ts_lang.ts_lsp(opts),
    vimls = {
      settings = {
        isNeovim = true
      }
    },
    yamlls = {
      settings = {
        yaml = {
          schemas = require("schemastore").yaml.schemas(),
          keyOrdering = true,
          validate = true
        }
      }
    },
    zls = zig_lang.zig_lsp(),
  }
  for name, config in pairs(servers) do
    local merged_config = vim.tbl_deep_extend("force", {}, default_config, config or {})
    lspconfig[name].setup(merged_config)
  end
  vim.diagnostic.config({
    virtual_text = { prefix = '●', spacing = 4 },
    float = {
      border = 'rounded',
      source = 'if_many',
      format = function(diagnostic)
        return string.format('%s (%s) [%s]', diagnostic.message,
          diagnostic.source, diagnostic.code or
          (diagnostic.user_data and diagnostic.user_data.lsp and diagnostic.user_data.lsp.code or ""))
      end
    },
    signs = true,
    severity_sort = true,
    underline = true,
    update_in_insert = true,
  })
end

---@param client vim.lsp.Client
---@param bufnr number
function M.lsp_on_attach(client, bufnr)
  if type(bufnr) ~= "number" then
    vim.notify("Invalid buffer number in lsp_on_attach: " .. tostring(bufnr), vim.log.levels.ERROR)
    return
  end
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
  bufmap('n', '[d', function() vim.diagnostic.jump_prev() end, 'Previous Diagnostic')
  bufmap('n', ']d', function() vim.diagnostic.jump_next() end, 'Next Diagnostic')
	vim.notify("LSP attached: " .. client.name, vim.log.levels.INFO)
 end

---@param opts table|nil
---@return table
function M.lsp_setup(opts)
  opts = opts or {}
  local lspconfig = require("lspconfig")
  local capabilities = M.lsp_capabilities()
  return {
    lspconfig = lspconfig,
    capabilities = capabilities,
    autocmds = M.lsp_autocmds,
    config = function()
      M.lsp_servers(vim.tbl_deep_extend("force", { capabilities = capabilities }, opts))
    end,
    on_attach = M.lsp_on_attach,
  }
end

return M
