-- /qompassai/Diver/lsp/terraform_ls.lua
-- Qompass AI Terraform_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
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
