-- /qompassai/lsp/sourcekit_ls.lua
-- Qompass AI Sourcekit Ls

local LANGUAGE_IDS = {
    objc = 'objective-c',
    objcpp = 'objective-cpp',
}

return ---@type vim.lsp.Config
{
    capabilities = {
        textDocument = {
            diagnostic = {
                dynamicRegistration = true,
                relatedDocumentSupport = true,
            },
        },

        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
            },
        },
    },

    cmd = {
        'sourcekit-lsp',
    },

    filetypes = {
        'c',
        'cpp',
        'objc',
        'objcpp',
        'swift',
    },

    get_language_id = function(_, filetype)
        return LANGUAGE_IDS[filetype] or filetype
    end,

    root_markers = {
        'buildServer.json',

        {
            '*.xcodeproj',
            '*.xcworkspace',
        },

        {
            'compile_commands.json',
            'Package.swift',
        },

        '.git',
    },
}
