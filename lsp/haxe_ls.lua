-- /qompassai/Diver/lsp/haxe_ls.lua
-- Qompass AI Haxe LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'node',
        'server.js',
    },
    filetypes = {
        'haxe',
    },
    root_markers = {
        'build.hxml',
        'haxe_libraries',
        '.git',
    },
    init_options = {
        displayArguments = {
            'build.hxml',
        },
    },
    settings = {
        haxe = {
            executable = 'haxe',
            buildCompletionCache = true,
        },
    },
}
