-- qompassai/Diver/lua/plugins/cicd/filetype.lua
-- Qompass AI Diver Filetype Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
    'nathom/filetype.nvim',
    optional = true,
    init = function()
      if not pcall(require, 'LazyVim') then
        require('config.cicd.shell').setup_sh_filetype_detection()
      end
    end
  }
