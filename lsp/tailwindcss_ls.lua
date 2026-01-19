-- /qompassai/Diver/lsp/tailwindcss_ls.lua
-- Qompass AI TailwindCSS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    before_init = function(_, config) ---@class lsp.LSPObject.editor
        if not config.settings then
            config.settings = {}
        end
        if not config.settings.editor then
            config.settings.editor = {}
        end
        if not config.settings.editor.tabSize then
            config.settings.editor.tabSize = vim.lsp.util.get_effective_tabstop()
        end
    end,
    cmd = {
        'tailwindcss-language-server',
    },
    filetypes = {
        'aspnetcorerazor',
        'astro',
        'astro-markdown',
        'blade',
        'clojure',
        'css',
        'django-html',
        'edge',
        'ejs',
        'eelixir',
        'elixir',
        'erb',
        'eruby',
        'gohtml',
        'gohtmltmpl',
        'haml',
        'handlebars',
        'hbs',
        'heex',
        --'html',
        'html-eex',
        'htmlangular',
        'htmldjango',
        'jade',
        --'js'
        'leaf',
        'less',
        'liquid',
        'markdown',
        'javascript',
        'javascriptreact',
        'mdx',
        --'mixed'
        'mustache',
        'njk',
        'nunjucks',
        'php',
        'postcss',
        'razor',
        'reason',
        'rescript',
        'sass',
        'scss',
        'slim',
        'stylus',
        'sugarss',
        'templ',
        'twig',
        'typescript',
        'typescriptreact',
        'svelte',
        'vue',
    },
    capabilities = {
        workspace = {
            didChangeWatchedFiles = {
                dynamicRegistration = true,
            },
        },
    },
    root_markers = {
        'tailwind.config.js',
        'tailwind.config.cjs',
        'tailwind.config.mjs',
        'tailwind.config.ts',
        'postcss.config.js',
        'postcss.config.cjs',
        'postcss.config.mjs',
        'postcss.config.ts',
        'theme/static_src/tailwind.config.js',
        'theme/static_src/tailwind.config.cjs',
        'theme/static_src/tailwind.config.mjs',
        'theme/static_src/tailwind.config.ts',
        'theme/static_src/postcss.config.js',
        '.git',
    },
    settings = {
        tailwindCSS = {
            classAttributes = {
                'class',
                'className',
                'class:list',
                'classList',
                'ngClass',
            },
            includeLanguages = {
                eelixir = 'html-eex',
                elixir = 'phoenix-heex',
                eruby = 'erb',
                heex = 'phoenix-heex',
                htmlangular = 'html',
                templ = 'html',
            },
            lint = {
                cssConflict = 'warning',
                invalidApply = 'error',
                invalidScreen = 'error',
                invalidVariant = 'error',
                invalidConfigPath = 'error',
                invalidTailwindDirective = 'error',
                recommendedVariantOrder = 'warning',
            },
            validate = true,
        },
    },
}