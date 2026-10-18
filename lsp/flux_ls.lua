-- /qompassai/Diver/lsp/flux_ls.lua
-- Qompass AI Flux LSP Spec
-- Reference: https://github.com/influxdata/flux-lsp
-- cargo install --git https://github.com/influxdata/flux-lsp
---@type vim.lsp.Config
return {
    cmd = {
        'flux-lsp', ---@type string[]
    },
    filetypes = { ---@type string[]
        'flux',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
