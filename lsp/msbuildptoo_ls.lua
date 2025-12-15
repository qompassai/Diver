-- /qompassai/Diver/lsp/msbuild_project_tools_server.lua
-- Qompass AI MSBuild LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.filetype.add({
    extension = {
        props = 'msbuild',
        tasks = 'msbuild',
        targets = 'msbuild',
    },
    pattern = {
        [ [[.*\..*proj]] ] = 'msbuild',
    },
})
vim.treesitter.language.register('xml', {
    'msbuild',
})
local host_dll = vim.fn.stdpath('data') .. '/msbuild-project-tools/MSBuildProjectTools.LanguageServer.Host.dll'
vim.lsp.config['msbuildptoo_ls'] = {
    cmd = {
        'dotnet',
        host_dll,
    },
    filetypes = {
        'msbuild',
    },
    root_markers = {
        '*.sln',
        '*.slnx',
        '*.*proj',
        '*.',
        '.git',
    },
}
