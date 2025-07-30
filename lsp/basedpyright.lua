-- /qompassai/Diver/lsp/basedpyright.lua
-- Qompass AI Basedpyright LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['basedpyright'] = {
    cmd = { 'basedpyright-langserver', '--stdio' },
    filetypes = { 'python' },
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
            function()
                local params = vim.lsp.util.make_range_params()
                params.context = { only = { "source.organizeImports" } }
                vim.lsp.buf_request(0, "textDocument/codeAction", params, function(_err, _, result)
                    if result and result[1] then
                        vim.lsp.util.apply_workspace_edit(result[1].edit)
                    end
                end)
            end,
            description = 'Organize Imports',
        },
        PyrightSetPythonPath = {
            function(new_path)
                vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", {
                    settings = {
                        python = {
                            pythonPath = new_path,
                        },
                    },
                })
            end,
            description = 'Reconfigure basedpyright with the provided python path',
            nargs = 1,
            complete = 'file',
        },
    },
}
