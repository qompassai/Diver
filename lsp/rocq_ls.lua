--- vsrocqtop language-server config — starts the Rocq/Coq proof files tutor.
---
--- Plain-language version: a language server is a helper program that reads your code and tells Neovim about
--- errors, completions, and definitions -- like a tutor looking over your shoulder. This file is the introduction
--- card that tells Neovim how to start the `vsrocqtop` tutor whenever you open Rocq/Coq proof files. It only takes
--- effect if `vsrocqtop` is installed on your computer.
---@module 'lsp.rocq_ls'
-- /qompassai/Diver/lsp/rocq_ls.lua
-- Qompass AI VS Rocq Interactive Theorem Prover LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source https://github.com/rocq-prover/vsrocq
--  opam pin add vsrocq-language-server.2.3.4 \
--    https://github.com/rocq-prover/vsrocq/releases/download/v2.3.4/vsrocq-language-server-2.3.4.tar.gz
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
