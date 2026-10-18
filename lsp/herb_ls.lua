-- /qompassai/Diver/lsp/herb_ls.lua
-- Qompass AI Diver Herb LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'herb-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'html',
        'eruby',
    },
    init_options = { ---@type table
        linter = {
            enabled = true,
        },
    },
    root_markers = { ---@type string[]
        'Gemfile',
        '.git',
    },
}
