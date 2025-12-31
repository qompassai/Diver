-- prolog_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'swipl',
    '-g',
    'use_module(library(lsp_server)).',
    '-g',
    'lsp_server:main',
    '-t',
    'halt',
    '--',
    'stdio',
  },
  filetypes = { 'prolog' },
  root_markers = { 'pack.pl' },
}