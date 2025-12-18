-- /qompassai/Diver/lsp/rocq_ls.lua
-- Qompass AI VS Rocq Interactive Theorem Prover LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/rocq-prover/vsrocq
--  opam install vsrocq-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'vsrocqtop',
    },
    filetypes = { ---@type string[]
        'coq',
    },
    root_markers = { ---@type string[]
        '_CoqProject',
        '.git',
        '_RocqProject',
    },
}
