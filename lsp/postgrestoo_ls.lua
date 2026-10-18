-- /qompassai/Diver/lsp/postgrestoo_ls.lua
-- Qompass AI PostGresTools LSP Spec
-- Reference:  https://pg-language-server.com
---@type vim.lsp.Config
return {
    cmd = {
        'postgrestools',
        'lsp-proxy',
    },
    filetypes = {
        'sql',
    },
    root_markers = {
        'postgrestools.jsonc',
    },
    settings = {},
    workspace_required = true,
}
