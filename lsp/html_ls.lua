-- /qompassai/Diver/lsp/html_ls.lua
-- Qompass AI HTML LSP Config
-- pnpm add -g vscode-langservers-extracted
---@type vim.lsp.Config
return {
    cmd = {
        'vscode-html-language-server',
        '--stdio',
    },
    filetypes = {
        'html',
        'templ',
    },
    root_markers = {
        '.git',
        'package.json',
        'package.json5',
    },
    settings = {},
    init_options = {
        provideFormatter = true,
        embeddedLanguages = {
            css = true,
            javascript = true,
        },
        configurationSection = {
            'css',
            'html',
            'javascript',
        },
    },
}
