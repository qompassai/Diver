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
        end, {})
    )
    return opts
end

---@class image.Options
function M.md_image(opts)
    opts = opts or {}
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
            'cmp_menu',
            'cmp_docs',
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

function M.md_rendermd(opts)
    opts = opts or {}
    require('render-markdown').setup({
        enabled = true,
        render_modes = { ---@type string[]
            'c',
            'n',
            't',
        },
        debounce = 100,
        max_file_size = 100.0,
        preset = 'none',
        log_level = nil,
        log_runtime = false,
        file_types = {
            'markdown',
        },
        ignore = function()
            return false
        end,
        change_events = {},
        injections = {
            gitcommit = {
                enabled = true,
                query = [[
          ((message) @injection.content
              (#set! injection.combined)
              (#set! injection.include-children)
              (#set! injection.language 'markdown'))
        ]],
            },
        },
        patterns = {
            markdown = {
                disable = false,
                directives = {
                    {
                        id = 17,
                        name = 'conceal_lines',
                    },
                    {
                        id = 18,
                        name = 'conceal_lines',
                    },
                },
            },
        },
        anti_conceal = {
            disabled_modes = true,
            enabled = true,
            above = 0,
            below = 0,
            ignore = {
                code_background = true,
                sign = true,
            },
        },
        padding = {
            highlight = 'Normal',
        },
        latex = {
            enabled = true,
            render_modes = true,
            converter = 'lualatex',
            highlight = 'RenderMarkdownMath',
            position = 'above',
            top_pad = 0,
            bottom_pad = 0,
        },
        on = {
            attach = function() end,
            initial = function() end,
            render = function() end,
            clear = function() end,
        },
        completions = {
            blink = {
                enabled = true,
            },
            coq = {
                enabled = true,
            },
            lsp = {
                enabled = false,
            },
            filter = {
                callout = function()
                    return true
                end,
                checkbox = function()
                    return true
                end,
            },
        },
        heading = { ---@type table[]
            enabled = false,
            render_modes = true,
            atx = true,
            setext = true,
            sign = true,
            icons = {
                '󰲡 ',
                '󰲣 ',
                '󰲥 ',
                '󰲧 ',
                '󰲩 ',
                '󰲫 ',
            },
            position = 'overlay',
            signs = { '󰫎 ' },
            width = 'full',
            left_margin = 0,
            left_pad = 0,
            right_pad = 0,
            min_width = 0,
            border = true,
            border_virtual = true,
            border_prefix = true,
            above = '▄',
            below = '▀',
            backgrounds = { ---@type string[]
                'RenderMarkdownH1Bg',
                'RenderMarkdownH2Bg',
                'RenderMarkdownH3Bg',
                'RenderMarkdownH4Bg',
                'RenderMarkdownH5Bg',
                'RenderMarkdownH6Bg',
            },
            foregrounds = { ---@type string[]
                'RenderMarkdownH1',
                'RenderMarkdownH2',
                'RenderMarkdownH3',
                'RenderMarkdownH4',
                'RenderMarkdownH5',
                'RenderMarkdownH6',
            },
            custom = {},
        },
        paragraph = {
            enabled = true,
            render_modes = true,
            left_margin = 0,
            indent = 0,
            min_width = 0,
        },
        code = { ---@type table[]
            enabled = true,
            render_modes = true,
            sign = true,
            style = 'full',
            position = 'left',
            language_pad = 0,
            language_icon = true,
            language_name = true,
            language_info = true,
            disable_background = {
                'diff',
            },
            width = 'full',
            left_margin = 0,
            left_pad = 0,
            right_pad = 0,
            min_width = 0,
            border = 'hide',
            language_border = '█',
            language_left = '',
            language_right = '',
            above = '▄',
            below = '▀',
            inline_left = '',
            inline_right = '',
            inline_pad = 0,
            highlight = 'RenderMarkdownCode',
            highlight_info = 'RenderMarkdownCodeInfo',
            highlight_language = nil,
            highlight_border = 'RenderMarkdownCodeBorder',
            highlight_fallback = 'RenderMarkdownCodeFallback',
            highlight_inline = 'RenderMarkdownCodeInline',
        },
        dash = {
            enabled = true,
            render_modes = true,
            icon = '─',
            width = 'full',
            left_margin = 0,
            highlight = 'RenderMarkdownDash',
        },
        document = {
            enabled = true,
            render_modes = true,
            conceal = {
                char_patterns = {},
                line_patterns = {},
            },
        },
        bullet = { ---@type table[]
            enabled = true,
            render_modes = true,
            icons = {
                '●',
                '○',
                '◆',
                '◇',
            },
            ordered_icons = function(ctx)
                local value = vim.trim(ctx.value)
                local index = tonumber(value:sub(1, #value - 1))
                return ('%d.'):format(index > 1 and index or ctx.index)
            end,
            left_pad = 0,
            right_pad = 0,
            highlight = 'RenderMarkdownBullet',
            scope_highlight = {},
        },
        checkbox = {
            enabled = true,
            render_modes = true,
            bullet = true,
            right_pad = 1,
            unchecked = {
                icon = '󰄱 ',
                highlight = 'RenderMarkdownUnchecked',
                scope_highlight = nil,
            },
            checked = {
                icon = '󰱒 ',
                highlight = 'RenderMarkdownChecked',
                scope_highlight = nil,
            },
            custom = {
                todo = {
                    highlight = 'RenderMarkdownTodo',
                    raw = '[-]',
                    rendered = '󰥔 ',
                    scope_highlight = nil,
                },
            },
        },
        quote = {
            enabled = true,
            highlight = {
                'RenderMarkdownQuote1',
                'RenderMarkdownQuote2',
                'RenderMarkdownQuote3',
                'RenderMarkdownQuote4',
                'RenderMarkdownQuote5',
                'RenderMarkdownQuote6',
            },
            icon = '▋',
            render_modes = true,
            repeat_linebreak = true,
        },
        pipe_table = { ---@type table[]
            cell = 'trimmed',
            enabled = true,
            render_modes = true,
            preset = 'none',
            style = 'full',
            padding = 1,
            min_width = 0,
            border = {
                '┌',
                '┬',
                '┐',
                '├',
                '┼',
                '┤',
                '└',
                '┴',
                '┘',
                '│',
                '─',
            },
            border_virtual = true, ---@type boolean
            alignment_indicator = '━',
            filler = 'RenderMarkdownTableFill',
            head = 'RenderMarkdownTableHead',
            row = 'RenderMarkdownTableRow',
        },
        callout = { ---@type table[]
            note = {
                raw = '[!NOTE]',
                rendered = '󰋽 Note',
                highlight = 'RenderMarkdownInfo',
                category = 'github',
            },
            tip = {
                raw = '[!TIP]',
                rendered = '󰌶 Tip',
                highlight = 'RenderMarkdownSuccess',
                category = 'github',
            },
            important = {
                raw = '[!IMPORTANT]',
                rendered = '󰅾 Important',
                highlight = 'RenderMarkdownHint',
                category = 'github',
            },
            warning = {
                raw = '[!WARNING]',
                rendered = '󰀪 Warning',
                highlight = 'RenderMarkdownWarn',
                category = 'github',
            },
            caution = {
                raw = '[!CAUTION]',
                rendered = '󰳦 Caution',
                highlight = 'RenderMarkdownError',
                category = 'github',
            },
            abstract = {
                raw = '[!ABSTRACT]',
                rendered = '󰨸 Abstract',
                highlight = 'RenderMarkdownInfo',
                category = 'obsidian',
            },
            summary = {
                raw = '[!SUMMARY]',
                rendered = '󰨸 Summary',
                highlight = 'RenderMarkdownInfo',
                category = 'obsidian',
            },
            tldr = {
                raw = '[!TLDR]',
                rendered = '󰨸 Tldr',
                highlight = 'RenderMarkdownInfo',
                category = 'obsidian',
            },
            info = {
                raw = '[!INFO]',
                rendered = '󰋽 Info',
                highlight = 'RenderMarkdownInfo',
                category = 'obsidian',
            },
            todo = {
                raw = '[!TODO]',
                rendered = '󰗡 Todo',
                highlight = 'RenderMarkdownInfo',
                category = 'obsidian',
            },
            hint = {
                raw = '[!HINT]',
                rendered = '󰌶 Hint',
                highlight = 'RenderMarkdownSuccess',
                category = 'obsidian',
            },
            success = {
                raw = '[!SUCCESS]',
                rendered = '󰄬 Success',
                highlight = 'RenderMarkdownSuccess',
                category = 'obsidian',
            },
            check = {
                raw = '[!CHECK]',
                rendered = '󰄬 Check',
                highlight = 'RenderMarkdownSuccess',
                category = 'obsidian',
            },
            done = {
                raw = '[!DONE]',
                rendered = '󰄬 Done',
                highlight = 'RenderMarkdownSuccess',
                category = 'obsidian',
            },
            question = {
                raw = '[!QUESTION]',
                rendered = '󰘥 Question',
                highlight = 'RenderMarkdownWarn',
                category = 'obsidian',
            },
            help = {
                raw = '[!HELP]',
                rendered = '󰘥 Help',
                highlight = 'RenderMarkdownWarn',
                category = 'obsidian',
            },
            faq = {
                raw = '[!FAQ]',
                rendered = '󰘥 Faq',
                highlight = 'RenderMarkdownWarn',
                category = 'obsidian',
            },
            attention = {
                raw = '[!ATTENTION]',
                rendered = '󰀪 Attention',
                highlight = 'RenderMarkdownWarn',
                category = 'obsidian',
            },
            failure = {
                raw = '[!FAILURE]',
                rendered = '󰅖 Failure',
                highlight = 'RenderMarkdownError',
                category = 'obsidian',
            },
            fail = {
                raw = '[!FAIL]',
                rendered = '󰅖 Fail',
                highlight = 'RenderMarkdownError',
                category = 'obsidian',
            },
            missing = {
                raw = '[!MISSING]',
                rendered = '󰅖 Missing',
                highlight = 'RenderMarkdownError',
                category = 'obsidian',
            },
            danger = {
                raw = '[!DANGER]',
                rendered = '󱐌 Danger',
                highlight = 'RenderMarkdownError',
                category = 'obsidian',
            },
            error = {
                raw = '[!ERROR]',
                rendered = '󱐌 Error',
                highlight = 'RenderMarkdownError',
                category = 'obsidian',
            },
            bug = {
                raw = '[!BUG]',
                rendered = '󰨰 Bug',
                highlight = 'RenderMarkdownError',
                category = 'obsidian',
            },
            example = {
                raw = '[!EXAMPLE]',
                rendered = '󰉹 Example',
                highlight = 'RenderMarkdownHint',
                category = 'obsidian',
            },
            quote = {
                raw = '[!QUOTE]',
                rendered = '󱆨 Quote',
                highlight = 'RenderMarkdownQuote',
                category = 'obsidian',
            },
            cite = {
                raw = '[!CITE]',
                rendered = '󱆨 Cite',
                highlight = 'RenderMarkdownQuote',
                category = 'obsidian',
            },
        },
        link = {
            enabled = true,
            render_modes = true,
            footnote = {
                enabled = true,
                superscript = true,
                prefix = '',
                suffix = '',
            },
            image = '󰥶 ',
            email = '󰀓 ',
            hyperlink = '󰌹 ',
            highlight = 'RenderMarkdownLink',
            wiki = {
                icon = '󱗖 ',
                body = function()
                    return nil
                end,
                highlight = 'RenderMarkdownWikiLink',
            },
            custom = { ---@type table[]
                web = {
                    pattern = '^http',
                    icon = '󰖟 ',
                },
                discord = {
                    pattern = 'discord%.com',
                    icon = '󰙯 ',
                },
                github = {
                    pattern = 'github%.com',
                    icon = '󰊤 ',
                },
                gitlab = {
                    pattern = 'gitlab%.com',
                    icon = '󰮠 ',
                },
                google = {
                    pattern = 'google%.com',
                    icon = '󰊭 ',
                },
                neovim = {
                    pattern = 'neovim%.io',
                    icon = ' ',
                },
                reddit = {
                    pattern = 'reddit%.com',
                    icon = '󰑍 ',
                },
                stackoverflow = {
                    pattern = 'stackoverflow%.com',
                    icon = '󰓌 ',
                },
                wikipedia = {
                    pattern = 'wikipedia%.org',
                    icon = '󰖬 ',
                },
                youtube = {
                    pattern = 'youtube%.com',
                    icon = '󰗃 ',
                },
            },
        },
        sign = {
            enabled = true,
            highlight = 'RenderMarkdownSign',
        },
        inline_highlight = {
            enabled = true,
            render_modes = true,
            highlight = 'RenderMarkdownInlineHighlight',
        },
        indent = {
            enabled = true,
            render_modes = true,
            per_level = 2,
            skip_level = 1,
            skip_heading = true,
            icon = '▎',
            highlight = 'RenderMarkdownIndent',
        },
        html = {
            enabled = true,
            render_modes = true,
            comment = {
                conceal = false,
                text = nil,
                highlight = 'RenderMarkdownHtmlComment',
            },
            tag = {},
        },
        win_options = {
            conceallevel = {
                default = vim.o.conceallevel,
                rendered = 3,
            },
            concealcursor = {
                default = vim.o.concealcursor,
                rendered = '',
            },
        },
        overrides = {
            buflisted = {},
            buftype = {
                nofile = {
                    padding = {
                        highlight = 'NormalFloat',
                    },
                    render_modes = true,
                    sign = {
                        enabled = true,
                    },
                },
            },
            filetype = {},
        },
        custom_handlers = {},
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
    M.md_rendermd(opts)
    M.md_pdf(opts)
end

return M
