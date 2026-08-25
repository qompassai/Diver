-- /qompassai/Diver/lsp/glslana_ls.lua
-- Qompass AI GLSL Analyzer LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@source https://github.com/nolanderc/glsl_analyzer
return ---@type vim.lsp.Config
{
    cmd = {
        'glsl_analyzer',
    },
    filetypes = {
        'comp',
        'glsl',
        'vert',
        'frag',
        'geom',
        'tesc',
        'tese',
    },
    codeActionProvider = {
        codeActionKinds = {
            '',
            'quickfix',
            'refactor',
        },
        resolveProvider = true,
    },
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        glsl = {
            cmd = {
                'glsl_analyzer',
                '--port',
                '7000',
            },
            defines = {
                'USE_NORMALMAP=1',
                'QUALITY=2',
            },
            includePaths = {
                'shaders/includes',
                'shaders/include',
                'vendor/glsl',
                'vendor/shaders',
            },
            formatter = {
                enabled = true,
            },
        },
    },
}
