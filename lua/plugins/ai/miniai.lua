-- /qompassai/Diver/lua/plugins/ai/miniai.lua
-- Qompass AI Diver MiniAI Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    'echasnovski/mini.ai',
    enabled = 'false',
    version = '*',
    opts = {
        n_lines = 500,
        custom_textobjects = {},
        search_method = 'cover_or_next'
    },
    config = function(_, opts) require('mini.ai').setup(opts) end
}
