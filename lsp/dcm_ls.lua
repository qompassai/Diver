-- /qompassai/Diver/lsp/dcm_ls.lua
-- Qompass AI Dart Code Metrics (DCM) LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'dcm',
        'start-server',
        '--client=neovim',
    },
    filetypes = {
        'dart',
    },
    root_markers = {
        'pubspec.yaml',
    },
    settings = {},
}
