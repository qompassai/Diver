-- /qompassai/Diver/lsp/postgrestoo_ls.lua
-- Qompass AI PostGresTools LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
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