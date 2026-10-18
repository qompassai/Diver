-- /qompassai/Diver/lsp/crystalline_ls.lua
-- Qompass AI Crystalline LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'crystalline',
    },
    filetypes = {
        'crystal',
    },
    root_markers = {
        'shard.yml',
        '.git',
    },
}
