-- /qompassai/Diver/lua/plugins/data/large.lua
-- Qompass AI Diver Large Data Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    'vim-scripts/LargeFile',
    config = function()
        vim.g.LargeFile = 100
    end,
}
