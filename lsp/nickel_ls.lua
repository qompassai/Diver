-- /qompassai/Diver/lsp/nickel_ls.lua
-- Qompass AI Nickel LSP Spec
-- Reference: https://github.com/tweag/nickel
-- cargo install nickel-lang-lsp
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'nls',
    },
    filetypes = { ---@type string[]
        'ncl',
        'nickel',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
