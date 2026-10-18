-- /qompassai/Diver/lsp/gleam_ls.lua
-- Qompass AI Diver Gleam LSP Config
return ---@type vim.lsp.Config
{
    cmd = {
        'gleam',
        'lsp',
    },
    filetypes = {
        'gleam',
    },
    root_markers = {
        'gleam.toml',
        '.git',
    },
    settings = {
        gleam = {},
    },
}
