-- /qompassai/Diver/lsp/smithy_ls.lua
-- Qompass AI Smithy LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'coursier',
        'launch',
        'software.amazon.smithy:smithy-language-server:0.7.0',
        '-M',
        'software.amazon.smithy.lsp.Main',
        '--',
        '0',
    },
    filetypes = { ---@type string[]
        'smithy',
    },
    root_markers = { ---@type string[]
        'smithy-build.json',
        'build.gradle',
        'build.gradle.kts',
        '.git',
    },
    message_level = vim.lsp.protocol.MessageType.Log,
    init_options = {
        statusBarProvider = 'show-message',
        isHttpEnabled = true,
        compilerOptions = {
            snippetAutoIndent = true,
        },
    },
}
