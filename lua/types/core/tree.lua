#!/usr/bin/env lua

-- tree.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@class TSNode
local TSNode = {}
---@return string
function TSNode:type() end

---@return boolean
function TSNode:named() end

---@return integer
function TSNode:id() end

---@return TSNode|nil
function TSNode:parent() end

---@return integer
function TSNode:child_count() end

---@param index integer
---@return TSNode|nil
function TSNode:child(index) end

---@return integer
function TSNode:named_child_count() end

---@param index integer
---@return TSNode|nil
function TSNode:named_child(index) end

---@param field_name string
---@return TSNode|nil
function TSNode:child_by_field_name(field_name) end

---@return integer start_row, integer start_col, integer end_row, integer end_col
function TSNode:range() end

---@param other TSNode
---@return boolean
function TSNode:equal(other) end

----@param row integer
----@param col integer
---@return TSNode|nil
--function TSNode:descendant_for_range(row, col, end_row, end_col) end

----@param row integer
----@param col integer
---@return TSNode|nil
--function TSNode:named_descendant_for_range(row, col, end_row, end_col) end

---@class TSTree
local TSTree = {}

---@return TSNode
function TSTree:root() end

---@param node TSNode
function TSTree:edit(node) end

---@param old_tree TSTree
---@param input any
---@return TSTree
function TSTree:walk(old_tree, input) end

---@class TSParser
local TSParser = {}

---@param text string
---@return TSTree
function TSParser:parse_string(text) end

---@param bufnr integer
---@return TSTree
function TSParser:parse(bufnr) end

---@param lang string
function TSParser:set_language(lang) end

---@class TSQuery
local TSQuery = {}

---@param node TSNode
---@param bufnr integer|string
---@param start_row? integer
---@param end_row? integer
---@return fun(): integer, TSNode, vim.treesitter.query.TSMetadata
function TSQuery:iter_captures(node, bufnr, start_row, end_row) end

---@param node TSNode
---@param bufnr integer|string
---@param start_row? integer
---@param end_row? integer
---@return fun(): integer, TSNode[], vim.treesitter.query.TSMetadata
function TSQuery:iter_matches(node, bufnr, start_row, end_row) end

---@class vim.treesitter.LanguageTree
local LanguageTree = {}

---@return TSTree[]
function LanguageTree:parse() end

---@return TSNode
function LanguageTree:root() end

---@param lang string
---@return vim.treesitter.LanguageTree
function LanguageTree:child(lang) end

---@class vim.treesitter.query.TSMetadata: table
---@field range? integer[]
---@field text? string[]

---@class vim.treesitter
local treesitter = {}

---@param bufnr? integer
---@param lang? string
---@param opts? { root_lang?: string, injected?: boolean }
---@return vim.treesitter.LanguageTree
function treesitter.get_parser(bufnr, lang, opts) end

---@param node TSNode
---@param bufnr_or_text integer|string
---@return string
function treesitter.get_node_text(node, bufnr_or_text) end

---@param node TSNode
---@param source integer|string
---@param metadata? vim.treesitter.query.TSMetadata
---@return integer start_row, integer start_col, integer end_row, integer end_col, integer start_byte, integer end_byte
function treesitter.get_range(node, source, metadata) end

---@param lang string
---@param query string
---@return TSQuery
function treesitter.query.parse(lang, query) end

----@param lang string
----@return boolean
--function treesitter.language.require_language(lang, path) end
---@class vim
---@field treesitter vim.treesitter
local vim = {}

return vim
