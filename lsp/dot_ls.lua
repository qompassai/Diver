-- /qompassai/Diver/lsp/dot_ls.lua
-- Qompass AI Dot Language Server LSP Config
return ---@type vim.lsp.Config
{
    cmd = {
        'dot-language-server',
        '--stdio',
    },
    filetypes = {
        'dot',
    },
    root_markers = {
        '.git',
    },
}
