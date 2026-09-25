-- /qompassai/Diver/lua/plugins/ui/icons.lua
-- Qompass AI Icons Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local icons_cfg = require('config.ui.icons')
return {
    {
        'nvim-tree/nvim-web-devicons',
        opts = { color_icons = true, default = false },
        config = function(_, _opts)
            icons_cfg.icons_devicons()
        end,
    },
    {
        'yamatsum/nvim-nonicons',
        dependencies = { 'kyazdani42/nvim-web-devicons' },
        config = function(_, _opts)
            icons_cfg.icons_nonicons()
        end,
    },
}
