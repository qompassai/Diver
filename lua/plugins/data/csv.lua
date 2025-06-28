-- ~/.config/nvim/lua/plugins/data/csv.lua
-- Qompass AI Diver CSV Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    'cameron-wags/rainbow_csv.nvim',
    enabled = true,
    config = true,
    opts = {delim = ','},
    ft = {
        'csv', 'tsv', 'csv_semicolon', 'csv_whitespace', 'csv_pipe', 'rfc_csv',
        'rfc_semicolon'
    },
    cmd = {
        'RainbowDelim', 'RainbowDelimSimple', 'RainbowDelimQuoted',
        'RainbowMultiDelim'
    }
}
