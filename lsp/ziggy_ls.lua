-- /qompassai/Diver/lsp/ziggy.lua
-- Qompass AI Ziggy LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local parser_config = require("nvim-treesitter.parsers").get_parser_configs() ---@class parser_config
parser_config.ziggy = {
  install_info = {
    url = 'https://github.com/kristoff-it/ziggy',
    files = {
      'tree-sitter-ziggy-schema/src/parser.c'
    },
    branch = 'main',
    generate_requires_npm = true,
    requires_generate_from_grammar = true,
  },
}
---@type vim.lsp.Config
return {
      cmd = { ---@type string[]
        'ziggy',
        'lsp',
      },
      filetypes = { ---@type string[]
        'ziggy',
      },
      root_markers = { ---@type string[]
        '.git',
      },
    },
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('ziggy', {}),
      pattern = 'ziggy',
      callback = function()
        vim.lsp.start({
          name = 'Ziggy LSP',
          cmd = {
            'ziggy',
            'lsp'
          },
          root_dir = vim.loop.cwd(),
        })
      end,
    })