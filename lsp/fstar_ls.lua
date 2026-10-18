-- /qompassai/Diver/lsp/fstar_ls.lua
-- Qompass AI FStar LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'fstar',
        '--lsp',
    },
    filetypes = {
        'fstar',
    },
    root_markers = {
        '.git',
    },
}
