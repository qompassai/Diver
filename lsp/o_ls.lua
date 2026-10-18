-- /qompassai/Diver/lsp/o_ls.lua
-- Qompass AI Odin LSP Spec
--Reference: https://github.com/DanielGavin/ols
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'ols',
    },
    filetypes = { ---@type string[]
        'odin',
    },
    root_markers = { ---@type string[]
        '.git',
        'ols.json',
        'ols.jsonc',
        '*.odin',
    },
}
