-- /qompassai/Diver/lsp/pb_ls.lua
-- Qompass AI Protobuf (Pb) LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'pbls',
    },
    filetypes = {
        'proto',
    },
    root_markers = {
        '.pbls.toml',
        '.git',
    },
    settings = {},
}
