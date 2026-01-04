-- /qompassai/Diver/lua/plugins/data/csv.lua
-- Qompass AI Diver CSV Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
  'cameron-wags/rainbow_csv.nvim',
  filetypes = {
    'csv',
    'tsv',
    'csv_semicolon',
    'csv_whitespace',
    'csv_pipe',
    'rfc_csv',
    'rfc_semicolon',
  },
  config = true,
  opts = {
    delim = ',',
  },
  cmd = {
    'RainbowDelim',
    'RainbowDelimSimple',
    'RainbowDelimQuoted',
    'RainbowMultiDelim',
  },
}