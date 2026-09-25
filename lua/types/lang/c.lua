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
---@field line                                             integer
---@field character                                        integer
---@class Clangd.Range
---@field start                                            Clangd.Position
---@field end                                              Clangd.Position
---@class                    Clangd.ASTNode
---@field role                                             string Node role (e.g., "expression", "statement")
---@field kind                                             string Node kind (e.g., "BinaryOperator")
---@field detail?                                          string Optional detail information
---@field range?                                           Clangd.Range Optional source range
---@field children?                                        Clangd.ASTNode[] Optional child nodes

---@class Clangd.TextDocumentIdentifier
---@field uri                                              string Document URI

---@class Clangd.ASTParams
---@field textDocument                                     Clangd.TextDocumentIdentifier Document to analyze
---@field range                                            Clangd.Range Range to analyze

---@class ClangdExt.NodePosition
---@field start                                            integer[] [line, character]
---@field end                                              integer[] [line, character]

---@class ClangdExt.DetailPosition
---@field start                                            integer Start character offset
---@field end                                              integer End character offset

---@class ClangdExt.ASTConfig
---@field kind_icons                                       table<string, string> Icons for node kinds
---@field role_icons                                       table<string, string> Icons for node roles
---@field highlights                                       table<string, string> Highlight groups

---@class ClangdExt.AST
---@field node_pos table<integer, table<integer, table<integer, ClangdExt.NodePosition>>> Source->AST->Line mapping
---@field detail_pos                                       table<integer, table<integer, ClangdExt.DetailPosition>>
---@field nsid                                             integer Namespace ID
---@field clear_highlight                                  fun(source_buf: integer) Clear highlights
---@field update_highlight                                 fun(source_buf: integer, ast_buf: integer) Update highlights
---@field display_ast                                      fun(line1: integer, line2: integer) Display AST for range

---@class ClangdExt.Utils
---@field validate                                         fun(args: table) Validate arguments
---@field buf_request_method fun(method: string, params: table, handler: function, bufnr: integer) Request LSP method

---@class ClangdExt.Config
---@field options                                          table Plugin options
---@field ast                                              ClangdExt.ASTConfig AST configuration
