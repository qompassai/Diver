-- /qompassai/Diver/lsp/clojure_ls.lua
-- Qompass AI Clojure LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References: https://github.com/clojure-lsp/clojure-lsp
-- nix run github:clojure-lsp/clojure-lsp
vim.lsp.config['clojure_ls'] = {
  cmd = {
    'clojure-lsp'
  },
  filetypes = {
    'clojure',
    'edn'
  },
  root_markers = {
    'project.clj',
    'deps.edn',
    'build.boot',
    'shadow-cljs.edn',
    '.git',
    'bb.edn'
  },
}