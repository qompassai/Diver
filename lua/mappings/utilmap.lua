-- /qompassai/Diver/lua/mappings/utilmap.lua
-- Qompass AI Diver Utility Mappings Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@module 'mappings.utilmap'
local M = {}

local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
        silent = true,
        noremap = true,
        desc = desc,
    })
end

local function create_user_command(name, rhs, desc)
    vim.api.nvim_create_user_command(name, rhs, {
        desc = desc,
    })
end

local function setup_terminal_mappings()
    map('t', '<Esc>', [[<C-\><C-n>]], 'Exit terminal mode')
    map('t', '<C-h>', [[<C-\><C-n><C-w>h]], 'Terminal window left')
    map('t', '<C-j>', [[<C-\><C-n><C-w>j]], 'Terminal window down')
    map('t', '<C-k>', [[<C-\><C-n><C-w>k]], 'Terminal window up')
    map('t', '<C-l>', [[<C-\><C-n><C-w>l]], 'Terminal window right')

    vim.api.nvim_create_autocmd({
        'TermOpen',
        'BufEnter',
    }, {
        pattern = 'term://*',
        desc = 'Enter insert mode in terminal buffers',
        callback = function()
            vim.cmd('startinsert')
        end,
    })

    create_user_command('AudioTerm', function()
        vim.cmd('botright 12split | terminal')
    end, 'Open utility terminal split')

    map('n', '<leader>zt', '<cmd>AudioTerm<cr>', 'Audio terminal')
end

local function setup_quickfix_mappings()
    map('n', '<leader>zo', '<cmd>copen<cr>', 'Quickfix open')
    map('n', '<leader>zc', '<cmd>cclose<cr>', 'Quickfix close')
    map('n', '<leader>zn', '<cmd>cnext<cr>', 'Quickfix next')
    map('n', '<leader>zp', '<cmd>cprevious<cr>', 'Quickfix previous')
    map('n', '<leader>zN', '<cmd>cnewer<cr>', 'Quickfix newer list')
    map('n', '<leader>zP', '<cmd>colder<cr>', 'Quickfix older list')
end
local function setup_audio_commands()
    vim.opt.makeprg = 'make'
    create_user_command('AudioPreview', 'make preview', 'Build audio preview target')
    create_user_command('AudioFinal', 'make final', 'Build final audio target')
    create_user_command('AudioPlay', function()
        vim.cmd('botright 12split | terminal mpv audio/preview.wav')
    end, 'Play audio preview in terminal split')
    create_user_command('AudioRenderCsound', function()
        vim.cmd('botright 12split | terminal csound -o audio/csound_layer.wav csd/texture.csd')
    end, 'Render CSound layer')

    map('n', '<leader>xr', '<cmd>AudioRenderCsound<cr>', 'Audio render CSound')
    map('n', '<leader>xf', '<cmd>AudioFinal<cr>', 'Audio final')
    map('n', '<leader>xp', '<cmd>AudioPlay<cr>', 'Audio play')
    map('n', '<leader>xv', '<cmd>AudioPreview<cr>', 'Audio preview')
end
local ok, fzf = pcall(require, 'fzf-lua')
if ok then
    vim.keymap.set('n', '<leader>?', function()
        fzf.keymaps()
    end, { desc = 'Keymap cheatsheet (fzf-lua)', silent = true, noremap = true })
end
M.setup_utilmap = function()
    setup_terminal_mappings()
    setup_quickfix_mappings()
    setup_audio_commands()
end

return M