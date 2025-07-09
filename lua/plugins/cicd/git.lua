-- qompassai/Diver/lua/plugins/cicd/git.lua
-- Qompass AI Diver Git Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
  'kdheepak/lazygit.nvim',
  cmd = {
    'LazyGit', 'LazyGitConfig', 'LazyGitCurrentFile', 'LazyGitFilter',
    'LazyGitFilterCurrentFile'
  },
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = { { '<leader>lg', '<cmd>LazyGit<cr>', desc = 'LazyGit' } }
}
