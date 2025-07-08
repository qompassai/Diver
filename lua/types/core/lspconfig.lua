-- /qompassai/Diver/lua/types/core/lspconfig.lua
-- Qompass AI LSPConfig Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta

---@alias LspCapabilities lsp.ClientCapabilities

---@class LspCompletion
---@field completionItem LspCompletionItem

---@class LspCompletionItem
---@field snippetSupport boolean?

---@class LspFoldingRange
---@field dynamicRegistration boolean?
---@field lineFoldingOnly boolean?
---@field snippetSupport boolean?

---@class LspFileOperations
---@field didRename boolean?
---@field willRename boolean?

---@class LspWorkspace
---@field fileOperations LspFileOperations

---@class LspTextDocument
---@field foldingRange LspFoldingRange
---@field completion LspCompletion

