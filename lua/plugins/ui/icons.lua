-- /qompassai/Diver/lua/plugins/ui/icons.lua
-- Qompass AI Icons Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    {
        'nvim-tree/nvim-web-devicons',
        config = function() require('config.ui.icons').setup_devicons() end
    }, {
        'yamatsum/nvim-nonicons',
        config = function() require('config.ui.icons').setup_nonicons() end
    }, {
        'zakissimo/smoji.nvim',
        dependencies = {'stevearc/dressing.nvim'},
        config = function() require('smoji').setup() end
    }
}
