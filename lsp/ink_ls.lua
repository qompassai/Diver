-- /qompassai/Diver/lsp/ink_ls.lua
-- Qompass AI Ink LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'ink-lsp-server',
    },
    filetypes = {
        'ink',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
