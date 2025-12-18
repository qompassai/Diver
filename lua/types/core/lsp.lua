-- /qompassai/Diver/lua/types/lsp.lua
-- Qompass AI Diver Core LSP
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta

---@class HlOpts
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
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  '@lsp.type.class.lua',
  {
    fg = '#f7768e',
    bold = true,
    underline = true,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  '@lsp.type.parameter.lua',
  {
    fg = '#e0af68',
    bold = true,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  '@lsp.type.property.lua',
  {
    fg = '#7aa2f7',
    bold = true,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  '@lsp.type.function.lua',
  {
    fg = '#9ece6a',
    bold = true,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  '@lsp.type.variable.lua',
  {
    fg = '#7df9ff',
    bold = true,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  'Comment',
  {
    italic = false,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  'markdownCode',
  {
    italic = false,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  'markdownCodeBlock',
  {
    italic = false,
  }
)
vim.api.nvim_set_hl( ---@type HlOpts
  0,
  'markdownCodeDelimiter',
  {
    italic = false,
  }
)
vim.api.nvim_set_hl(
  0,
  'DiagnosticError', {
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
vim.api.nvim_set_hl(0,
  'DiagnosticOk', { fg = '#5fd75f' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError',
  { fg = '#ff5f5f', bg = '#3b1f1f' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextWarn',
  {
    fg = '#ffaf00', bg = '#3b2f1f'
  })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo',
  {
    fg = '#5fafff', bg = '#1f2f3b'
  })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextHint', { fg = '#5fd7af', bg = '#1f3b2f' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextOk', { fg = '#5fd75f', bg = '#1f3b1f' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { undercurl = true, sp = '#ff5f5f' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { undercurl = true, sp = '#ffaf00' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { undercurl = true, sp = '#5fafff' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { undercurl = true, sp = '#5fd7af' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineOk', { undercurl = true, sp = '#5fd75f' })
vim.api.nvim_set_hl(0, 'DiagnosticSignError', { fg = '#ff5f5f' })
vim.api.nvim_set_hl(0, 'DiagnosticSignWarn', { fg = '#ffaf00' })
vim.api.nvim_set_hl(0, 'DiagnosticSignInfo', { fg = '#5fafff' })
vim.api.nvim_set_hl(0, 'DiagnosticSignHint', { fg = '#5fd7af' })
vim.api.nvim_set_hl(0, 'DiagnosticSignOk', { fg = '#5fd75f' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingError', { fg = '#ff5f5f' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingWarn', { fg = '#ffaf00' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingInfo', { fg = '#5fafff' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingHint', { fg = '#5fd7af' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingOk', { fg = '#5fd75f' })