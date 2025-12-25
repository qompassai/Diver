return {
    'jamessan/vim-gnupg',
    config = function()
        vim.g.GPGPreferSymmetric = 1
        vim.api.nvim_create_autocmd('User', {
            pattern = 'GnuPG',
            callback = function()
                vim.opt_local.textwidth = 72
            end,
        })
    end,
}
