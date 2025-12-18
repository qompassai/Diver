-- /qompassai/Diver/lsp/nginx_ls.lua
-- Qompass AI Nginx LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--- pip install -U nginx-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'nginx-language-server',
    },
    filetypes = { ---@type string[]
        'nginx',
    },
    root_markers = { ---@type string[]
        'nginx.conf',
        '.git',
    },
}
