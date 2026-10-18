-- /qompassai/Diver/lsp/sway_ls.lua
-- Qompass AI Sway LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'forc-lsp',
    },
    filetypes = {
        'sway',
    },
    root_markers = {
        'Forc.toml',
        'forc.toml',
        '.git',
    },
    settings = {},
    on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false
    end,
}
