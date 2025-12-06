-- /qompassai/Diver/lsp/fort_ls.lua
-- Qompass AI Fortran (fortls) LSP Speca
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------------
-- Reference:  https://fortls.fortran-lang.org/index.html
-- pip install fortls

vim.lsp.config['fort_ls'] = {
  cmd = {
    'fortls',
    '--notify_init',
    '--incremental_sync',
    '--hover_signature',
    '--hover_language=fortran90',
    '--use_signature_help',
    '--enable_code_actions',
    '--sort_keywords',
    '--nthreads', '8',
    '--recursion_limit', '2000',
    '--source_dirs', './**',
    '--incl_suffixes', '.h', '.FPP',
    '--excl_suffixes', '_tmp.f90', '_gen.f90',
    '--excl_paths', 'build/**', '.git/**', '.direnv/**',
    '--pp_suffixes', '.F90', '.F', '.F08', '.fpp', '.h',
    '--include_dirs', 'include', 'preprocessor', '/usr/local/include'
  },
  filetypes = {
    'fortran',
    'fortran_fixed',
    'fortran_free'
  },
  root_markers = {
    '.fortlsrc',
    '.fortls.json',
    '.fortls',
    '.git'
  },
  settings = {},
}