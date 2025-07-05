-- /qompassai/Diver/lua/plugins/cloud/remote.lua
-- Qompass AI Diver Fire Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
  'amitds1997/remote-nvim.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim',
    'ibhagwan/fzf-lua'
  },
  config = function()
    require('remote-nvim').setup({
      method = 'ssh',
      default_user = os.getenv('USER'),
      picker = 'telescope',
      ssh_config = vim.fn.expand('~/.ssh/config')
    })
  end,
  event = 'VeryLazy'
}
