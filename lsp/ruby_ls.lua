-- /qompassai/Diver/lsp/ruby-lsp.lua
-- Qompass AI Diver Ruby LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.rb',
  callback = function()
    vim.lsp.buf.format()
  end,
})
---@param client vim.lsp.Client
---@param bufnr integer
local function add_ruby_deps_command(client, bufnr)
  local enabled = client.config and client.config.init_options and client.config.init_options.enabledFeatures
  if not enabled then
    return
  end
  vim.api.nvim_buf_create_user_command(bufnr, 'RubyLspDeps', function()
    print('Ruby LSP deps for buffer ' .. bufnr)
  end, {
    desc = 'Show Ruby LSP dependencies',
  })
end
return ---@type vim.lsp.Config
{
  cmd = {
    'ruby-lsp',
  },
  filetypes = {
    'eruby',
    'ruby',
  },
  init_options = {
    enabledFeatures = {
      codeActions = true,
      codeLens = true,
      completion = true,
      definition = true,
      diagnostics = true,
      documentHighlights = true,
      documentLink = true,
      documentSymbols = true,
      foldingRanges = true,
      formatting = true,
      hover = true,
      inlayHint = true,
      onTypeFormatting = true,
      selectionRanges = true,
      semanticHighlighting = true,
      signatureHelp = true,
      typeHierarchy = true,
      workspaceSymbol = true,
    },
    featuresConfiguration = {
      inlayHint = {
        implicitHashValue = true,
        implicitRescue = true,
      },
    },
    indexing = {
      excludedGems = {
        'bootsnap',
        'sass-rails',
      },

      excludedMagicComments = {
        'compiled:true',
        'frozen_string_literal:true',
      },
      excludedPatterns = {
        '.git/**',
        'docs/book/book/**',
        'fastlane/metadata/**',
        'log/**',
        'node_modules/**',
        'public/**',
        'tmp/**',
        'vendor/**',
      },
      experimentalFeaturesEnabled = true, ---@type boolean
      formatter = 'auto', ---@type string
      includedPatterns = { ---@type string[]
        'fastlane/**',
        'lib/**',
        'scripts/**',
        'spec/**',
        'test/**',
      },
      linters = { ---@type string[]
        'rubocop',
      },
    },
  },
  on_attach = function(client, bufnr)
    add_ruby_deps_command(client, bufnr)
  end,
  root_markers = { ---@type string[]
    '.git',
    '.ruby-version',
    'Gemfile',
    'Gemfile.lock',
  },
  single_file_support = true,
}
