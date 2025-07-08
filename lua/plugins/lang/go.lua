-- /qompassai/Diver/lua/plugins/lang/go.lua
-- Qompass AI Go Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    {
        'ray-x/go.nvim',
        ft = {'go', 'gomod'},
        config = function() require('go').setup({}) end,
        dependencies = {'ray-x/guihua.lua', 'ray-x/navigator.lua'}
    },
}
