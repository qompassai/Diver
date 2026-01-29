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

return M