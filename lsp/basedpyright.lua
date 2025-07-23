-- /qompassai/Diver/lsp/basedpyright.lua
-- Qompass AI Basedpyright LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['basedpyright'] = {
    cmd = { 'basedpyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_dir = function(fname)
        return util.root_pattern(unpack(root_files))(fname)
    end,
    single_file_support = true,
    settings = {
        basedpyright = {
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = 'openFilesOnly',
            },
        },
    },
    commands = {
        PyrightOrganizeImports = {
            organize_imports,
            description = 'Organize Imports',
        },
        PyrightSetPythonPath = {
            set_python_path,
            description = 'Reconfigure basedpyright with the provided python path',
            nargs = 1,
            complete = 'file',
        },
    },
}
