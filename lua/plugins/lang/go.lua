-- /qompassai/Diver/lua/plugins/lang/go.lua
-- Qompass AI Go Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local go_cfg = require('config.lang.go')
return {
    {
        'ray-x/go.nvim',
        ft = {
            'go',
            'gomod',
        },
        config = function(_, opts)
            go_cfg = require(go_cfg)(opts)
        end,
        dependencies = {
            'ray-x/guihua.lua',
            'ray-x/navigator.lua',
        },
    },
}
