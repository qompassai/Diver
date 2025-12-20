-- /qompassai/Diver/lua/config/ui/css.lua
-- Qompass AI Diver CSS Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
local function xdg_config(path)
    return vim.fn.expand(vim.env.XDG_CONFIG_HOME or '~/.config') .. '/' .. path
end
function M.css_autocmds()
    vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'css', 'scss', 'less' },
        callback = function()
            vim.opt_local.tabstop = 2
            vim.opt_local.shiftwidth = 2
            vim.opt_local.expandtab = true
        end,
    })
end

function M.css_colorizer(opts)
    opts = opts or {}
    local ok, colorizer = pcall(require, 'colorizer')
    if not ok then
        return
    end
    local default_opts = {
        filetypes = {
            'css',
            'scss',
            'sass',
            'less',
            'stylus',
            'markdown',
            'html',
            'javascript',
            'typescript',
            'jsx',
            'tsx',
            'vue',
            'svelte',
            'astro',
            'php',
            'lua',
            'vim',
        },
        user_default_options = {
            RGB = true,
            RRGGBB = true,
            names = true,
            RRGGBBAA = true,
            AARRGGBB = true,
            rgb_fn = true,
            hsl_fn = true,
            css = true,
            css_fn = true,
            mode = 'background',
            tailwind = true,
            sass = { enable = true, parsers = { 'css' } },
            virtualtext = '■',
            always_update = true,
        },
        buftypes = {},
    }
    local merged = vim.tbl_deep_extend('force', default_opts, opts)
    colorizer.setup(merged)
    vim.api.nvim_create_autocmd('FileType', {
        pattern = merged.filetypes,
        callback = function()
            colorizer.attach_to_buffer(0)
        end,
    })
end

function M.css_conform(opts)
    opts = opts or {}
    local function merge_config(defaults, overrides)
        return vim.tbl_deep_extend('force', defaults, overrides or {})
    end
    return {
        biome = merge_config({
            command = 'biome',
            args = { 'format', '--stdin-file-path', '$FILENAME' },
            cwd = xdg_config('biome'),
        }, opts.biome_css),
    }
end

function M.nls(opts)
    opts = opts or {}
    local nlsb = require('null-ls').builtins
    local sources = {
        nlsb.formatting.biome.with({
            ft = { 'css', 'scss', 'less' },
            prefer_local = 'node_modules/.bin',
        }),
        nlsb.diagnostics.trail_space.with({
            ft = { 'css', 'scss', 'less' },
        }),
    }
    if opts.sources and type(opts.sources) == 'table' then
        return opts.sources
    end
    return sources
end

function M.css_lsp(on_attach, capabilities)
    local lspconfig = require('lspconfig')
    local function find_tailwind_root(fname)
        local root_files = {
            'tailwind.config.js',
            'tailwind.config.cjs',
            'tailwind.config.mjs',
            'tailwind.config.ts',
            'postcss.config.js',
            'postcss.config.cjs',
            'postcss.config.mjs',
            'postcss.config.ts',
        }
        local dir = vim.fn.fnamemodify(fname, ':p:h')
        while dir and dir ~= '/' do
            for _, root_file in ipairs(root_files) do
                local path = table.concat({ dir, root_file }, '/')
                if vim.fs_stat(path) then
                    return dir
                end
            end
            dir = vim.fn.fnamemodify(dir, ':h')
        end
        local xdg_config_home = os.getenv('XDG_CONFIG_HOME') or vim.fn.expand('~/.config')
        local tailwind_dir = table.concat({ xdg_config_home, 'tailwind' }, '/')
        for _, root_file in ipairs(root_files) do
            local path = table.concat({ tailwind_dir, root_file }, '/')
            if vim.fs_stat(path) then
                return tailwind_dir
            end
        end
        return vim.fn.getcwd()
    end
    lspconfig.cssls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        filetypes = { 'css', 'scss', 'less' },
        settings = {
            css = {
                validate = true,
                lint = {
                    compatibleVendorPrefixes = 'warning',
                    vendorPrefix = 'warning',
                    duplicateProperties = 'warning',
                    emptyRules = 'warning',
                },
            },
            scss = { validate = true },
            less = { validate = true },
        },
    })
    lspconfig.tailwindcss.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        cmd = { 'tailwindcss-language-server', '--stdio' },
        ft = {
            'aspnetcorerazor',
            'astro',
            'astro-markdown',
            'blade',
            'django-html',
            'htmldjango',
            'edge',
            'eelixir',
            'ejs',
            'erb',
            'eruby',
            'gohtml',
            'handlebars',
            'hbs',
            'html',
            'htmlangular',
            'html-eex',
            'heex',
            'liquid',
            'markdown',
            'mdx',
            'mustache',
            'njk',
            'php',
            'razor',
            'slim',
            'twig',
            'css',
            'less',
            'postcss',
            'sass',
            'scss',
            'stylus',
            'javascript',
            'javascriptreact',
            'typescript',
            'typescriptreact',
            'vue',
            'svelte',
        },
        settings = {
            tailwindCSS = {
                validate = true,
                lint = {
                    cssConflict = 'warning',
                    invalidApply = 'error',
                    invalidScreen = 'error',
                    invalidVariant = 'error',
                    invalidConfigPath = 'error',
                    invalidTailwindDirective = 'error',
                    recommendedVariantOrder = 'warning',
                },
                classAttributes = { 'class', 'className', 'class:list', 'classList', 'ngClass' },
                includeLanguages = {
                    eelixir = 'html-eex',
                    eruby = 'erb',
                    templ = 'html',
                    htmlangular = 'html',
                },
            },
        },
        on_new_config = function(new_config)
            new_config.settings = new_config.settings or {}
            new_config.settings.editor = new_config.settings.editor or {}
            new_config.settings.editor.tabSize = new_config.settings.editor.tabSize
                or vim.lsp.util.get_effective_tabstop()
        end,
        root_dir = find_tailwind_root,
    })
end

function M.css_treesitter(opts)
    opts = opts or {}
    local ts_ok, ts_configs = pcall(require, 'nvim-treesitter.configs')
    if not ts_ok then
        return
    end
    local parsers = require('nvim-treesitter.parsers').available_parsers() or {}
    local needed = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(parsers, lang)
    end, { 'css', 'scss' })
    if vim.tbl_isempty(needed) then
        return
    end
    local default_config = {
        sync_install = true,
        auto_install = true,
        highlight = { enable = true },
    }

    local config = vim.tbl_deep_extend('force', default_config, opts)

    ts_configs.setup(config)
end

function M.css_tools(opts)
    opts = opts or {}
    local defaults = {
        server = {
            override = true,
            settings = {
                experimental = {
                    classRegex = { 'tw\\(\'([^\']*)\'\\)' },
                },
                tailwindCSS = {
                    validate = true,
                    classAttributes = { 'class', 'className', 'class:list', 'classList', 'ngClass' },
                    includeLanguages = {
                        eelixir = 'html-eex',
                        eruby = 'erb',
                        templ = 'html',
                        htmlangular = 'html',
                    },
                },
            },
            on_attach = opts.on_attach,
            root_dir = require('lspconfig.util').root_pattern(
                'tailwind.config.js',
                'tailwind.config.ts',
                'tailwind.config.cjs',
                'tailwind.config.mjs',
                'postcss.config.js',
                'postcss.config.ts',
                'postcss.config.cjs',
                'postcss.config.mjs'
            ),
        },
        document_color = {
            enabled = false,
            kind = 'inline',
            inline_symbol = '󰝤 ',
            debounce = 200,
        },
        conceal = {
            enabled = true,
            symbol = '󱏿',
            highlight = { fg = '#38BDF8' },
        },
        keymaps = {
            smart_increment = {
                enabled = true,
                units = { { prefix = 'border', values = { '2', '4', '6', '8' } } },
            },
        },

        cmp = { highlight = 'foreground' },
        telescope = {
            utilities = {
                callback = function(name, class)
                    print(('Selected: %s = %s'):format(name, class))
                end,
            },
        },
        extension = {
            queries = {},
            patterns = {
                rust = { 'class=["\']([^"\']+)["\']' },
                javascript = { 'clsx%(([^)]+)%)' },
            },
        },
    }
    opts = vim.tbl_deep_extend('force', defaults, opts)
    return opts
end

function M.css_config(opts)
    opts = opts or {}
    if not vim.g.qompassai_css_config_initialized then
        M.css_autocmds()
        M.css_colorizer(opts.colorizer)
        M.css_lsp(opts.on_attach, opts.capabilities)
        M.css_treesitter(opts.treesitter)
        vim.g.qompassai_css_config_initialized = true
    end
    return {
        setup = M.css_config,
        null_ls = M.nls,
        conform = M.css_conform,
        lsp = M.css_lsp,
        treesitter = M.css_treesitter,
        colorizer = M.css_colorizer,
        autocmds = M.css_autocmds,
        tailwind_tools = M.css_tools,
    }
end

return M
