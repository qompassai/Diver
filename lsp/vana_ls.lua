-- /qompassai/Diver/lsp/vana_ls.lua
-- Qompass AI Diver V-Lang LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'v-analyzer',
    },
    filetypes = {
        'v',
        'vsh',
        'vv',
    },
    init_options = {},
    root_markers = {
        'v.mod',
        '.git',
    },
    settings = {},
}
