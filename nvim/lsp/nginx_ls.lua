-- /qompassai/Diver/lsp/nginx_ls.lua
-- Qompass AI Nginx LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--- pip install -U nginx-language-server
vim.lsp.config['nginx_ls'] = {
    cmd = {
        'nginx-language-server',
    },
    filetypes = {
        'nginx',
    },
    root_markers = {
        'nginx.conf',
        '.git',
    },
}
