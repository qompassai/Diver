-- /qompassai/Diver/lsp/styleable_ls.lua
-- Qompass AI Diver Styleable LSP Spec
return {
    cmd = {
        'stylable-ls',
        '--stdio',
    },
    filetypes = {
        'css',
        'styl',
        'stylable',
    },
    root_markers = {
        'package.json',
        '.git',
    },
    settings = {},
}
