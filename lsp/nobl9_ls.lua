-- /qompassai/diver/lsp/nobl9_ls.lua
-- Qompass AI Nobl9 LSP Spec
return { ---@type vim.lsp.Config
    cmd = {
        'nobl9-language-server',
    },
    filetypes = {
        'yaml',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
