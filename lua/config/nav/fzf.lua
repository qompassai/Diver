-- /qompassai/Diver/lua/config/nav/fzf.lua
-- Qompass AI Diver Nav Fzf Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
M.options = {
    winopts = {
        height = 0.85,
        width = 0.85,
        preview = {
            layout = 'flex',
            default = 'bat',
            hidden = 'hidden',
            vertical = 'down:45%',
        },
        border = 'rounded',
        hls = {
            Normal = 'Normal',
            Border = 'FloatBorder',
        },
    },
    fzf_opts = {
        ['--layout'] = 'reverse-list',
        ['--info'] = 'inline',
    },
    keymap = {
        fzf = {
            ['ctrl-c'] = 'abort',
            ['ctrl-q'] = 'select-all+accept',
            ['ctrl-d'] = 'half-page-down',
            ['ctrl-u'] = 'half-page-up',
        },
    },
}
M.keymaps = {
    {
        '<leader>zf',
        '<cmd>FzfLua files<cr>',
        desc = 'Fzf Files',
    },
    {
        '<leader>zb',
        '<cmd>FzfLua buffers<cr>',
        desc = 'Fzf Buffers',
    },
    {
        '<leader>zs',
        '<cmd>FzfLua live_grep<cr>',
        desc = 'Fzf Search',
    },
    {
        '<leader>zh',
        '<cmd>FzfLua colorschemes<cr>',
        desc = 'Fzf Colorscheme',
    },
    {
        '<leader>zw',
        '<cmd>FzfLua grep_cword<cr>',
        desc = 'Fzf Current Word',
    },
    {
        '<leader>zh',
        '<cmd>FzfLua help_tags<cr>',
        desc = 'Fzf Help Tags',
    },
    {
        '<leader>zm',
        '<cmd>FzfLua marks<cr>',
        desc = 'Fzf Marks',
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
        '<leader>zWs',
        '<cmd>FzfLua lsp_live_workspace_symbols<cr>',
        desc = 'Fzf Workspace Symbols',
    },
    {
        '<leader>zgs',
        '<cmd>FzfLua git_status<cr>',
        desc = 'Fzf Git Status',
    },
    {
        '<leader>zgb',
        '<cmd>FzfLua git_branches<cr>',
        desc = 'Fzf Git Branches',
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
