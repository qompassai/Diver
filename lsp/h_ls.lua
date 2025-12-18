-- /qompassai/Diver/lsp/hls.lua
-- Qompass AI Haskell/WhitePaperLang LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- https://github.com/haskell/haskell-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'haskell-language-server-wrapper',
        '--lsp',
    },
    filetypes = { ---@type string[]
        'haskell',
        'lhaskell',
        'cabal',
    },
    root_markers = { ---@type string[]
        'hie.yaml',
        'stack.yaml',
        'cabal.project',
        '*.cabal',
        'package.yaml',
    },
    settings = {
        haskell = {
            formattingProvider = 'ormolu',
            cabalFormattingProvider = 'cabal-fmt',
        },
    },
}
