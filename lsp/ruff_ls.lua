-- /qompassai/Diver/lsp/ruff_ls.lua
-- Qompass AI Diver Ruff LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'ruff',
    'server',
    '--preview',
  },
  filetypes = {
    'python',
  },
  on_attach = function(client)
    client.server_capabilities.semanticTokensProvider = nil
  end,
  root_markers = {
    'pyproject.toml',
    'ruff.toml',
    '.git',
  },
  init_options = {
    settings = {
      configuration = {
        lint = {
          preview = true,
          unfixable = {
            'F401',
          },
          ['extend-select'] = {
            'TID251',
          },
          ['flake8-tidy-imports'] = {
            ['banned-api'] = {
              ['typing.TypedDict'] = {
                msg = 'Use `typing_extensions.TypedDict` instead',
              },
            },
          },
        },
        format = {
          ['quote-style'] = 'single',
        },
      },
      configurationPreference = 'filesystemFirst',
      exclude = {
        '**/tests/**',
      },
      lineLength = 100,
      fixAll = true,
      organizeImports = true,
      showSyntaxErrors = true,
      logLevel = 'info',
      codeAction = {
        disableRuleComment = {
          enable = true,
        },
        fixViolation = {
          enable = true,
        },
      },
      lint = {
        enable = true,
        preview = true,
        select = {
          'E',
          'F',
          'I',
          'UP',
          'W',
          'N',
          'B',
        },
        extendSelect = {
          'W',
          'C4',
          'SIM',
        },
        ignore = {
          'E4',
          'E7',
        },
      },
      format = {
        preview = true,
        backend = 'internal',
      },
    },
  },
}