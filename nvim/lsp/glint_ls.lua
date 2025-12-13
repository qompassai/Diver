-- /qompassai/Diver/lsp/lint_ls.lua
-- Qompass AI Glint LSP Spec for Glimmer
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference:  https://github.com/typed-ember/glint | https://typed-ember.gitbook.io/glint/
vim.lsp.config['glint_ls'] = {
    cmd = {
        'glint-language-server',
    },
    init_options = {
        glint = {
            useGlobal = true,
        },
    },
    filetypes = {
        'html.handlebars',
        'handlebars',
        'typescript',
        'typescript.glimmer',
        'javascript',
        'javascript.glimmer',
    },
    root_markers = {
        '.glintrc.yml',
        '.glintrc',
        '.glintrc.json',
        '.glintrc.js',
        'glint.config.js',
        'package.json',
    },
    workspace_required = true,
}
