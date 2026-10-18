-- /qompassai/Diver/lsp/rech_ls.lua
-- Qompass AI Diver Rech LSP Spec
return {
    cmd = {
        'node',
        'server.js',
        '--stdio',
    },
    filetypes = {
        'cobol',
        'cbl',
    },
    root_markers = {
        '.git',
        '.cobol-root',
    },
    settings = {},
}
