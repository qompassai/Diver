-- /qompassai/Diver/lua/plugins/ui/themes.lua
-- Qompass AI Diver Themes Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    {
        'tribela/transparent.nvim',
        event = 'VimEnter',
        config = true,
    },
    {
        'olimorris/onedarkpro.nvim',
        priority = 1000,
    },
    { 'catppuccin/nvim' },
    {
        'EdenEast/nightfox.nvim',
    },
    { 'folke/tokyonight.nvim' },
    { 'marko-cerovac/material.nvim' },
    { 'Mofiqul/dracula.nvim' },
    { 'navarasu/onedark.nvim' },
    { 'projekt0n/github-nvim-theme' },
    -- { 'sainnhe/gruvbox-material' },
    { 'shaunsingh/nord.nvim' },
    {
        'vyfor/cord.nvim',
        event = 'BufEnter',
        config = function(_, opts)
            require('config.ui.themes').cord_setup(opts)
        end,
    },
}