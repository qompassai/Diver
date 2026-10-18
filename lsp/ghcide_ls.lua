-- /qompassai/Diver/lsp/ghcide_ls.lua
-- Qompass AI Ghcide LSP Spec
-- Deprecated
-- Reference: https://github.com/digital-asset/ghcide
---@type vim.lsp.Config
return {
    cmd = {
        'ghcide',
        '--lsp',
    },
    filetypes = {
        'haskell',
        'lhaskell',
    },
    root_markers = {
        'BUILD.bazel',
        'cabal.config',
        'hie-bios',
        'package.yaml',
        'stack.yaml',
    },
}
