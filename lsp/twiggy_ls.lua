-- /qompassai/Diver/lsp/twiggy_ls.lua
-- Qompass AI Twiggy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/moetelo/twiggy
--pnpm add -g twiggy-language-server
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'twiggy-language-server',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'twig',
  },
  root_markers = { ---@type string[]
    'composer.json',
    '.git',
  },
}