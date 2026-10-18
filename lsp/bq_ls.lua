-- /qompassai/Diver/lsp/bq_ls.lua
-- Qompass AI Big Query (BQ) LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'bqls',
    },
    filetypes = {
        'sql',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
