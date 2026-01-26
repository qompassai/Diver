-- /qompassai/Diver/lua/config/ui/css.lua
-- Qompass AI Diver CSS Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
local gtk_selectors = {
    ['backdrop'] = {
        documentation = 'GTK-specific pseudo-class for backdrop/unfocused window state',
        function_selector = false,
    },
    ['drop'] = {
        args = 'active',
        documentation = 'GTK-specific pseudo-class for drag-and-drop states',
        function_selector = true,
    },
}
local gtk_properties = {
    ['-gtk-dpi'] = {
        documentation = 'Controls DPI scaling for GTK applications',
    },
    ['-gtk-icon-filter'] = {
        documentation = 'Applies filter effects to icons',
    },
    ['-gtk-icon-palette'] = {
        documentation = 'Defines color palette for symbolic icons',
    },
    ['-gtk-secondary-caret-color'] = {
        documentation = 'Sets the color of the secondary caret in bidirectional text',
    },
    ['-gtk-icon-shadow'] = {
        documentation = 'Applies shadow effects to icons',
    },
    ['-gtk-icon-size'] = {
        documentation = 'Sets the size of icons',
    },
    ['-gtk-icon-source'] = {
        documentation = 'Specifies the source image for icons',
    },
    ['-gtk-icon-style'] = {
        documentation = 'Controls icon rendering style',
    },
    ['-gtk-icon-transform'] = {
        documentation = 'Applies CSS transforms to icons',
    },
}
local gtk_colors = {
    ['@accent_color'] = 'Accent color used across widgets for important/interactive elements',
    ['@accent_bg_color'] = 'Accent background color',
    ['@accent_fg_color'] = 'Accent foreground color',
    ['@borders'] = 'Border color for high contrast mode',
    ['@card_bg_color'] = 'Card and boxed list background color',
    ['@card_fg_color'] = 'Card and boxed list foreground color',
    ['@card_shade_color'] = 'Card and boxed list shade color',
    ['@destructive_color'] = 'Color for dangerous actions like deleting files',
    ['@destructive_bg_color'] = 'Destructive action background color',
    ['@destructive_fg_color'] = 'Destructive action foreground color',
    ['@error_bg_color'] = 'Error background color',
    ['@error_color'] = 'Error status color',
    ['@error_fg_color'] = 'Error foreground color',
    ['@headerbar_bg_color'] = 'Header bar background color',
    ['@headerbar_fg_color'] = 'Header bar foreground color',
    ['@headerbar_border_color'] = 'Header bar border color',
    ['@headerbar_backdrop_color'] = 'Header bar backdrop state color',
    ['@headerbar_shade_color'] = 'Header bar shade color',
    ['@popover_bg_color'] = 'Popover background color',
    ['@popover_fg_color'] = 'Popover foreground color',
    ['@scrollbar_outline_color'] = 'Scrollbar outline for visibility',
    ['@shade_color'] = 'Scroll undershoots and transitions (partially transparent black)',
    ['@sidebar_bg_color'] = 'Sidebar background color',
    ['@sidebar_fg_color'] = 'Sidebar foreground color',
    ['@sidebar_backdrop_color'] = 'Sidebar backdrop state color',
    ['@sidebar_shade_color'] = 'Sidebar shade color',
    ['@success_color'] = 'Success status color',
    ['@success_bg_color'] = 'Success background color',
    ['@success_fg_color'] = 'Success foreground color',
    ['@view_bg_color'] = 'View background color (TextView, etc)',
    ['@view_fg_color'] = 'View foreground color',
    ['@warning_bg_color'] = 'Warning background color',
    ['@warning_color'] = 'Warning status color',
    ['@warning_fg_color'] = 'Warning foreground color',
    ['@window_bg_color'] = 'Window background color',
    ['@window_fg_color'] = 'Window foreground color',
}

local gtk_functions = {
    alpha = {
        documentation = 'Replaces alpha value of color. Range: 0 to 1',
        snippet = 'alpha(${1:color}, ${2:alpha})',
    },
    lighter = {
        documentation = 'Produces a brighter variant of the passed color',
        snippet = 'lighter($0)',
    },
    darker = {
        documentation = 'Produces a darker variant of the passed color',
        snippet = 'darker($0)',
    },
    shade = {
        documentation = 'Changes lightness of color. Range: 0 (black) to 2 (white)',
        snippet = 'shade(${1:color}, ${2:factor})',
    },
    mix = {
        documentation = 'Interpolates between two colors',
        snippet = 'mix(${1:color1}, ${2:color2}, ${3:factor})',
    },
    ['-gtk-recolor'] = {
        documentation = 'Recolors icon from URI with the selected palette',
        snippet = '-gtk-recolor(${1:url})',
    },
    ['-gtk-icontheme'] = {
        documentation = 'Looks up themed icon, respecting -gtk-icon-palette property',
        snippet = '-gtk-icontheme(${1:icon-name})',
    },
    ['-gtk-scaled'] = {
        documentation = 'Provides normal and hi-resolution image variants',
        snippet = '-gtk-scaled(${1:normal-url}, ${2:hidpi-url})',
    },
}

function M.setup_gtk_completions()
    local original_handler = vim.lsp.handlers['textDocument/completion']
    vim.lsp.handlers['textDocument/completion'] = function(err, result, ctx, config)
        if not result or vim.tbl_isempty(result) then
            return original_handler(err, result, ctx, config)
        end
        local bufname = vim.api.nvim_buf_get_name(ctx.bufnr)
        local is_gtk_css = bufname:match('%.gtk%.css$')
            or bufname:match('/gtk%-[34]/')
            or bufname:match('/themes/.-/gtk')
        if is_gtk_css then
            local items = result.items or result
            for prop_name, prop_data in pairs(gtk_properties) do
                table.insert(items, {
                    label = prop_name,
                    kind = vim.lsp.protocol.CompletionItemKind.Property,
                    documentation = {
                        kind = 'markdown',
                        value = prop_data.documentation,
                    },
                    insertText = prop_name .. ': ',
                    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
                    sortText = '0' .. prop_name,
                })
            end
            for color_var, color_docs in pairs(gtk_colors) do
                table.insert(items, {
                    label = color_var,
                    kind = vim.lsp.protocol.CompletionItemKind.Color,
                    documentation = {
                        kind = 'markdown',
                        value = color_docs,
                    },
                    insertText = color_var,
                    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
                    sortText = '1' .. color_var,
                })
            end
            for func_name, func_data in pairs(gtk_functions) do
                table.insert(items, {
                    label = func_name,
                    kind = vim.lsp.protocol.CompletionItemKind.Function,
                    documentation = {
                        kind = 'markdown',
                        value = func_data.documentation,
                    },
                    insertText = func_data.snippet,
                    insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
                    sortText = '2' .. func_name,
                })
            end
        end
        for selector_name, selector_data in pairs(gtk_selectors) do
            local insert_text = selector_name
            local insert_format = vim.lsp.protocol.InsertTextFormat.PlainText
            if selector_data.function_selector then
                insert_text = selector_data.snippet or (selector_name .. '($0)')
                insert_format = vim.lsp.protocol.InsertTextFormat.Snippet
            end
            table.insert(items, {
                label = ':' .. selector_name,
                kind = vim.lsp.protocol.CompletionItemKind.Keyword,
                documentation = {
                    kind = 'markdown',
                    value = selector_data.documentation,
                },
                insertText = ':' .. insert_text,
                insertTextFormat = insert_format,
                sortText = '3:' .. selector_name,
            })
        end
        return original_handler(err, result, ctx, config)
    end
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
    vim.api.nvim_create_autocmd('FileType', {
        pattern = merged.filetypes,
        callback = function()
            colorizer.attach_to_buffer(0)
        end,
    })
end

function M.css_config(opts)
    opts = opts or {}
    M.css_autocmds()
    M.css_colorizer(opts.colorizer)
    M.setup_gtk_completions()
    return {
        setup = M.css_config,
        colorizer = M.css_colorizer,
        autocmds = M.css_autocmds,
        gtk_completions = M.setup_gtk_completions,
    }
end

return M
