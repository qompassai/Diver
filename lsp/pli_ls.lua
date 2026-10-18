-- /qompassai/Diver/lsp/pli_ls.lua
-- Qompass AI  PL/I LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'pli_language_server',
    },
    filetypes = {
        'pli',
    },
    root_markers = {
        '.pliplugin',
    },
}
