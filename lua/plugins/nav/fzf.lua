-- ~/.config/nvim/lua/plugins/fzf.lua
return {
    'ibhagwan/fzf-lua',
    lazy = false,
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
    cmd = 'FzfLua',
    keys = function()
        return require('config.nav.fzf').keymaps
    end,
    config = function()
        require('config.nav.fzf').fzf_setup()
    end,
}