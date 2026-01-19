-- /qompassai/Diver/lsp/rocq_ls.lua
-- Qompass AI VS Rocq Interactive Theorem Prover LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://github.com/rocq-prover/vsrocq
--  opam pin add vsrocq-language-server.2.3.4  https://github.com/rocq-prover/vsrocq/releases/download/v2.3.4/vsrocq-language-server-2.3.4.tar.gz
return ---@type vim.lsp.Config
{
    cmd = {
        'vsrocqtop',
    },
    filetypes = {
        'coq',
    },
    root_markers = {
        '_CoqProject',
        '.git',
        '_RocqProject',
    },
    settings = {},
}