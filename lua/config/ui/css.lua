-- /qompassai/Diver/lua/config/ui/css.lua
-- Qompass AI Diver UI CSS Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
local api = vim.api
local autocmd = vim.api.nvim_create_autocmd
local group = api.nvim_create_augroup('CSS', {
    clear = true,
})
function M.css_colorizer(opts)
    opts = opts or {}
    local ok, colorizer = pcall(require, 'colorizer')
    if not ok then
        return
    end
    local default_opts = {
        filetypes = {
            'astro',
            'css',
            'html',
            'javascript',
            'jsx',
            'less',
            'lua',
            'markdown',
            'php',
            'sass',
            'scss',
            'stylus',
            'svelte',
            'tsx',
            'typescript',
            'vim',
            'vue',
        },
        user_default_options = {
            css = true,
            css_fn = true,
            RGB = true,
            RRGGBB = true,
            names = true,
            RRGGBBAA = true,
            AARRGGBB = true,
            rgb_fn = true,
            hsl_fn = true,
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
    autocmd('FileType', {
        group = group,
        pattern = merged.filetypes,
        callback = function()
            colorizer.attach_to_buffer(0)
        end,
    })
end
function M.css_config(opts)
    opts = opts or {}
    M.css_colorizer(opts.colorizer)
    return {
        setup = M.css_config,
        colorizer = M.css_colorizer,
    }
end
return M