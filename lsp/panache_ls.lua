-- /qompassai/Diver/lsp/panache_ls.lua
-- Qompass AI Diver Panache LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
---@source https://github.com/jolars/panache

return ---@type vim.lsp.Config
{
  cmd = {
    'panache',
    'lsp',
  },

  filetypes = {
    'markdown',
    'mdsvex',
    'quarto',
    'rmarkdown',
  },

  on_attach = function(client)
    -- Diagnostics are owned by the native Panache linter.
    client.server_capabilities.diagnosticProvider = nil

    -- Formatting is owned by the formatter layer.
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,

  handlers = {
    ['textDocument/publishDiagnostics'] = function()
      -- Intentionally suppressed.
      --
      -- Diagnostics are provided by:
      -- /qompassai/Diver/lua/linters/panache.lua
      --
      -- This prevents duplicate diagnostics from the Panache
      -- CLI linter and Panache LSP.
    end,
  },

  root_markers = {
    '.panache.toml',
    'panache.toml',
    '.config/panache.toml',

    '_bookdown.yml',
    'bookdown.yml',

    '_quarto.yml',
    '.quarto.yml',
    'quarto.yml',

    '.git',
  },

  settings = {
    panache = {
      -- -----------------------------------------------------------
      -- Core
      -- -----------------------------------------------------------

      cache = false,

      -- Panache supports:
      --   commonmark
      --   gfm
      --   pandoc
      --   quarto
      --   rmarkdown
      --
      -- `pandoc` is the safest general default. Per-project flavor
      -- should normally live in panache.toml.
      flavor = 'pandoc',

      external_max_parallel = 4,

      -- -----------------------------------------------------------
      -- Formatting
      --
      -- LSP formatting is disabled above so these settings do not
      -- compete with your formatter framework. They are retained so
      -- Panache has coherent internal formatting preferences for
      -- features such as edits and code actions.
      -- -----------------------------------------------------------

      format = {
        line_ending = 'lf',
        line_width = 120,
        wrap = 'preserve',
      },

      -- -----------------------------------------------------------
      -- Lint
      --
      -- Diagnostics are intentionally suppressed at the LSP handler
      -- layer because your native Panache linter owns diagnostics.
      --
      -- Keep lint configuration conservative here. Project-specific
      -- rules should live in panache.toml.
      -- -----------------------------------------------------------

      lint = {},

      -- -----------------------------------------------------------
      -- Flavor overrides
      -- -----------------------------------------------------------

      flavor_overrides = {
        ['*.qmd'] = 'quarto',
        ['*.Rmd'] = 'rmarkdown',
        ['*.rmd'] = 'rmarkdown',
      },

      -- -----------------------------------------------------------
      -- External formatters
      --
      -- Intentionally empty.
      --
      -- Your Neovim formatter framework should own external
      -- formatting, rather than allowing Panache to recursively
      -- invoke tools such as StyLua, Ruff, Biome, or shfmt.
      -- -----------------------------------------------------------

      formatters = {},

      -- -----------------------------------------------------------
      
      --
      -- -----------------------------------------------------------

      linters = {},

      -- -----------------------------------------------------------
      -- Experimental
      -- -----------------------------------------------------------

      experimental = {
        format_math = false,
      },
    },
  },
}