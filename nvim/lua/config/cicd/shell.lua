-- qompassai/Diver/lua/config/cicd/shell.lua
-- Qompass AI Diver CICD Shell Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.sh_filetype_detection()
  vim.filetype.add({
    extension = {
      sh = 'bash',
      bash = 'bash',
      zsh = 'zsh',
      fish = 'fish',
      nu = 'nu',
    },
    pattern = {
      ['.*.sh'] = 'bash',
      ['.*.bash'] = 'bash',
      ['.bash*'] = 'bash',
      ['.*.zsh'] = 'zsh',
      ['.zsh*'] = 'zsh',
      ['.*.fish'] = 'fish',
      ['.*.nu'] = 'nu',
    },
    filename = {
      ['.bashrc'] = 'bash',
      ['.zshrc'] = 'zsh',
      ['config.fish'] = 'fish',
    },
  })
end

return M