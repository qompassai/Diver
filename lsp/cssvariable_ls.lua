-- /qompassai/Diver/lsp/cssvariable_ls.lua
-- Qompass AI CSS Variable LSP Spec
return {
    cmd = {
        'css-variables-language-server',
        '--stdio',
    },
    filetypes = {
        'css',
        'scss',
        'less',
    },
    root_markers = {
        'package-lock.json',
        'yarn.lock',
        'pnpm-lock.yaml',
        'bun.lockb',
        'bun.lock',
        '.git',
    },
    settings = {
        cssVariables = {
            lookupFiles = {
                '**/*.less',
                '**/*.scss',
                '**/*.sass',
                '**/*.css',
            },
            blacklistFolders = {
                '**/.cache',
                '**/.DS_Store',
                '**/.git',
                '**/.hg',
                '**/.next',
                '**/.svn',
                '**/bower_components',
                '**/CVS',
                '**/dist',
                '**/node_modules',
                '**/tests',
                '**/tmp',
            },
        },
    },
}
