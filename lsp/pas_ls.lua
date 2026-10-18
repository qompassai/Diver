-- /qompassai/Diver/lsp/pas_ls.lua
-- Qompass AI Diver Pascal LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'pasls',
    },
    filetypes = {
        'pascal',
    },
    root_markers = {
        '*.lpi',
        '*.lpk',
        '.git',
    },
    settings = {},
}
