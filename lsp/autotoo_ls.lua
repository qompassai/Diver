-- /qompassai/Diver/lsp/autotools.lua
-- Qompass AI Diver AutoTools LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'autotools-language-server',
    },
    filetypes = {
        'automake',
        'config',
        'make',
    },
    root_markers = {
        'configure.ac',
        'Makefile',
        'Makefile.am',
        '*.mk',
    },
    settings = {
      make = {
        command = {
          'make-language-server'
        },
        filetypes = 'make'
      }
    },
}