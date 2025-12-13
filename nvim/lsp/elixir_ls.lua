-- /qompassai/Diver/lsp/elixir_ls.lua
-- Qompass AI Elixir LSP Spec (ElixirLS)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config['elixir_ls'] = {
    cmd = {
        'elixir-ls',
    },
    filetypes = {
        'elixir',
        'heex',
        'elixir',
        'surface',
    },
    codeActionProvider = {
        codeActionKinds = {
            '',
            'quickfix',
            'refactor.extract',
            'refactor.inline',
            'refactor.rewrite',
            'source.organizeImports',
            'source.fixAll',
        },
        resolveProvider = true,
    },
    colorProvider = false,
    semanticTokensProvider = {
        full = true,
        legend = {
            tokenModifiers = {
                'declaration',
                'definition',
                'readonly',
                'static',
                'deprecated',
                'documentation',
                'defaultLibrary',
            },
            tokenTypes = {
                'namespace',
                'type',
                'class',
                'enum',
                'interface',
                'struct',
                'typeParameter',
                'parameter',
                'variable',
                'property',
                'enumMember',
                'event',
                'function',
                'method',
                'macro',
                'keyword',
                'modifier',
                'comment',
                'string',
                'number',
                'regexp',
                'operator',
                'decorator',
            },
        },
        range = true,
    },
    settings = {
        elixirLS = {
            dialyzerEnabled = true,
            dialyzerFormat = 'dialyxir',
            fetchDeps = true,
            enableTestLenses = true,
            mixEnv = 'test',
            suggestSpecs = true,
            enableProjectDiagnostics = true,
            enableWarningsAsDiagnostics = true,
        },
    },
    single_file_support = true,
}
