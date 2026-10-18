-- /qompassai/Diver/lsp/nginxfmt_ls.lua
-- Qompass AI Nginx Config Formatter LSP Spec
--Reference: https://github.com/slomkowski/nginx-config-formatter
--pip install nginxfmt
vim.lsp.config['nginxfmt_ls'] = {
    cmd = {
        'nginxfmt.py',
    },
    filetypes = {
        'nginx',
        'nginx.conf',
    },
    codeActionProvider = false,
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        nginx_formatter = {},
    },
}
