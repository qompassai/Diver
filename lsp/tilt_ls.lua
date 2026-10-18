-- /qompassai/Diver/lsp/tilt_ls.lua
-- Qompass AI Diver Tilt LSP Spec
---@source https://docs.tilt.dev/
return ---@type vim.lsp.Config
{
    cmd = {
        'tilt',
        'lsp',
        'start',
    },
    filetypes = {
        'tiltfile',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
