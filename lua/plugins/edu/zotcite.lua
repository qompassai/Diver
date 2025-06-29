-- /qompassai/Diver/lua/plugins/edu/zotcite.lua
-- Qompass AI Diver Zotcite Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    'jalvesaq/zotcite',
    ft = {'markdown', 'text', 'latex', 'tex'},
    dependencies = {'nvim-treesitter/nvim-treesitter', 'ibhagwan/fzf-lua'},
    config = function()
        require('zotcite').setup({python_path = '/usr/bin/python3'})
    end
}
