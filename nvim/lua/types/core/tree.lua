#!/usr/bin/env lua5.1
-- /qompassai/diver/lua/types/core/tree.lua
-- Qompass AI Diver Treesitter Core Types
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
---@class TSNode
---@field type                                             fun(self: TSNode): string
---@field named fun(self: TSNode): boolean
---@field id fun(self: TSNode): string|integer
---@field parent fun(self: TSNode): TSNode|nil
---@field child_count fun(self: TSNode): integer
---@field child fun(self: TSNode, index: integer): TSNode|nil
---@field named_child_count fun(self: TSNode): integer
---@field named_child fun(self: TSNode, index: integer): TSNode|nil
---@field child_by_field_name fun(self: TSNode, field_name: string): TSNode|nil
---@field range fun(self: TSNode): integer, integer, integer, integer
---@field equal fun(self: TSNode, other: TSNode): boolean

---@class TSTree
---@field root fun(self: TSTree): TSNode
---@field copy fun(self: TSTree): TSTree
---@field included_ranges fun(self: TSTree): table

---@class vim.treesitter.query.TSMetadata : table
---@field range integer[]|nil
---@field text string[]|nil

---@alias TSMetadata vim.treesitter.query.TSMetadata

---@class TSQuery
---@field iter_captures fun(
---  self: TSQuery,
---  node: TSNode,
---  source: integer|string,
---  start: integer|nil,
---  stop: integer|nil): fun(): integer, TSNode, TSMetadata
---@field iter_matches fun(
---  self: TSQuery,
---  node: TSNode,
---  source: integer|string,
---  start: integer|nil,
---  stop: integer|nil): fun(): integer, table, TSMetadata

---@class vim.treesitter.query
---@field parse fun(lang: string, query: string): TSQuery

---@class vim.treesitter.LanguageTree
---@field parse fun(self: vim.treesitter.LanguageTree, range: {integer: integer, integer: integer}|nil): TSTree[]
---@field root fun(self: vim.treesitter.LanguageTree): TSNode
---@field language_for_range fun(self: vim.treesitter.LanguageTree, range: {integer: integer, integer: integer}): vim.treesitter.LanguageTree

---@class vim.treesitter
---@field query vim.treesitter.query
---@field get_parser fun(
---  bufnr: integer|nil,
---  lang: string|nil,
---  opts: { error: boolean }|nil): vim.treesitter.LanguageTree
---@field get_node_text fun(node: TSNode, source: integer|string, opts: table|nil): string

---@class vim
---@field treesitter vim.treesitter

local vim = _G.vim
return vim
