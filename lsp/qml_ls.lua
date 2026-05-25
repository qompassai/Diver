-- /qompassai/Diver/lsp/qml_ls.lua
-- Qompass AI Diver QML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local qs_imports = '/usr/share/quickshell'
local qt_docs = '/usr/share/doc/qt6'
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'qmlls6',
        '--build-dir',
        vim.fn.getcwd() .. '/build',
        '-I',
        qs_imports,
        '-E',
        '--doc-dir',
        qt_docs,
        '--no-cmake-calls',
        '--verbose',
        '--log-file',
        '/tmp/qmlls.log',
    },
    cmd_env = {
        QMLLS_BUILD_DIRS = vim.fn.getcwd() .. '/build',
        QML_IMPORT_PATH = qs_imports,
        QMLLS_NO_CMAKE_CALLS = '1',
    },
    filetypes = {
        'qml',
        'qmljs',
    },
    root_dir = function(fname)
        return vim.fs.dirname(vim.fs.find({
            'CMakeLists.txt',
            '.qmlls.ini',
            'qmldir',
            '.git',
        }, { path = fname, upward = true })[1]) or vim.fn.getcwd()
    end,
    on_attach = require('config.core.lsp').on_attach,
    settings = {},
}