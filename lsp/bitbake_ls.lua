-- /qompassai/Diver/lsp/bitbake_ls.lua
-- Qompass AI BitBake LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'bitbake-language-server',
    },
    filetypes = {
        'bitbake',
    },
    root_markers = {
        '.git',
    },
}
