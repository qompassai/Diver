-- /qompassai/Diver/lsp/millet_ls.lua
-- Qompass AI Millet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/azdavis/millet
-- cargo install --git https://github.com/azdavis/millet millet-ls --bin millet-ls
-- cargo install --git https://github.com/azdavis/millet millet-cli --bin millet-cli
-- cargo install --git https://github.com/azdavis/millet xtask --bin xtask
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'millet',
    },
    filetypes = { ---@type string[]
        'sml',
    },
    root_markers = { ---@type string[]
        'millet.toml',
    },
}
