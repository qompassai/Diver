-- /qompassai/Diver/lsp/autohotkey_ls.lua
-- Qompass AI Autohotkey LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'autohotkey_lsp',
    '--stdio',
  },
  filetypes = {
    'autohotkey',
  },
  root_markers = {
    'package.json',
  },
  ---@diagnostic disable-next-line: missing-fields
  flags = {
    debounce_text_changes = 500,
  },
  init_options = {
    locale = 'en-us',
    AutoLibInclude = 'All',
    CommentTags = '^;;\\s*(?<tag>.+)',
    CompleteFunctionParens = false,
    SymbolFoldinFromOpenBrace = false,
    Diagnostics = {
      ClassStaticMemberCheck = true,
      ParamsCheck = true,
    },
    ActionWhenV1IsDetected = 'Continue',
    FormatOptions = {
      array_style = 'expand',
      break_chained_methods = false,
      ignore_comment = false,
      indent_string = '\t',
      max_preserve_newlines = 2,
      brace_style = 'One True Brace',
      object_style = 'none',
      preserve_newlines = true,
      space_after_double_colon = true,
      space_before_conditional = true,
      space_in_empty_paren = false,
      space_in_other = true,
      space_in_paren = false,
      wrap_line_length = 0,
    },
  },
}