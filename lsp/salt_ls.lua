-- /qompassai/Diver/lsp/salt_ls.lua
-- Qompass AI Salt LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'salt_lsp_server',
    },
    filetypes = {
        'sls',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
