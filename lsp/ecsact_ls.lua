-- /qompassai/Diver/lsp/ecsact_ls.lua
-- Qompass AI Ecsact LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'ecsact_lsp_server',
        '--stdio',
    },
    filetypes = {
        'ecsact',
    },
    root_markers = {
        '.git',
    },
}
