-- /qompassai/Diver/lua/plugins/lang/nvim-lint.lua
-- Qompass AI Linter Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  'mfussenegger/nvim-lint',
  event = { 'VimEnter'  },
  config = function(lint)
    require('config.lang.lint').lint_cfg(lint)
  end,
}
