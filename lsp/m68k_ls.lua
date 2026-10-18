-- /qompassai/Diver/lsp/m68k_ls.lua
-- Qompass AI Motorola 68000 Assembly LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'm68k-lsp-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'asm68k',
    },
    root_markers = { ---@type string[]
        'Makefile',
        '.git',
    },
}
