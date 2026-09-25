-- /qompassai/Diver/lua/config/ui/md.lua
-- Qompass AI Diver Markdown Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
local api = vim.api
function M.md_anchor(link, opts)
    opts = opts or {}
    local prefix = opts.prefix or '#'
    local separator = opts.separator or '-'
    local lowercase = opts.lowercase ~= false
    local result = link
    if lowercase then
        result = string.lower(result)
    end
    return prefix .. result:gsub(' ', separator)
end
function M.md_autocmds()
    api.nvim_create_autocmd('FileType', {
        pattern = {
            'markdown',
            'md',
        },
        callback = function()
            vim.g.mkdp_auto_start = 0
            vim.g.mkdp_auto_close = 0
            vim.g.mkdp_refresh_slow = 1
            vim.g.mkdp_port = ''
            vim.g.mkdp_command_for_global = 0
            vim.g.mkdp_open_to_the_world = 0
            vim.g.mkdp_open_ip = ''
            vim.g.mkdp_combine_preview = 1
            vim.g.mkdp_browser = ''
            vim.g.mkdp_echo_preview_url = 1
            vim.g.mkdp_page_title = '${name}'
            vim.g.mkdp_filetypes = {
                'markdown',
            }
        end,
    })
end
function M.md_diagram(opts)
    opts = opts or {}
    -- diagram.nvim requires image.nvim (its lua/diagram/hover.lua requires the
    -- 'image' module), which was removed. Detach from the missing module:
    -- degrade gracefully instead of erroring when it is unavailable.
    local ok, err = pcall(function()
        require('diagram').setup(
            {
                integrations = {
                    require('diagram.integrations.markdown'),
                    require('diagram.integrations.neorg'),
                },
                events = {
                    render_buffer = {
                        'InsertLeave',
                        'BufWinEnter',
                        'TextChanged',
                    },
                    clear_buffer = {
                        'BufLeave',
                    },
                },
                renderer_options = {
                    mermaid = {
                        background = nil,
                        height = 600,
                        theme = 'dark',
                        scale = 1,
                        width = 800,
                    },
                    plantuml = {
                        charset = 'utf-8',
                    },
                    d2 = {
                        theme_id = 'neutral',
                        dark_theme_id = 'dark',
                        scale = 1.0,
                        layout = 'dagre',
                        sketch = true,
                        gnuplot = {
                            size = nil,
                            font = nil,
                            theme = nil,
                        },
                    },
                },
            },
            api.nvim_create_user_command('DiagramRender', function()
                require('diagram').render_buffer()
            end, { desc = 'Render diagrams in current buffer' })
        )
    end)
    if not ok then
        vim.notify(
            'diagram.nvim is unavailable (it requires image.nvim, which was removed); diagram rendering disabled: '
                .. tostring(err),
            vim.log.levels.WARN
        )
    end
    return opts
end

---@class image.Options
function M.md_image(_opts)
    require('image').setup({
        backend = 'kitty',
        integrations = {
            markdown = {
                enabled = true,
                clear_in_insert_mode = true,
                download_remote_images = true,
                only_render_image_at_cursor = false,
                only_render_image_at_cursor_mode = 'popup',
                floating_windows = true,
                filetypes = {
                    'markdown',
                    'vimwiki',
                    'quarto',
                },
            },
            neorg = {
                enabled = false,
                clear_in_insert_mode = true,
                download_remote_images = true,
                only_render_image_at_cursor = false,
                filetypes = {
                    'norg',
                },
            },
            neotree = {
                clear_in_insert_mode = true,
                download_remote_images = true,
                enabled = true,
                only_render_image_at_cursor = false,
                only_render_image_at_cursor_mode = 'popup',
            },
            typst = {
                enabled = true,
                filetypes = {
                    'typst',
                },
            },
            html = {
                enabled = true,
                clear_in_insert_mode = true,
                download_remote_images = true,
                only_render_image_at_cursor = false,
                only_render_image_at_cursor_mode = 'popup',
                floating_windows = true,
                filetypes = {
                    'markdown',
                    'html',
                },
            },
            css = {
                enabled = true,
                clear_in_insert_mode = true,
                download_remote_images = false,
                only_render_image_at_cursor = false,
                only_render_image_at_cursor_mode = 'popup',
                floating_windows = true,
            },
        },
        kitty_method = 'normal',
        max_width = nil,
        max_height = nil,
        max_width_window_percentage = nil,
        max_height_window_percentage = 50,
        processor = 'magick_cli',
        window_overlap_clear_enabled = false,
        window_overlap_clear_ft_ignore = {
            'scrollview',
            'scrollview_sign',
        },
        editor_only_render_when_focused = false,
        tmux_show_only_in_active_window = false,
        hijack_file_patterns = {
            '*.png',
            '*.jpg',
            '*.jpeg',
            '*.gif',
            '*.webp',
            '*.avif',
        },
    })
end
function M.md_livepreview(opts)
    opts = vim.tbl_deep_extend('force', {
        port = 5500,
        browser = 'google-chrome-canary', ---@type string
        dynamic_root = true, ---@type boolean
        sync_scroll = true, ---@type boolean
        picker = 'fzf-lua',
    }, opts or {})
    local ok, _ = pcall(require, 'live-preview') ---@type boolean, any
    if not ok then
        vim.echo('live-preview.nvim not found', vim.log.levels.WARN)
        return
    end
    require('livepreview.config').set(opts)
end

function M.md_pdf(opts)
    opts = opts or {}
    require('md-pdf').setup({
        margins = opts.margins or '1.5cm',
        highlight = opts.highlight or 'tango',
        toc = opts.toc ~= false,
        preview_cmd = opts.preview_cmd, ---@type  string|string[]
        ignore_viewer_state = opts.ignore_viewer_state or false,
        fonts = opts.fonts or {
            main_font = 'Libertinus Serif',
            sans_font = 'DejaVuSans',
            mono_font = 'DaddyTimeMono Nerd Font',
            math_font = 'Libertinus Math',
        },
        pandoc_user_args = opts.pandoc_user_args, ---@type string[]
        pdf_engine = opts.pdf_engine or 'lualatex',
        output_path = opts.output_path or './',
    })
    return opts
end
function M.md_table_mode()
    api.nvim_create_autocmd('FileType', {
        pattern = {
            'markdown',
            'md',
        },
        callback = function()
            vim.cmd('TableModeEnable')
        end,
    })
end

function M.md_config(opts)
    opts = opts or {}
    M.md_anchor(opts)
    M.md_autocmds()
    M.md_image(opts)
    M.md_livepreview(opts)
    M.md_preview(opts)
    -- Native renderer (replaces render-markdown.nvim): extmarks +
    -- conceallevel only, no plugin. setup() is idempotent.
    require('config.markdown.render').setup(opts)
    M.md_pdf(opts)
    M.md_table_mode()
end

return M
