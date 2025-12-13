-- /qompassai/Diver/lsp/crystalline.lua
-- Qompass AI Crystalline LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/elbywan/crystalline
vim.lsp.config['crystalline'] = {
    cmd = { 'crystalline' },
    filetypes = { 'crystal' },
    root_markers = { 'shard.yml', '.git' },
}
