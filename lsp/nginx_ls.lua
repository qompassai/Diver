-- /qompassai/Diver/lsp/nginx_ls.lua
-- Qompass AI Nginx LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
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
