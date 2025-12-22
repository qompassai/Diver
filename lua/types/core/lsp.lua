-- /qompassai/Diver/lua/types/lsp.lua
-- Qompass AI Diver Core LSP
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'types.core.lsp'
---@class                             vim.lsp.Config
---@field name?                       string
---@field settings?                   table
---@field init_options?               table
---@field capabilities?               lsp.ClientCapabilities|table
---@field single_file_support?        boolean
---@field autostart?                  boolean
----@field on_init?                   fun(client: vim.lsp.Client, init_result: lsp.InitializeResult|nil)
---@field on_attach?                  fun(client: vim.lsp.Client, bufnr: integer)
---@field on_exit?                    fun(code: integer, signal: integer, client_id: integer)
---@class                             BashShellcheckSeverityConfig
---@field error?                      string
---@field warning?                    string
---@field info?                       string
---@field style?                      string
---@class                             BashShellcheckConfig
---@field enable                      boolean
---@field executablePath              string
---@field severity                    BashShellcheckSeverityConfig
---@class                             BashCompletionConfig
---@field enabled                     boolean
---@field includeDirs                 string[]
---@class                             BashDiagnosticsConfig
---@field enabled                     boolean
---@class                             BashShfmtConfig
---@field binaryNextLine              boolean
---@field caseIndent                  boolean
---@field funcNextLine                     boolean
---@field ignoreEditorconfig               boolean
---@field indent                           integer
---@field keepPadding                      boolean
---@field languageDialect                  string
---@field path                             string
---@field simplifyCode                     boolean
---@field spaceRedirects                   boolean
---@class                                  BashIdeConfig
---@field backgroundAnalysisMaxFiles       integer
---@field globPattern                      string
---@field logLevel                         string
---@field maxNumberOfProblems              integer
---@field shellcheck                       BashShellcheckConfig
---@field completion                       BashCompletionConfig
---@field diagnostics                      BashDiagnosticsConfig
---@field shfmt                            BashShfmtConfig
---@field explainshellEndpoint             string|nil
---@class (exact)                          BashLspSettings
---@field bashIde                          BashIdeConfig
---@class BashLsConfig  :                  vim.lsp.Config
---@field cmd                              string[]
---@field filetypes                        string[]
---@field root_markers                     string[]
---@field settings                         BashLspSettings
---@class                                  ClangdInlayHintsParams
---@field textDocument                     lsp.TextDocumentIdentifier
---@class                                  ClangdInitOptions
---@field fallbackFlags                    string[]
---@class ClangdSwitchSourceHeaderParams : lsp.TextDocumentIdentifier
---@class                                  ClangdSymbolInfo
---@field name          string
---@field containerName string|nil
---@class ClangdTextDocumentCapabilities
---@field completion  { editsNearCursor: boolean }
---@field references  { container: boolean }
---@class ClangdClientCapabilities : lsp.ClientCapabilities
---@field textDocument ClangdTextDocumentCapabilities
---@field offsetEncoding string[]
---@class ClangdLsConfig : vim.lsp.Config
---@field cmd          string[]
---@field filetypes    string[]
---@field root_markers string[]
---@field init_options ClangdInitOptions
---@field capabilities ClangdClientCapabilities
---@class ClangdInitializeResult : lsp.InitializeResult
---@field offsetEncoding? string
---@class               HlOpts
---@field bg? string
---@field bold? boolean
---@field fg? string
---@field italic? boolean
---@field sp? string
---@field undercurl? boolean
---@field underline? boolean
---@class VimLspCodeLensModule
---@field clear fun(client_id?: integer, bufnr?: integer)
---@field display fun(lenses?: lsp.CodeLens[], bufnr: integer, client_id: integer)
---@field get fun(bufnr: integer): lsp.CodeLens[]
---@field on_codelens fun(err: lsp.ResponseError?, result: lsp.CodeLens[], ctx: lsp.HandlerContext)
---@field refresh fun(opts?: { bufnr?: integer })
---@field run fun()
---@field save fun(lenses?: lsp.CodeLens[], bufnr: integer, client_id: integer)
---@class VimLspCompletionEnableOpts
---@field autotrigger? boolean
---@field convert? fun(item: lsp.CompletionItem): table
---@field cmp? fun(a: table, b: table): boolean
---@class VimLspCompletionGetOpts
---@field ctx? lsp.CompletionContext
---@class VimLspCompletionModule
---@field enable fun(enable: boolean, client_id: integer, bufnr: integer, opts?: VimLspCompletionEnableOpts)
---@field get fun(opts?: VimLspCompletionGetOpts)
---@class VimLspModule
---@field codelens VimLspCodeLensModule
---@field completion VimLspCompletionModule
---@class VimExtendedLsp : VimLspModule
---@class VimExtendedAPI
---@field lsp VimExtendedLsp
---@class NvimApi
---@field nvim_set_hl fun(ns_id: integer, name: string, val: HlOpts)
---@lsp.mod.deprecated gui=strikethrough
---@lsp.typemod.function.async guifg=Pink
vim.api.nvim_set_hl(
  0,
  '@lsp.type.class.lua',
  {
    fg = '#f7768e',
    bold = true,
    underline = true,
  }
)
vim.api.nvim_set_hl(
  0,
  '@lsp.type.parameter.lua',
  {
    fg = '#e0af68',
    bold = true,
  }
)
vim.api.nvim_set_hl(
  0,
  '@lsp.type.property.lua',
  {
    fg = '#7aa2f7',
    bold = true,
  }
)
vim.api.nvim_set_hl(
  0,
  '@lsp.type.function.lua',
  {
    fg = '#9ece6a',
    bold = true,
  }
)
vim.api.nvim_set_hl(
  0,
  '@lsp.type.variable.lua',
  {
    fg = '#7df9ff',
    bold = true,
  }
)
vim.api.nvim_set_hl(
  0,
  'Comment',
  {
    italic = false,
  }
)
vim.api.nvim_set_hl(
  0,
  'markdownCode',
  {
    italic = true
  }
)
vim.api.nvim_set_hl(
  0,
  'markdownCodeBlock',
  {
    italic = false,
  }
)
vim.api.nvim_set_hl(
  0,
  'markdownCodeDelimiter',
  {
    italic = true,
  }
)
vim.api.nvim_set_hl(
  0,
  'DiagnosticError',
  {
    fg = '#ff5f5f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticWarn',
  {
    fg = '#ffaf00'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticInfo',
  {
    fg = '#5fafff'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticHint',
  {
    fg = '#5fd7af'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticOk',
  {
    fg = '#5fd75f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticVirtualTextError',
  {
    fg = '#ff5f5f',
    bg = '#3b1f1f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticVirtualTextWarn',
  {
    fg = '#ffaf00',
    bg = '#3b2f1f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticVirtualTextInfo',
  {
    fg = '#5fafff',
    bg = '#1f2f3b'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticVirtualTextHint',
  {
    fg = '#5fd7af',
    bg = '#1f3b2f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticVirtualTextOk',
  {
    fg = '#5fd75f',
    bg = '#1f3b1f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticUnderlineError',
  {
    undercurl = true,
    sp = '#ff5f5f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticUnderlineWarn',
  {
    undercurl = true,
    sp = '#ffaf00'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticUnderlineInfo',
  {
    undercurl = true,
    sp = '#5fafff'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticUnderlineHint',
  {
    undercurl = true,
    sp = '#5fd7af'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticUnderlineOk',
  {
    undercurl = true,
    sp = '#5fd75f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticSignError',
  {
    fg = '#ff5f5f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticSignWarn',
  {
    fg = '#ffaf00'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticSignInfo',
  {
    fg = '#5fafff'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticSignHint',
  {
    fg = '#5fd7af'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticSignOk',
  {
    fg = '#5fd75f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticFloatingError',
  {
    fg = '#ff5f5f'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticFloatingWarn',
  {
    fg = '#ffaf00'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticFloatingInfo',
  {
    fg = '#5fafff'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticFloatingHint',
  {
    fg = '#5fd7af'
  })
vim.api.nvim_set_hl(
  0,
  'DiagnosticFloatingOk',
  {
    fg = '#5fd75f'
  })
vim.api.nvim_set_hl(
  0,
  'Normal',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'NormalFloat',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'FloatBorder',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'Pmenu',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'Terminal',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'EndOfBuffer',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'FoldColumn',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'Folded',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'SignColumn',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'NvimTreeNormal',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'NvimTreeVertSplit',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(0,
  'NvimTreeEndOfBuffer',
  {
    bg = 'none'
  })
vim.api.nvim_set_hl(
  0,
  'Search',
  {
    bg = '#8BCD5B',
    fg = '#202020'
  })

vim.api.nvim_set_hl(
  0, 'CurSearch',
  {
    bg = '#EFBD5D',
    fg = '#000000'
  })
vim.api.nvim_set_hl(
  0,
  'IncSearch',
  {
    bg = '#F15664',
    fg = '#000000'
  })
vim.api.nvim_set_hl(
  0,
  'CursorLine',
  {
    --  bg = '#1A1A1F'
  })
vim.api.nvim_set_hl(
  0,
  'CursorColumn',
  {
    --  bg = '#1A1A1F'
  })
vim.api.nvim_set_hl(
  0, 'Visual', {
    bg = '#103070'
  })