-- /qompassai/Diver/lsp/tsquery_ls.lua
-- Qompass AI TS Query LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@source  https://github.com/ribru17/ts_query_ls
vim.g.query_lint_on = {}
return ---@type vim.lsp.Config
{
  cmd = {
    'ts_query_ls',
  },
  filetypes = {
    'query',
  },
  root_markers = {
    '.git',
    '.tsqueryrc.json',
  },
  init_options = {
    parser_aliases = {
      c = 'c',
      ecma = 'javascript',
      js = 'javascript',
      jsx = 'javascript',
      php_only = 'php',
    },
    language_retrieval_patterns = {
      'languages/src/([^/]+)/[^/]+%.scm$',
    },
    diagnostic_options = {
      string_argument_style = 'prefer_quoted',
      warn_unused_underscore_captures = true,
    },
    formatting_options = {
      dot_prefix_predicates = false,
      valid_captures = {
        highlights = {
          variable = 'Simple identifiers',
          ['variable.parameter'] = 'Parameters of a function',
        },
      },
    },
    valid_predicates = {
      ['any-of'] = {
        parameters = {
          {
            type = 'capture',
            arity = 'required',
          },
          {
            type = 'string',
            arity = 'required',
          },
          {
            type = 'string',
            arity = 'variadic',
            constraint = 'integer',
          },
        },
        description = 'Checks for equality between multiple strings',
      },
    },
    valid_directives = {},
    supported_abi_versions = {
      start = 13,
      ['end'] = 15,
    },
    parser_install_directories = {
      -- vim.fn.stdpath('data') .. '/site/parser',
      vim.fs.joinpath(vim.fn.stdpath('data'), 'lazy', 'nvim-treesitter', 'parser'),
    },
  },
  on_attach = function(_, buf)
    vim.bo[buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
  end,
}