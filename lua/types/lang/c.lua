#!/usr/bin/env lua
--- C language option types — type-checker dictionary (never runs).
---
--- Plain-language version: this file never runs -- Neovim never loads it at startup. It is a dictionary of shapes
--- (type annotations) for the lua-language-server type checker, so the editor can offer completions and catch
--- mistakes while you edit. Think of it as the answer key the teacher uses, not a lesson.
---@module 'types.lang.c'
-- /qompassai/Diver/lua/types/lang/c.lua
-- Qompass AI - C Lang Type Definitions
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@class                    Clangd.Position
---@field character                                        integer
---@field line                                             integer
---@class Clangd.Range
---@field end                                              Clangd.Position
---@field start                                            Clangd.Position
---@class                    Clangd.ASTNode
---@field children?                                        Clangd.ASTNode[] Optional child nodes
---@field detail?                                          string Optional detail information
---@field kind                                             string Node kind (e.g., "BinaryOperator")
---@field range?                                           Clangd.Range Optional source range
---@field role                                             string Node role (e.g., "expression", "statement")

---@class Clangd.TextDocumentIdentifier
---@field uri                                              string Document URI

---@class Clangd.ASTParams
---@field range                                            Clangd.Range Range to analyze
---@field textDocument                                     Clangd.TextDocumentIdentifier Document to analyze

---@class ClangdExt.NodePosition
---@field end                                              integer[] [line, character]
---@field start                                            integer[] [line, character]

---@class ClangdExt.DetailPosition
---@field end                                              integer End character offset
---@field start                                            integer Start character offset

---@class ClangdExt.ASTConfig
---@field highlights                                       table<string, string> Highlight groups
---@field kind_icons                                       table<string, string> Icons for node kinds
---@field role_icons                                       table<string, string> Icons for node roles

---@class ClangdExt.AST
---@field clear_highlight                                  fun(source_buf: integer) Clear highlights
---@field detail_pos                                       table<integer, table<integer, ClangdExt.DetailPosition>>
---@field display_ast                                      fun(line1: integer, line2: integer) Display AST for range
---@field node_pos table<integer, table<integer, table<integer, ClangdExt.NodePosition>>> Source->AST->Line mapping
---@field nsid                                             integer Namespace ID
---@field update_highlight                                 fun(source_buf: integer, ast_buf: integer) Update highlights

---@class ClangdExt.Utils
---@field buf_request_method fun(method: string, params: table, handler: function, bufnr: integer) Request LSP method
---@field validate                                         fun(args: table) Validate arguments

---@class ClangdExt.Config
---@field ast                                              ClangdExt.ASTConfig AST configuration
---@field options                                          table Plugin options
