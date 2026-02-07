-- /qompassai/Diver/lua/config/nav/fzf.lua
-- Qompass AI Diver Nav Fzf Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
M.keymaps = {
    builtin = {
        ['<M-Esc>'] = 'hide',
        ['<F1>'] = 'toggle-help',
        ['<F2>'] = 'toggle-fullscreen',
        ['<F3>'] = 'toggle-preview-wrap',
        ['<F4>'] = 'toggle-preview',
        ['<F5>'] = 'toggle-preview-cw',
        ['<F6>'] = 'toggle-preview-behavior',
        ['<F7>'] = 'toggle-preview-ts-ctx',
        ['<F8>'] = 'preview-ts-ctx-dec',
        ['<F9>'] = 'preview-ts-ctx-inc',
        ['<S-Left>'] = 'preview-reset',
        ['<S-down>'] = 'preview-page-down',
        ['<S-up>'] = 'preview-page-up',
        ['<M-S-down>'] = 'preview-down',
        ['<M-S-up>'] = 'preview-up',
    },
    {
        '<leader>zb',
        '<cmd>FzfLua buffers<cr>',
        desc = 'Fzf Buffers',
    },
    {
        '<leader>zc',
        '<cmd>FzfLua commands<cr>',
        desc = 'Fzf Commands',
    },
    {
        '<leader>zd',
        '<cmd>FzfLua lsp_document_symbols<cr>',
        desc = 'Fzf Document Symbols',
    },
    {
        '<leader>zf',
        '<cmd>FzfLua files<cr>',
        desc = 'Fzf Files',
    },
    {
        '<leader>zgb',
        '<cmd>FzfLua git_branches<cr>',
        desc = 'Fzf Git Branches',
    },
    {
        '<leader>zgs',
        '<cmd>FzfLua git_status<cr>',
        desc = 'Fzf Git Status',
    },
    {
        '<leader>zh',
        '<cmd>FzfLua help_tags<cr>',
        desc = 'Fzf Help Tags',
    },
    { '<leader>zH', '<cmd>FzfLua colorschemes<cr>', desc = 'Fzf Colorscheme' },
    { '<leader>zm', '<cmd>FzfLua marks<cr>', desc = 'Fzf Marks' },
    { '<leader>zs', '<cmd>FzfLua live_grep<cr>', desc = 'Fzf Search' },
    { '<leader>zWs', '<cmd>FzfLua lsp_live_workspace_symbols<cr>', desc = 'Fzf Workspace Symbols' },
    { '<leader>zw', '<cmd>FzfLua grep_cword<cr>', desc = 'Fzf Current Word' },
}
M.options = {
    actions = {},
    files = {
        previewer = 'bat',
        prompt = 'Files❯ ',
        cmd = 'rg --files',
        find_opts = [[-type f \! -path '*/.git/*']],
        rg_opts = [[--color=never --hidden --files -g "!.git"]],
        fd_opts = [[--color=never --hidden --type f --type l --exclude .git]],
        dir_opts = [[/s/b/a:-d]],
        cwd_prompt = true,
        cwd_prompt_shorten_len = 32,
        cwd_prompt_shorten_val = 1,
        toggle_ignore_flag = '--no-ignore',
        toggle_hidden_flag = '--hidden',
        toggle_follow_flag = '-L',
        hidden = true,
        follow = false,
        no_ignore = false,
        absolute_path = false,
        zoxide = {
            cmd = 'zoxide query --list --score',
            scope = 'global',
            git_root = true,
            formatter = 'path.dirname_first',
            fzf_opts = {
                ['--no-multi'] = true,
                ['--delimiter'] = '[\t]',
                ['--tabstop'] = '4',
                ['--tiebreak'] = 'end,index',
                ['--nth'] = '2..',
            },
        },
    },
    fzf_bin = 'sk',
    fzf_colors = {
        true,
        ['bg'] = {
            'bg',
            'Normal',
        },
        ['bg+'] = {
            'bg',
            {
                'CursorLine',
                'Normal',
            },
        },
        ['fg'] = {
            'fg',
            'CursorLine',
        },
        ['fg+'] = {
            'fg',
            'Normal',
            'underline',
        },
        ['gutter'] = '-1',
        ['header'] = {
            'fg',
            'Comment',
        },
        ['hl'] = { 'fg', 'Comment' },
        ['hl+'] = { 'fg', 'Statement' },
        ['info'] = { 'fg', 'PreProc' },
        ['marker'] = { 'fg', 'Keyword' },
        ['pointer'] = { 'fg', 'Exception' },
        ['prompt'] = { 'fg', 'Conditional' },
        ['spinner'] = { 'fg', 'Label' },
    },
    fzf_opts = {
        ['--algo'] = 'frizbee',
        ['--ansi'] = true,
        ['--border'] = 'none',
        ['--height'] = '100%',
        ['--highlight-line'] = true,
        ['--info'] = 'inline-right',
        ['--layout'] = 'reverse',
    },
    fzf_tmux_opts = {
        ['--margin'] = '0,0',
        ['-p'] = '80%,80%',
    },
    hls = {
        normal = 'Normal',
        preview_normal = 'Normal',
    },
    keymap = {
        fzf = {
            ['ctrl-c'] = 'abort',
            ['ctrl-d'] = 'half-page-down',
            ['ctrl-q'] = 'select-all+accept',
            ['ctrl-u'] = 'half-page-up',
        },
    },
    winopts = {
        border = 'rounded',
        height = 0.85,
        hls = {
            Border = 'FloatBorder',
            Normal = 'Normal',
        },
        preview = {
            default = 'bat',
            hidden = 'hidden',
            layout = 'flex',
            vertical = 'down:45%',
        },
        width = 0.85,
    },
}
function M.fzf_setup()
    local fzf = require('fzf-lua')
    fzf.setup(M.options)
    fzf.register_ui_select()
    vim.api.nvim_create_user_command('Projects', function()
        fzf.fzf_exec('find ~/projects -type d -maxdepth 2 | sort', {
            actions = {
                ['default'] = function(selected)
                    vim.cmd('cd ' .. selected[1])
                    require('fzf-lua').files()
                end,
            },
            prompt = 'Projects> ',
        })
    end, {})
end

local fn = vim.fn
---@param lines string[]
---@param sink fun(selection: string)
local function fzf_pick(lines, sink)
    if not lines or #lines == 0 then
        vim.notify('fzf: no entries', vim.log.levels.INFO)
        return
    end
    local fzf = 'fzf'
    local opts = {
        '--ansi',
        '--prompt=❯ ',
        '--reverse',
    }
    local stdin = table.concat(lines, '')
    local job_id
    job_id = fn.jobstart({ fzf, unpack(opts) }, {
        stdin = 'pipe',
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            if not data or not data[1] or data[1] == '' then
                return
            end
            sink(data[1])
        end,
        on_exit = function()
            if job_id then
                fn.jobstop(job_id)
            end
        end,
    })
    fn.chansend(job_id, stdin)
    fn.chanclose(job_id, 'stdin')
end

M.fzf_pick = fzf_pick
local function project_files()
    if fn.executable('fd') == 1 then
        return fn.systemlist({
            'fd',
            '--type',
            'f',
            '--strip-cwd-prefix',
        })
    else
        return fn.systemlist({
            'find',
            '.',
            '-type',
            'f',
        })
    end
end

function M.files()
    local lines = project_files()
    fzf_pick(lines, function(line)
        if not line or line == '' then
            return
        end
        vim.api.nvim_command('edit ' .. fn.fnameescape(line))
    end)
end

function M.buffers()
    local bufs = vim.api.nvim_list_bufs()
    local lines = {}
    for _, b in ipairs(bufs) do
        if vim.api.nvim_buf_is_loaded(b) and fn.buflisted(b) == 1 then
            local name = vim.api.nvim_buf_get_name(b)
            if name == '' then
                name = '[No Name]'
            end
            table.insert(lines, string.format('%d %s', b, name))
        end
    end
    fzf_pick(lines, function(line)
        local id = tonumber(line:match('^(%d+)'))
        if id ~= nil then ---@cast id integer
            vim.api.nvim_set_current_buf(id)
        end
    end)
end

function M.document_symbols()
    local params = vim.lsp.util.make_text_document_params()
    vim.lsp.buf_request(0, 'textDocument/documentSymbol', { textDocument = params }, function(err, result, ctx, _)
        if err or not result then
            vim.notify('LSP: no symbols', vim.log.levels.WARN)
            return
        end
        local items = vim.lsp.util.symbols_to_items(result, 0) or {}
        local lines = {}
        for _, it in ipairs(items) do
            local lnum = it.lnum + 1
            local text = it.text or ''
            local fname = it.filename or vim.api.nvim_buf_get_name(ctx.bufnr)
            fname = fname ~= '' and fname or '[Current]'
            table.insert(lines, string.format('%s:%d:%s', fname, lnum, text))
        end
        fzf_pick(lines, function(line)
            local file, lnum = line:match('^(.-):(%d+):')
            if file and lnum then
                vim.cmd('edit ' .. fn.fnameescape(file))
                local row = tonumber(lnum)
                if row ~= nil then
                    ---@cast row integer
                    vim.api.nvim_win_set_cursor(0, {
                        row,
                        0,
                    })
                end
            end
        end)
    end)
end

vim.opt.incsearch = true
vim.opt.hlsearch = true
function M.smart_hlsearch()
    local pattern = vim.fn.getreg('/')
    local enable = pattern ~= nil and pattern ~= ''
    if vim.v.hlsearch ~= (enable and 1 or 0) then
        vim.opt.hlsearch = enable
    end
end

function M.highlight_word_under_cursor()
    local word = vim.fn.expand('<cword>')
    if word == nil or word == '' then
        return
    end
    vim.cmd('keepjumps normal! m`')
    vim.fn.setreg('/', '\\V' .. vim.fn.escape(word, '\\'))
    M.smart_hlsearch()
end

function M.next_match()
    vim.cmd('keepjumps normal! n')
    M.smart_hlsearch()
end

function M.prev_match()
    vim.cmd('keepjumps normal! N')
    M.smart_hlsearch()
end

function M.substitute(cmd)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local old_search = vim.fn.getreg('/')
    vim.cmd('keepjumps ' .. cmd)
    vim.api.nvim_win_set_cursor(0, cursor)
    vim.fn.setreg('/', old_search)
    M.smart_hlsearch()
end

function M.setup_mappings()
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    map('n', '*', function()
        require('utils.search').highlight_word_under_cursor()
    end, opts)

    map('n', 'n', function()
        require('utils.search').next_match()
    end, opts)

    map('n', 'N', function()
        require('utils.search').prev_match()
    end, opts)

    map('n', '<leader>h', function()
        if vim.v.hlsearch == 1 then
            vim.opt.hlsearch = false
        else
            M.smart_hlsearch()
        end
    end, opts)
end

local group = vim.api.nvim_create_augroup('SmartSearchSetup', { clear = true })
vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
        local ok, search = pcall(require, 'utils.search')
        if ok then
            search.setup_mappings()
        end
    end,
})

return M