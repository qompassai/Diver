-- /qompassai/Diver/lua/types/lsp.lua
-- Qompass AI Diver Core LSP
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'types.core.lsp'
---@class                                            vim.lsp.Config
---@field additionalArgs?                            string[]
---@field args?                                      string[]
---@field autostart?                                 boolean
---@field backgroundAnalysisMaxFiles?                integer
---@field capabilities?                              lsp.ClientCapabilities|table
---@field caseIndent?                                boolean
---@field createBaconPreferencesFile?                boolean
---@field enable?                                    boolean
---@field enabled?                                   boolean|string[]
---@field executablePath?                            string
---@field explainshellEndpoint?                      string|nil
---@field fallbackFlags?                             string[]
---@field funcNextLine?                              boolean
---@field globPattern?                               string
---@field indent?                                    integer
---@field ignoreEditorconfig?                        boolean
---@field init_options?                              table[]
---@field keepPadding?                               boolean
---@field languageDialect?                           string
---@field logLevel?                                  string
---@field maxNumberOfProblems?                       integer
---@field name?                                      string
---@field offsetEncoding?                            string[]
---@field on_attach?                                 fun(client: vim.lsp.Client, bufnr: integer)
---@field onOpenAndSave?                             boolean
---@field path?                                      string|nil
---@field runBaconInBackground?                      boolean
---@field settings?                                  table[]
---@field single_file_support?                       boolean
---@field simplifyCode?                              boolean
---@field spaceRedirects?                            boolean
---@field synchronizeAllOpenFilesWaitMillis?         integer
---@field textDocument?                              lsp.TextDocumentIdentifier
---@field updateOnSave?                              boolean
---@field updateOnSaveWaitMillis?                    integer
---@field validateBaconPreferences?                  boolean
---@class vim.lsp.Config.Settings
---@field ltex.additionalRules.enablePickyRules?     boolean
---@field ltex.additionalRules.languageModel?        string
---@field ltex.additionalRules.motherTongue?         string
---@field basedpyright.analysis?                     vim.lsp.Config.BasedPyright.Analysis
---@field ltex.bibtex.fields?                        { [string]: boolean } ---object
---@field ltex.checkFrequency?                       'edit' | 'manual' | 'save'
---@field ltex.clearDiagnosticsWhenClosingFile?      boolean
---@field ltex.completionEnabled?                    boolean
---@field ltex.configurationTarget?                  { [string]: boolean } ---object
---@field ltex.diagnosticSeverity                   string | { [string]: boolean }
---@field ltex.java.maximumHeapSize?                 integer
---@field ltex.java.path?                            string
---@field ltex.languageToolOrg.username?             string
---@field ltex.latex.environments?                   { [string]: boolean } ---object
---@field ltex.ltex-ls.logLevel?                     'severe' | 'warning' | 'info' | 'config' | 'fine'| 'finer' | 'finest'
---@field ltex.ltex-ls.path?                         string
---@field ltex.markdown.nodes?                       { [string]: boolean } ---object
---@field basedpyright.python?                               { pythonPath: string }
---@field ltex.statusBarItem?                        boolean
---@field ltex.trace.server?                         'off' | 'messages' | 'verbose'
---@class                                            HlOpts
---@field bg?                                         string
---@field bold?                                       boolean
---@field fg?                                         string
---@field italic?                                     boolean
---@field sp?                                         string
---@field undercurl?                                  boolean
---@field underline?                                  boolean
---@class                                             vim.lsp.Config.CodeLensModule
---@field clear                                       fun(client_id?: integer, bufnr?: integer)
---@field display                                     fun(lenses?: lsp.CodeLens[], bufnr: integer, client_id: integer)
---@field get                                         fun(bufnr: integer): lsp.CodeLens[]
---@field on_codelens                           fun(err: lsp.ResponseError?, result: lsp.CodeLens[], ctx: lsp.HandlerContext)
---@field refresh                               fun(opts?: { bufnr?: integer })
---@field run                                   fun()
---@field save                                  fun(lenses?: lsp.CodeLens[], bufnr: integer, client_id: integer)
---@class                                       vim.lsp.Config.CompletionEnableOpts
---@field autotrigger?                          boolean
---@field cmp?                                  fun(a: table, b: table): boolean
---@field convert?                              fun(item: lsp.CompletionItem): table
---@class                                       vim.lsp.Config.CompletionGetOpts
---@field ctx?                                  lsp.CompletionContext
---@class vim.lsp.Config.CompletionModule
---@field enable                                 fun(enable: boolean, client_id: integer, bufnr: integer, opts?: vim.lsp.Config.CompletionEnableOpts)
---@field get?                                   fun(opts?: vim.lsp.Config.CompletionGetOpts)
---@class vim.lsp.Config.LspModule
---@field codelens?                              vim.lsp.Config.CodeLensModule
---@field completion?                            vim.lsp.Config.CompletionModule
---@class VimExtendedLsp :                       vim.lsp.Config.LspModule
---@class VimExtendedAPI
---@field lsp                                   VimExtendedLsp
---@class NvimApi
---@field nvim_set_hl                           fun(ns_id: integer, name: string, val: HlOpts)
---@lsp.mod.deprecated                          gui=strikethrough
---@lsp.typemod.function.async                  guifg=Pink
---@class vim.lsp.Config.BasedPyright.Analysis
---@field basedpyright.autoFormatStrings?        boolean
---@field basedpyright.autoSearchPaths?                       boolean
---@field basedpyright.diagnosticMode?                        'openFilesOnly' | 'workspace'
---@field basedpyright.analysis.typeCheckingMode    BasedPyright.TypeCheckingMode
---@field useLibraryCodeForTypes                boolean
---@field inlayHints                            { variableTypes: boolean, callArgumentNames: boolean, callArgumentNamesMatching: boolean, functionReturnTypes: boolean, genericTypes: boolean }
---@field useTypingExtensions                   boolean
---@field fileEnumerationTimeout                integer
---@field basedpyright.analysis.stubPath?       string
---@field basedpyright.analysis.typeshedPaths   string[]
---@field diagnosticSeverityOverrides           table<string, string>
---@field failOnWarnings?                       boolean
---@field reportUnreachable?                    boolean|string
---@field reportAny?                            boolean|string
---@field reportIgnoreCommentWithoutRule?       boolean|string
---@field reportPrivateLocalImportUsage?        boolean|string
---@field reportImplicitRelativeImport?         boolean|string
---@field reportInvalidCast?                    boolean|string
---@field reportUnsafeMultipleInheritance?      boolean|string
---@field reportUnusedParameter?                boolean|string
---@field reportImplicitAbstractClass?          boolean|string
---@field reportUnannotatedClassAttribute?      boolean|string
---@alias BasedPyright.TypeCheckingMode
---| 'off'
---| 'basic'
---| 'standard'
---| 'strict'
---| 'recommended'
---| 'all'
---@class RaRunnableArgs
---@field cargoArgs                             string[]
---@field executableArgs?                       string[]
---@field cwd                                   string
---@class RaRunnable
---@field kind                                  string
---@field label                                 string
---@field args                                  RaRunnableArgs
vim.api.nvim_set_hl(0, '@lsp.type.class.lua', {
  fg = '#f7768e',
  bold = true,
  underline = true,
})
vim.api.nvim_set_hl(0, '@lsp.type.parameter.lua', {
  fg = '#e0af68',
  bold = true,
})
vim.api.nvim_set_hl(0, '@lsp.type.property.lua', {
  fg = '#7aa2f7',
  bold = true,
})
vim.api.nvim_set_hl(0, '@lsp.type.function.lua', {
  fg = '#9ece6a',
  bold = true,
})
vim.api.nvim_set_hl(0, '@lsp.type.variable.lua', {
  fg = '#7df9ff',
  bold = true,
})
vim.api.nvim_set_hl(0, 'Comment', {
  italic = true,
})
vim.api.nvim_set_hl(0, 'markdownCode', {
  italic = true,
})
vim.api.nvim_set_hl(0, 'markdownCodeBlock', {
  italic = false,
})
vim.api.nvim_set_hl(0, 'markdownCodeDelimiter', {
  italic = true,
})
vim.api.nvim_set_hl(0, 'DiagnosticError', {
  fg = '#ff5f5f',
})
vim.api.nvim_set_hl(0, 'DiagnosticWarn', {
  fg = '#ffaf00',
})
vim.api.nvim_set_hl(0, 'DiagnosticInfo', {
  fg = '#5fafff',
})
vim.api.nvim_set_hl(0, 'DiagnosticHint', {
  fg = '#5fd7af',
})
vim.api.nvim_set_hl(0, 'DiagnosticOk', {
  fg = '#5fd75f',
})
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError', {
  fg = '#ff5f5f',
  bg = '#3b1f1f',
})
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextWarn', {
  fg = '#ffaf00',
  bg = '#3b2f1f',
})
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', {
  fg = '#5fafff',
  bg = '#1f2f3b',
})
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextHint', {
  fg = '#5fd7af',
  bg = '#1f3b2f',
})
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextOk', {
  fg = '#5fd75f',
  bg = '#1f3b1f',
})
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', {
  undercurl = true,
  sp = '#ff5f5f',
})
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', {
  undercurl = true,
  sp = '#ffaf00',
})
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', {
  undercurl = true,
  sp = '#5fafff',
})
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', {
  undercurl = true,
  sp = '#5fd7af',
})
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineOk', {
  undercurl = true,
  sp = '#5fd75f',
})
vim.api.nvim_set_hl(0, 'DiagnosticSignError', {
  fg = '#ff5f5f',
})
vim.api.nvim_set_hl(0, 'DiagnosticSignWarn', {
  fg = '#ffaf00',
})
vim.api.nvim_set_hl(0, 'DiagnosticSignInfo', {
  fg = '#5fafff',
})
vim.api.nvim_set_hl(0, 'DiagnosticSignHint', {
  fg = '#5fd7af',
})
vim.api.nvim_set_hl(0, 'DiagnosticSignOk', {
  fg = '#5fd75f',
})
vim.api.nvim_set_hl(0, 'DiagnosticFloatingError', {
  fg = '#ff5f5f',
})
vim.api.nvim_set_hl(0, 'DiagnosticFloatingWarn', {
  fg = '#ffaf00',
})
vim.api.nvim_set_hl(0, 'DiagnosticFloatingInfo', {
  fg = '#5fafff',
})
vim.api.nvim_set_hl(0, 'DiagnosticFloatingHint', {
  fg = '#5fd7af',
})
vim.api.nvim_set_hl(0, 'DiagnosticFloatingOk', {
  fg = '#5fd75f',
})
vim.api.nvim_set_hl(0, 'Normal', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'NormalFloat', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'FloatBorder', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'Pmenu', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'Terminal', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'EndOfBuffer', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'FoldColumn', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'Folded', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'SignColumn', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'NvimTreeNormal', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'NvimTreeVertSplit', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'NvimTreeEndOfBuffer', {
  bg = 'none',
})
vim.api.nvim_set_hl(0, 'Search', {
  bg = '#8BCD5B',
  fg = '#202020',
})

vim.api.nvim_set_hl(0, 'CurSearch', {
  bg = '#EFBD5D',
  fg = '#000000',
})
vim.api.nvim_set_hl(0, 'IncSearch', {
  bg = '#F15664',
  fg = '#000000',
})
vim.api.nvim_set_hl(0, 'CursorLine', {
  --  bg = '#1A1A1F'
})
vim.api.nvim_set_hl(0, 'CursorColumn', {
  --  bg = '#1A1A1F'
})
vim.api.nvim_set_hl(0, 'Visual', {
  bg = '#103070',
})