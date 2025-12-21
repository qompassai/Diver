-- /qompassai/Diver/lsp/jq_ls.lua
-- Qompass AI JQ LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference:  https://github.com/wader/jq-lsp
-- go install github.com/wader/jq-lsp@master
vim.cmd([[au BufRead,BufNewFile *.jq setfiletype jq]])
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'jq-lsp',
  },
  filetypes = { ---@type string[]
    'jq',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}