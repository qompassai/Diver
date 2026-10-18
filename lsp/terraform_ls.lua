-- /qompassai/Diver/lsp/terraform_ls.lua
-- Qompass AI Terraform_ls LSP Config
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'terraform-ls',
        'serve',
    },
    filetypes = { ---@type string[]
        'terraform',
        'terraform-vars',
    },
    root_markers = { ---@type string[]
        '.terraform',
        '.git',
    },
}
