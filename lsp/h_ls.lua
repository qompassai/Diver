-- /qompassai/Diver/lsp/h_ls.lua
-- Qompass AI Haskell/WhitePaperLang LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'haskell-language-server-wrapper',
        '--lsp',
    },
    filetypes = {
        'haskell',
        'lhaskell',
        'cabal',
    },
    root_markers = {
        '*.cabal',
        'cabal.project',
        'hie.yaml',
        'stack.yaml',
        'package.yaml',
    },
    settings = {
        haskell = {
            cabalFormattingProvider = 'cabal-fmt',
            checkParents = 'CheckOnSave',
            checkProject = true,
            formattingProvider = 'ormolu',
            plugin = {
                class = {
                    globalOn = true,
                },
                eval = {
                    globalOn = true,
                    config = {
                        diff = true,
                        exception = false,
                    },
                },
                ['ghcide-code-actions-bindings'] = {
                    globalOn = true,
                },
                ['ghcide-code-actions-fill-holes'] = {
                    globalOn = true,
                },
                ['ghcide-code-actions-imports-exports'] = {
                    globalOn = true,
                },
                ['ghcide-code-actions-type-signatures'] = {
                    globalOn = true,
                },
                ['ghcide-completions'] = {
                    globalOn = true,
                    completionOn = true,
                    config = {
                        autoExtendOn = true,
                        snippetsOn = true,
                    },
                },
                ['ghcide-hover-and-symbols'] = {
                    globalOn = true,
                    hoverOn = true,
                    symbolsOn = true,
                },
                ['ghcide-type-lenses'] = {
                    globalOn = true,
                    codeLensOn = true,
                    config = {
                        mode = 'always',
                    },
                },
                hlint = {
                    globalOn = true,
                    diagnosticsOn = true,
                    codeActionsOn = true,
                    config = {
                        flags = {
                            '-XQuasiQuotes',
                        },
                    },
                },
                importLens = {
                    globalOn = true,
                    codeLensOn = true,
                },
                moduleName = {
                    globalOn = true,
                    codeActionsOn = true,
                },
                ['plugin.ormolu'] = {
                    config = {
                        external = false,
                    },
                },
                ['plugin.fourmolu'] = {
                    config = {
                        external = false,
                    },
                },
                pragmas = {
                    globalOn = true,
                    codeActionsOn = true,
                },
                rename = {
                    globalOn = true,
                    renameOn = true,
                    config = {
                        crossModule = true,
                    },
                },
                retrie = {
                    globalOn = true,
                    codeActionsOn = true,
                },
                signatureHelp = {
                    globalOn = true,
                    signatureHelpOn = true,
                },
                splice = {
                    globalOn = true,
                    codeActionsOn = true,
                },
                stan = {
                    globalOn = true,
                },
            },
        },
    },
}