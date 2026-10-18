-- /qompassai/Diver/lsp/mm0_ls.lua
-- Qompass AI MetaMath Zero (mm0) LSP Spec
-- References: https://github.com/digama0/mm0/tree/master/mm0-rs)

return ---@type vim.lsp.Config
{
    cmd = { ---@type string[]
        'mm0-rs',
        'server',
    },
    root_markers = { ---@type string[]
        '.git',
    },
    filetypes = { ---@type string[]
        'metamath-zero',
    },
}
