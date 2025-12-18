-- /qompassai/Diver/lsp/stylua3p_ls.lua
-- Qompass AI Stylua 3rd Party LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/antonk52/lua-3p-language-servers
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'stylua-3p-language-server',
    },
    filetypes = { ---@type string[]
        'lua',
    },
    root_markers = { ---@type string[]
        '.stylua.toml',
        'stylua.toml',
    },
}
