-- ~/.config/nvim/lua/config/ui/md.lua
--------------------------------------
local M = {}
function M.md_conform(opts)
    local conform_ok, conform = pcall(require, 'conform')
    if not conform_ok then return opts end
    opts = opts or {}
    local default_opts = {
        formatters_by_ft = {markdown = {'prettierd', 'markdownlint'}},
        default_format_opts = {lsp_format = 'fallback', timeout_ms = 500},
        format_on_save = {lsp_format = 'fallback', timeout_ms = 500},
        log_level = vim.log.levels.ERROR,
        notify_on_error = true
    }
    local config = vim.tbl_deep_extend('force', default_opts, opts)
    conform.setup(config)
    return config
end
function M.md_none_ls_sources(opts)
    opts = opts or {}
    local markdown_filetypes = opts.markdown_filetypes or {'markdown', 'md'}
    local text_filetypes = opts.text_filetypes or {'markdown', 'md', 'txt'}
    local prettier_config = opts.prettier or {}
    local markdownlint_config = opts.markdownlint or {}
    local vale_config = opts.vale or {}
    local proselint_config = opts.proselint or {}
    local include_prettier = opts.include_prettier ~= false
    local include_markdownlint = opts.include_markdownlint ~= false
    local include_vale = opts.include_vale ~= false
    local include_proselint = opts.include_proselint ~= false
    local null_ls_ok, null_ls = pcall(require, 'null-ls')
    if not null_ls_ok then return {} end
    local b = null_ls.builtins
    local sources = {}
    if include_prettier then
        table.insert(sources,
                     b.formatting.prettierd.with(
                         vim.tbl_deep_extend('force', {
                filetypes = markdown_filetypes,
                prefer_local = 'node_modules/.bin'
            }, prettier_config)))
    end
    if include_markdownlint then
        table.insert(sources,
                     b.diagnostics.markdownlint
                         .with(vim.tbl_deep_extend('force', {
            ft = markdown_filetypes,
            extra_args = {
                '--config', vim.fn.expand('~/.config/markdownlint.json')
            }
        }, markdownlint_config)))
    end
    if include_vale then
        table.insert(sources,
                     b.diagnostics.vale.with(
                         vim.tbl_deep_extend('force', {
                ft = text_filetypes,
                extra_args = {
                    '--config', vim.fn.expand('~/.config/vale/.vale.ini')
                }
            }, vale_config)))
    end
    if include_proselint then
        table.insert(sources,
                     b.code_actions.proselint.with(
                         vim.tbl_deep_extend('force', {ft = text_filetypes},
                                             proselint_config)))
    end
    return sources
end
function M.md_lsp(on_attach, capabilities)
    local lspconfig = require('lspconfig')
    lspconfig.marksman.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        filetypes = {'markdown', 'md'}
    })
end
function M.md_pdf(opts)
    opts = opts or {}
    local pdf_opts = {
        pdf_engine = opts.pdf_engine or 'pandoc',
        pdf_engine_opts = opts.pdf_engine_opts or '--pdf-engine=xelatex',
        extra_opts = opts.extra_opts or
            '--variable=mainfont:Arial --variable=fontsize:12pt',
        output_path = opts.output_path or './',
        auto_open = opts.auto_open ~= false,
        pandoc_path = opts.pandoc_path or '/usr/bin/pandoc',
        theme = opts.theme or 'default',
        margins = opts.margins or '1in',
        toc = opts.toc ~= false,
        highlight = opts.highlight or 'tango'
    }
    local md_pdf_ok, md_pdf = pcall(require, 'md-pdf')
    if md_pdf_ok then md_pdf.setup(pdf_opts) end
    vim.api.nvim_create_autocmd('FileType', {
        pattern = {'markdown', 'md'},
        callback = function()
            vim.keymap.set('n', '<leader>mp', function()
                if md_pdf_ok then
                    require('md-pdf').convert_md_to_pdf()
                else
                    vim.cmd('MarkdownToPDF')
                end
            end, {buffer = true, desc = 'Convert Markdown to PDF'})
        end
    })
    return pdf_opts
end
function M.md_treesitter(opts)
    opts = opts or {}
    opts.sync_install = opts.sync_install or false
    opts.ignore_install = opts.ignore_install or {}
    opts.auto_install = opts.auto_install ~= false
    opts.modules = opts.modules or {}
    opts.ensure_installed = opts.ensure_installed or {}
    if type(opts.ensure_installed) == 'table' then
        vim.list_extend(opts.ensure_installed, {'markdown', 'markdown_inline'})
    end
    opts.highlight = opts.highlight or {}
    opts.highlight.enable = opts.highlight.enable ~= true
    opts.highlight.additional_vim_regex_highlighting = opts.highlight
                                                           .additional_vim_regex_highlighting or
                                                           {'markdown'}
    return opts
end
function M.md_mdpreview()
    vim.g.mkdp_auto_start = 0
    vim.g.mkdp_auto_close = 0
    vim.g.mkdp_refresh_slow = 0
    vim.g.mkdp_command_for_global = 0
    vim.g.mkdp_open_to_the_world = 0
    vim.g.mkdp_open_ip = '127.0.0.1'
    vim.g.mkdp_browser = ''
    vim.g.mkdp_page_title = '${name}'
    vim.g.mkdp_filetypes = {'markdown'}
    vim.g.mkdp_theme = 'dark'
    vim.g.mkdp_markdown_css = ''
    vim.g.vim_markdown_folding_disabled = 1
    vim.g.vim_markdown_math = 1
    vim.g.vim_markdown_frontmatter = 1
    vim.g.vim_markdown_toml_frontmatter = 1
    vim.g.vim_markdown_json_frontmatter = 1
    vim.g.vim_markdown_follow_anchor = 1
    vim.g.vim_markdown_anchorexpr =
        "v:lua.require'config.ui.md'.get_anchor(v:fname)"
end
function M.md_anchor(link, opts)
    opts = opts or {}
    local prefix = opts.prefix or '#'
    local separator = opts.separator or '-'
    local lowercase = opts.lowercase ~= false
    local result = link
    if lowercase then result = string.lower(result) end
    return "'" .. prefix .. "' . substitute(" ..
               (lowercase and 'tolower(link)' or 'link') .. ", ' ', '" ..
               separator .. "', 'g')"
end
function M.md_table_mode()
    vim.g.table_mode_corner = '|'
    vim.g.table_mode_separator = '|'
    vim.g.table_mode_always_active = 0
    vim.g.table_mode_syntax = 1
    vim.g.table_mode_update_time = 300
    vim.api.nvim_create_autocmd('FileType', {
        pattern = {'markdown', 'md'},
        callback = function() vim.cmd('TableModeEnable') end
    })
end
function M.md_latex_preview()
    local nabla_ok, nabla = pcall(require, 'nabla')
    if nabla_ok then
        vim.keymap.set('n', '<leader>mp', function() nabla.popup() end,
                       {desc = 'Preview LaTeX equations'})

        vim.keymap.set('n', '<leader>mt', function() nabla.toggle_virt() end,
                       {desc = 'Toggle LaTeX equations'})
    end
end
vim.api.nvim_create_autocmd('FileType', {
    pattern = {'markdown', 'md'},
    callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.conceallevel = 2
        vim.opt_local.concealcursor = 'nc'
        vim.opt_local.spell = true
        vim.opt_local.spelllang = 'en_us'
        vim.opt_local.textwidth = 80
        vim.keymap.set('n', '<leader>mp', ':MarkdownPreview<CR>',
                       {buffer = true, desc = 'Markdown Preview'})
        vim.keymap.set('n', '<leader>ms', ':MarkdownPreviewStop<CR>',
                       {buffer = true, desc = 'Stop Markdown Preview'})
        vim.keymap.set('n', '<leader>mt', ':TableModeToggle<CR>',
                       {buffer = true, desc = 'Toggle Table Mode'})
        vim.keymap.set('n', '<leader>mi', ':KittyScrollbackGenerateImage<CR>',
                       {buffer = true, desc = 'Generate image from code block'})
        vim.keymap.set('v', '<leader>mr', ':SnipRun<CR>',
                       {buffer = true, desc = 'Run selected code'})
    end
})
vim.api.nvim_create_user_command('MarkdownToPDF', function()
    local input_file = vim.fn.expand('%')
    local output_file = vim.fn.expand('%:r') .. '.pdf'
    vim.notify('Converting ' .. input_file .. ' to PDF...', vim.log.levels.INFO)

    local cmd =
        'pandoc -f markdown -t pdf ' .. '--pdf-engine=xelatex ' .. '-o ' ..
            output_file .. ' ' .. input_file
    vim.fn.jobstart(cmd, {
        on_exit = function(_, code)
            if code == 0 then
                vim.notify('Successfully converted to ' .. output_file,
                           vim.log.levels.INFO)
            else
                vim.notify('Failed to convert to PDF', vim.log.levels.ERROR)
            end
        end
    })
end, {})
local markdownlint_config = vim.fn.expand('~/.config/markdownlint.json')
if vim.fn.filereadable(markdownlint_config) == 0 then
    vim.fn.mkdir(vim.fn.expand('~/.config/nvim/utils'), 'p')
    local config = [[{
      "default": true,
      "line-length": false,
      "no-trailing-punctuation": false,
      "no-inline-html": false
    }]]
    vim.fn.writefile(vim.split(config, '\n'), markdownlint_config)
end
function M.md(opts)
    opts = opts or {}
    M.md_lsp(opts.on_attach, opts.capabilities)
    local null_ls_ok, null_ls = pcall(require, 'null-ls')
    if null_ls_ok then
        local sources = M.md_none_ls_sources(opts)
        if #sources > 0 then
            for _, source in ipairs(sources) do
                null_ls.register(source)
            end
        end
    end
    M.md_conform(opts)
    M.md_anchor(opts)
    M.md_none_ls_sources(opts)
    M.md_mdpreview()
    M.md_table_mode()
    M.md_treesitter(opts)
    M.md_latex_preview()
    M.md_pdf(opts)
end
return M
