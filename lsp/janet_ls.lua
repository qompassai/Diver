-- /qompassai/Diver/lsp/janet_ls.lua
-- Qompass AI Diver Janet LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'janet-lsp',
        '--stdio',
    },
    filetypes = {
        'janet',
    },
    root_markers = {
        'project.janet',
        '.git',
    },
    settings = {},
}
