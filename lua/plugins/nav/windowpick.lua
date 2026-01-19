-- /qompassai/Diver/lua/plugins/nav/windowpick.lua
-- Qompass AI WindowPick Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    's1n7ax/nvim-window-picker',
    version = '2.*',
    config = function()
        require('window-picker').setup({
            filter_rules = {
                include_current_win = true,
                autoselect_one = true,
                bo = {
                    filetype = {
                        'neo-tree',
                        'neo-tree-popup',
                        'notify',
                    },
                    buftype = {
                        'terminal',
                        'quickfix',
                    },
                },
            },
        })
    end,
}
