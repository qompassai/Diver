return {
    'nmac427/guess-indent.nvim',
    event = 'BufReadPre',
    config = function()
        require('guess-indent').setup({
            auto_cmd = true,
            override_editorconfig = false,
            filetype_exclude = {
                'netrw', 'tutor', 'help', 'dashboard', 'neo-tree', 'mason',
                'terminal', 'TelescopePrompt', 'nofile', 'lspinfo'
            }
        })
    end
}
