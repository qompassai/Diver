-- /qompassai/Diver/lsp/deno.lua
-- Qompass AI Diver Deno LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'deno',
        'lsp',
    },
    filetypes = {
        'javascript',
        'json',
        'jsonc',
        'jsx',
        --'markdown',
        'typescriptreact',
        'javascriptreact',
        'tsx',
        'typescript',
    },
    init_options = {
        deno = {
            enable = true,
            unstable = true,
            lint = true,
            certificateStores = {},
            tlsCertificate = '',
            unsafelyIgnoreCertificateErrors = false,
            internalDebug = true,
            codeLens = {
                implementations = true,
                references = true,
                referencesAllFunctions = true,
                test = true,
            },
            suggest = {
                autoImports = true,
                names = true,
                paths = true,
                completeFunctionCalls = true,
                imports = {
                    autoDiscover = true,
                    hosts = {
                        ['https://deno.land'] = true,
                        ['https://cdn.nest.land'] = true,
                        ['https://crux.land'] = true,
                    },
                },
            },
        },
    },
    root_markers = {
        'deno.json',
        'deno.jsonc',
        'tsconfig.json',
        '.git',
    },
}
