-- /qompassai/dotfiles/.configpyrefly.lua
-- Qompass AI Pyrefly LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------
vim.lsp.config['pyrefly'] = {
  cmd = {
    'pyrefly',
    'lsp',
  },
  codeActionProvider = {
    codeActionKinds = {
      '',
      'quickfix',
      'refactor.extract',
      'refactor.rewrite',
    },
    resolveProvider = true,
  },
  colorProvider = true,
  filetypes = {
    'python',
  },
  root_markers = {
    '.git',
    'MANIFEST.in',
    'pyproject.toml',
    'pyrefly.toml',
    'requirements.txt',
    'setup.cfg',
    'setup.py',
  },
  semanticTokensProvider = {
    full = true,
    legend = {
      tokenModifiers = {
        'abstract',
        'async',
        'declaration',
        'defaultLibrary',
        'definition',
        'deprecated',
        'documentation',
        'global',
        'modification',
        'readonly',
        'static',
      },
      tokenTypes = {
        'class',
        'comment',
        'decorator',
        'enum',
        'enumMember',
        'event',
        'function',
        'interface',
        'keyword',
        'macro',
        'method',
        'modifier',
        'namespace',
        'number',
        'operator',
        'parameter',
        'property',
        'regexp',
        'string',
        'struct',
        'type',
        'typeParameter',
        'variable',
      },
    },
    range = true,
  },
  settings = {
    pyrefly = {
      analysis = {
        autoSearchPaths = true,
        typeCheckingMode = 'strict',
        useLibraryCodeForTypes = true,
      },
      completion = {
        enable = true,
      },
      diagnostics = {
        enable = true,
      },
      hint = {
        enable = true,
      },
      telemetry = {
        enable = false,
      },
    },
  },
}