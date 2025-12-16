-- /qompassai/Diver/lsp/clojure_ls.lua
-- Qompass AI Clojure LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References: https://github.com/clojure-lsp/clojure-lsp
-- nix run github:clojure-lsp/clojure-lsp
---@type vim.lsp.Config
return {
  cmd = {
    'clojure-lsp',
  },
  filetypes = {
    'clojure',
    'edn',
  },
  root_markers = {
    'build.boot',
    'project.clj',
    'deps.edn',
    'shadow-cljs.edn',
    '.git',
    'bb.edn',
  },
}