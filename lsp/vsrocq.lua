-- /qompassai/Diver/lsp/vsrocq.lua
-- Qompass AI VS Rocq Interactive Theorem Prover LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/rocq-prover/vsrocq
--  opam install vsrocq-language-server
vim.lsp.config['vsrocqtop'] = {
  cmd = {
    'vsrocqtop'
  },
  filetypes = {
    'coq'
  },
  root_markers = {
    '_CoqProject',
    '.git',
    '_RocqProject'
  },
}