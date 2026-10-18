-- /qompassai/Diver/lsp/customelements_ls.lua
-- Qompass AI Custom Elements LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'custom-elements-languageserver',
        '--stdio',
    },
    filetypes = {},
    init_options = {
        hostInfo = 'neovim',
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        'tsconfig.json',
        'package.json',
        'jsconfig.json',
        '.git',
    },
    settings = {},
}
