-- /qompassai/Diver/lsp/hls.lua
-- Qompass AI Haskell/WhitePaperLang LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['cypher_ls'] = {
    cmd = {
        'cypher-language-server',
        '--stdio',
    },
    filetypes = {
        'cypher',
    },
    root_markers = {
        '.git',
    },
}
