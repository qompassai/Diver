--/qompassai/Diver/ftdetect/git.lua
-- Qompass AI FTDetect Git Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.filetype.add({
    pattern = {
        ['^.*/gitconfig.*$'] = 'gitconfig',
        ['^.*/gitignore.*$'] = 'gitignore',
        ['^.*/gitcommit.*$'] = 'gitcommit',
    },
})
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = 'gitconfig*',
    callback = function(ev)
        vim.bo[ev.buf].filetype = 'gitconfig'
    end,
})
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = 'gitignore*',
    callback = function(ev)
        vim.bo[ev.buf].filetype = 'gitignore'
    end,
})
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = 'gitcommit*',
    callback = function(ev)
        vim.bo[ev.buf].filetype = 'gitcommit'
    end,
})
