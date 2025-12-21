-- /qompassai/Diver/lua/config/core/tree.lua
-- Qompass AI Diver TreeSitter Config Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'config.core.tree'
local M = {}
function M.treesitter(opts) ---@param opts table<string, any>|nil
  opts = opts or {}
  require('nvim-treesitter.install').prefer_git = true
  local configs = require('nvim-treesitter.configs')
  local base_config = {
    auto_install = true,
    ensure_installed = { ---@type string[]
      'ada',
      'agda',
      'bash',
      'bibtex',
      'c',
      'cmake',
      'cpp',
      'css',
      'cuda',
      'dart',
      'dockerfile',
      'elixir',
      'erlang',
      'fsharp',
      'gleam',
      'go',
      'gomod',
      'graphql',
      'haskell',
      'hcl',
      'html',
      'ini',
      'java',
      'jsdoc',
      'json',
      'json5',
      'jsonc',
      'julia',
      'kotlin',
      'llvm',
      'lua',
      'luadoc',
      'latex',
      'make',
      'markdown',
      'markdown_inline',
      'meson',
      'nix',
      'objc',
      'objdump',
      'ocaml',
      'php',
      'proto',
      'python',
      'query',
      'regex',
      'ruby',
      'rust',
      'scala',
      'scss',
      'sql',
      'svelte',
      'swift',
      'terraform',
      'tmux',
      'toml',
      'tsx',
      'typescript',
      'vim',
      'vimdoc',
      'vue',
      'xml',
      'yaml',
      'zig'
    },
    highlight = { ---@type boolean[]
      enable = true,
      additional_vim_regex_highlighting = true,
    },
    ignore_install = {
      'ipkg',
      'norg'
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = 'gnn',
        node_decremental = 'grm',
        node_incremental = 'grn',
        scope_incremental = 'grc',
      },
    },
    indent = {
      enable = true,
    },
    sync_install = false,
    textobjects = {
      select = {
        enable = true,
        keymaps = {
          ['af'] = '@function.outer',
          ['if'] = '@function.inner',
        },
      },
    },
  }
  local final_config = vim.tbl_deep_extend('force',
    base_config, opts) ---@cast final_config TSConfig
  configs.setup(final_config)
end

function M.tree_cfg(opts)
  opts = opts or {}
  M.treesitter(opts)
  return {
    treesitter = vim.tbl_deep_extend(
      'force',
      M.options and M.options.treesitter or {},
      opts),
  }
end

vim.treesitter.query.set(
  'c',
  'highlights',
  [[;inherits c
  (identifier) @spell]]
)
return M