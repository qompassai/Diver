-- /qompassai/Diver/lua/types/lang/cmp.lua
-- Qompass AI Diver CMP Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-------------------------------------------------------------------
---@meta

---@class cmp.mapping
---@field scroll_docs                             fun(delta: number)
---@field complete                                fun(delta: number)
---@field confirm fun(opts: { behavior: any, select: boolean })
---@class cmp.config
---@field sources fun(sources: any): any
---@class cmp.ConfirmBehavior
---@field Replace string
---@field Insert string
---@class cmp
---@field mapping cmp.mapping
---@field config cmp.config
---@field ConfirmBehavior cmp.ConfirmBehavior
---@field visible fun(): boolean
---@field select_next_item fun(delta: number)
---@field select_prev_item fun(delta:number)

---@alias vim.lsp.protocol.MarkupKind 'plaintext' | 'markdown'

---@class vim.lsp.protocol.CompletionItem
---@field label string
---@field kind? integer
---@field documentation? string | { kind: vim.lsp.protocol.MarkupKind, value: string }

---@class BlinkCmp
---@alias blink.cmp.CompletionDocumentationDrawOpts any
-- --- @alias blink.cmp.Mode 'cmdline' | 'cmdwin' | 'term' | 'default'

---@class blink.cmp.CompletionItem : vim.lsp.protocol.CompletionItem
--- @field score_offset? number
--- @field source_id string
--- @field source_name string
--- @field cursor_column number
--- @field client_id? number
--- @field client_name? string
--- @field kind_name? string
--- @field kind_icon? string
--- @field kind_hl? string
--- @field exact? boolean
--- @field score? number

return {
  CompletionItemKind = {
    'Text',
    'Method',
    'Function',
    'Constructor',
    'Field',
    'Variable',
    'Class',
    'Interface',
    'Module',
    'Property',
    'Unit',
    'Value',
    'Enum',
    'Keyword',
    'Snippet',
    'Color',
    'File',
    'Reference',
    'Folder',
    'EnumMember',
    'Constant',
    'Struct',
    'Event',
    'Operator',
    'TypeParameter',

    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
    Unit = 11,
    Value = 12,
    Enum = 13,
    Keyword = 14,
    Snippet = 15,
    Color = 16,
    File = 17,
    Reference = 18,
    Folder = 19,
    EnumMember = 20,
    Constant = 21,
    Struct = 22,
    Event = 23,
    Operator = 24,
    TypeParameter = 25,
  },
}