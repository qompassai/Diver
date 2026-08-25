-- /qompassai/Diver/lsp/solargraph_ls.lua
-- Qompass AI Solargraph LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- References:  https://solargaraph.org/
return ---@type vim.lsp.Config
{
  cmd = {
    'solargraph',
    'stdio',
  },
  filetypes = {
    'ruby',
  },
  root_markers = {
    'Gemfile',
    '.solargraph.yml',
    'Fastfile',
    'Appfile',
    'Pluginfile',
    '.ruby-version',
    '.git',
  },
  init_options = {
    formatting = false,
  },
  settings = {
    solargraph = {
      include = {
        '**/*.rb',
      },
      exclude = {
        'spec/**/*',
        'test/**/*',
        'vendor/**/*',
        '.bundle/**/*',
      },
      require = {
        --'rails',
      },
      domains = {},
      reporters = {
        'rubocop',
        'require_not_found',
        'typecheck:strict',
      },
      formatter = 'rubocop',
      rubocop = {
        cops = 'safe',
        except = {},
        only = {},
        extra_args = {},
      },
      requirePaths = {},
      plugins = {
        'solargraph-rails',
      },
      maxFiles = 5000,
      diagnostics = false,
      formatting = false,
      autoformat = false,
      useBundler = false,
      completion = true,
      hover = true,
      symbols = true,
      definitions = true,
      references = true,
      rename = true,
      folding = true,
      checkGemVersion = false,
    },
  },
}
