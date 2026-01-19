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
        pattern = {
            'css',
            'scss',
            'less',
        },
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
            sass = {
                enable = true,
                parsers = {
                    'css',
                },
            },
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

function M.css_treesitter(opts)
    opts = opts or {}
    local ts_ok, ts_configs = pcall(require, 'nvim-treesitter.configs')
    if not ts_ok then
        return
    end
    local parsers = require('nvim-treesitter.parsers').available_parsers() or {}
    local needed = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(parsers, lang)
    end, {
        'css',
        'scss',
    })
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

function M.css_config(opts)
    opts = opts or {}
    if not vim.g.qompassai_css_config_initialized then
        M.css_autocmds()
        M.css_colorizer(opts.colorizer)
        M.css_treesitter(opts.treesitter)
        vim.g.qompassai_css_config_initialized = true
    end
    return {
        setup = M.css_config,
        conform = M.css_conform,
        treesitter = M.css_treesitter,
        colorizer = M.css_colorizer,
        autocmds = M.css_autocmds,
    }
end

return M
