-- /qompassai/Diver/lsp/angularls.lua
-- Qompass AI Angular LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://angular.dev/tools/language-service
-- pnpm add -g @angular/language-server@latest
local npm_root = vim.fn.systemlist('npm root -g')[1]
return {
    cmd = {
        'ngserver',
        '--stdio',
        '--tsProbeLocations',
        npm_root,
        '--ngProbeLocations',
        npm_root,
    },
    filetypes = {
        'typescript',
        'typescriptreact',
        'typescript.tsx',
        'html',
    },
    root_markers = {
        'angular.json',
        '.git',
        'workspace.json',
        'project.json',
        'nx.json',
        'package.json',
    },
}
