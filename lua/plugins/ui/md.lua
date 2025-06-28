-- /qompassai/Diver/lua/plugins/ui/md.lua
-- Qompass AI Markdown Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    {
        'arminveres/md-pdf.nvim',
        ft = 'markdown',
        dependencies = {'3rd/diagram.nvim'},
        keys = {
            {
                '<leader>,',
                function() require('md-pdf').convert_md_to_pdf() end,
                desc = 'Convert Markdown to PDF'
            }
        },
        opts = {
            pdf_engine = 'pandoc',
            pdf_engine_opts = '--pdf-engine=xelatex',
            extra_opts = '--variable=mainfont:Arial --variable=fontsize:12pt',
            output_path = './',
            auto_open = true,
            pandoc_path = '/usr/bin/pandoc',
            theme = 'default',
            margins = '1in',
            toc = true,
            highlight = 'tango'
        }
    }, {
        'iamcco/markdown-preview.nvim',
        cmd = {
            'MarkdownPreview', 'MarkdownPreviewToggle', 'MarkdownPreviewStop'
        },
        ft = {'markdown'},
        build = ':call mkdp#util#install()',
        init = function() vim.g.mkdp_filetypes = {'markdown'} end
    }, {'brianhuster/live-preview.nvim', dependencies = {'ibhagwan/fzf-lua'}},
    {'chomosuke/typst-preview.nvim', version = '1.*', opts = {}}, {
        '3rd/diagram.nvim',
        ft = {'markdown', 'norg'},
        dependencies = {'3rd/image.nvim'},
        opts = {
            events = {
                render_buffer = {'BufWritePost'},
                clear_buffer = {'BufLeave'}
            },
            integrations = {'markdown', 'neorg'},
            renderer_options = {
                mermaid = {
                    background = 'transparent',
                    theme = 'dark',
                    scale = 1
                },
                plantuml = {charset = 'utf-8'},
                d2 = {
                    theme_id = 'neutral',
                    dark_theme_id = 'dark',
                    scale = 1.0,
                    layout = 'dagre',
                    sketch = true
                }
            },
            auto_render = true,
            open_app = false,
            rocks = {hererocks = true, enabled = true}
        },
        config = function(_, opts)
            local integrations = {}
            for _, integration in ipairs(opts.integrations) do
                table.insert(integrations,
                             require('diagram.integrations.' .. integration))
            end
            opts.integrations = integrations
            require('diagram').setup(opts)
            vim.api.nvim_create_user_command('DiagramRender', function()
                require('diagram').render_buffer()
            end, {})
        end
    }, {
        '3rd/image.nvim',
        build = false,
        ft = {'markdown', 'norg', 'typst', 'html', 'css'},
        opts = {
            backend = 'kitty',
            processor = 'magick_cli',
            integrations = {
                markdown = {
                    enabled = true,
                    clear_in_insert_mode = true,
                    download_remote_images = true,
                    only_render_image_at_cursor = false,
                    only_render_image_at_cursor_mode = 'popup',
                    floating_windows = true,
                    filetypes = {'markdown', 'vimwiki'}
                },
                neorg = {enabled = true, filetypes = {'norg'}},
                typst = {enabled = true, filetypes = {'typst'}},
                html = {enabled = true},
                css = {enabled = true}
            },
            max_width = nil,
            max_height = nil,
            max_width_window_percentage = nil,
            max_height_window_percentage = 50,
            window_overlap_clear_enabled = false,
            window_overlap_clear_ft_ignore = {
                'cmp_menu', 'cmp_docs', 'snacks_notif', 'scrollview',
                'scrollview_sign'
            },
            editor_only_render_when_focused = false,
            tmux_show_only_in_active_window = false,
            hijack_file_patterns = {
                '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif'
            }
        }
    }, {
        'img-paste-devs/img-paste.vim',
        ft = {'markdown'},
        cmd = 'PasteImg',
        keys = {
            {
                '<C-a>',
                '<cmd>PasteImg<CR>',
                desc = 'Paste Image from Clipboard',
                ft = 'markdown'
            }
        },
        init = function()
            vim.g.mdip_imgdir = 'images'
            vim.g.mdip_imgname = 'image'
        end
    }
}
