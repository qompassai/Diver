-- /qompassai/Diver/lsp/cairo_ls.lua
-- Qompass AI Cairo LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'scarb',
        'cairo-language-server',
        '/C',
        '--node-ipc',
    },
    init_options = {
        hostInfo = 'neovim',
    },
    filetypes = {
        'cairo',
    },
    root_markers = {
        'Scarb.toml',
        'cairo_project.toml',
        '.git',
    },
}
