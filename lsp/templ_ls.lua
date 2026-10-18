-- /qompassai/Diver/lsp/templ_ls.lua
-- Qompass AI Templ LSP Spec
-- go install github.com/a-h/templ/cmd/templ@latest
-- Reference: https://templ.guide
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'templ',
        'lsp',
    },
    filetypes = { ---@type string[]
        'templ',
    },
    root_markers = { ---@type string[]
        'go.work',
        'go.mod',
        '.git',
    },
}
