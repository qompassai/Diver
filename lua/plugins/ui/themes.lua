-- /qompassai/Diver/lua/plugins/ui/themes.lua
-- Qompass AI Diver Themes Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
  {
    'tribela/transparent.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = true
  }, {
  'vyfor/cord.nvim',
  priority = 1000,
  event = { 'VimEnter' },
  dependencies = {
    'catppuccin/nvim', 'folke/tokyonight.nvim', 'navarasu/onedark.nvim',
    'sainnhe/gruvbox-material', 'EdenEast/nightfox.nvim',
    'shaunsingh/nord.nvim', 'marko-cerovac/material.nvim',
    'Mofiqul/dracula.nvim', 'projekt0n/github-nvim-theme',
    'olimorris/onedarkpro.nvim'
  },
  config = function()
    local ok, themes = pcall(require, 'config.ui.themes')
    if not ok then
      vim.notify('Failed to load theme config: ' .. tostring(themes),
        vim.log.levels.ERROR)
      return
    end
    if not themes.apply_current_theme() then return end
    local setup_ok, cord = pcall(themes.setup_cord)
    if not setup_ok then
      vim.notify('Cord setup failed: ' .. tostring(cord),
        vim.log.levels.ERROR)
      return
    end
    themes.cord = cord
    themes.cord_initialized = true
    themes.update_cord_theme()
  end
}
}
