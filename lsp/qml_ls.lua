-- /qompassai/Diver/lsp/qml_ls.lua
-- Qompass AI Diver QML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
      capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'qml-lsp',
        '-E',
    },
    filetypes = {
        'qml',
        'qmljs',
    },
       on_attach = require('config.core.lsp').on_attach,
    settings = {},
}