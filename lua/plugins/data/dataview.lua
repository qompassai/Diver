-- ~/.config/nvim/lua/plugins/data/dataviewer.lua
-- Qompass AI Diver Dataviewer Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    'vidocqh/data-viewer.nvim',
    enabled = true,
    opts = {},
    dependencies = {
        'nvim-lua/plenary.nvim',
        'chrisbra/csv.vim',
        'dhruvasagar/vim-table-mode',
        'kkharji/sqlite.lua',
        'hat0uma/csvview.nvim',
        config = function() require('csvview').setup() end
    }
}
