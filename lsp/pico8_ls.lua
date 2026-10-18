-- /qompassai/Diver/lsp/pico8_ls.lua
-- Qompass AI Pico8 LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'pico8-ls',
        '--stdio',
    },
    filetypes = {
        'pico8',
        --'lua'
    },
    root_markers = {
        '.git',
        '.p8',
    },
}
