-- /qompassai/Diver/lsp/y_ls.lua
-- Qompass AI Diver Yara LSP Spec
return {
    cmd = {
        'yls',
        '-vvv',
    },
    filetypes = {
        'yara',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
