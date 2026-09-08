-- /qompassai/Diver/lsp/msbuild_project_tools_server.lua
-- Qompass AI MSBuild LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.filetype.add({ ---@type string[]
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
---@type vim.lsp.Config
return {
    cmd = {
        'dotnet',
        host_dll,
    },
    filetypes = { ---@type string[]
        'msbuild',
    },
    root_markers = { ---@type string[]
        '*.sln',
        '*.slnx',
        '*.*proj',
        '*.',
        '.git',
    },
}
