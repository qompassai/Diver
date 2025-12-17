-- /qompassai/Diver/lsp/mint_ls.lua
-- Qompass AI Mint LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--https://www.mint-lang.com
-- git clone https://github.com/mint-lang/mint.gitt && cd mint && shards install && make && mv /bin/mint ~/.local/bin
return {
  cmd = {
    'mint',
    'ls',
  },
  filetypes = {
    'mint',
  },
  root_markers = {
    'mint.json',
    'mint.jsonc',
    '.git',
  },
}