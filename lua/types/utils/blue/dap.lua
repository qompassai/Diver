#!/usr/bin/env lua5.1, JIT
--- Blueteam DAP helper types — type-checker dictionary (never runs).
---
--- Plain-language version: this file never runs -- Neovim never loads it at startup. It is a dictionary of shapes
--- (type annotations) for the lua-language-server type checker, so the editor can offer completions and catch
--- mistakes while you edit. Think of it as the answer key the teacher uses, not a lesson.
---@module 'types.utils.blue.dap'

-- dap.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta

---@alias dap.PresentationHintKind
---| 'property'
---| 'method'
---| 'class'
---| 'data'
---| 'event'
---| 'baseClass'
---| 'innerClass'
---| 'interface'
---| 'mostDerivedClass'
---| 'virtual'
---| 'dataBreakpoint'
---| string
---@alias dap.PresentationHintAttribute
---| 'static'
---| 'constant'
---| 'readOnly'
---| 'rawString'
---| 'hasObjectId'
---| 'canHaveObjectId'
---| 'hasSideEffects'
---| 'hasDataBreakpoint'
---| string
---@alias dap.Visibility
---| 'public'
---| 'private'
---| 'protected'
---| 'internal'
---| 'final'
---| string

---@class dap.Source
---@field checksums? dap.Checksum[]

---@class dap.Checksum
---@field algorithm string
---@field checksum string

---@class dap.StackFrame
---@field instructionPointerReference? string
---@field moduleId? integer|string

---@class dap.ExceptionDetails
---@field message? string
---@field typeName? string
---@field fullTypeName? string
---@field evaluateName? string
---@field stackTrace? string
---@field innerException? dap.ExceptionDetails[]

---@class dap.ExceptionInfoResponse
---@field exceptionId? string
---@field breakMode? string
---@field description? string
---@field details? dap.ExceptionDetails

---@class dap.Session
---@field _request_scopes fun(self: dap.Session, frame: dap.StackFrame)

---@class dap.ListenerTable
---@field event_terminated table<string, fun(...)>
---@field event_exited table<string, fun(...)>
---@field event_continued table<string, fun(...)>
---@field continue table<string, fun(...)>
---@field event_stopped table<string, fun(session: dap.Session, event?: dap.StoppedEvent)>
---@field variables table<string, fun(session: dap.Session)>
---@field stackTrace table<string, fun(session: dap.Session, body?: dap.StackTraceResponse, request?: any)>
---@field exceptionInfo table<string, fun(session: dap.Session, body?: any, response?: dap.ExceptionInfoResponse)>

---@class dap.Listeners
---@field after dap.ListenerTable
---@field before dap.ListenerTable

---@class dap.Module
---@field listeners dap.Listeners
---@field session fun(): dap.Session|nil
---
---@class TSNode
---@field id fun(self: TSNode): integer
---@field start fun(self: TSNode): integer, integer, integer?
---@field range fun(self: TSNode): integer, integer, integer, integer
---@alias dap_virtual_text_chunk [string, string]
----@class dap_virtual_text_item: dap_virtual_text_chunk
----@field node TSNode
---@alias DapDisplayCallback fun(dap.Variable, integer, dap.StackFrame, TSNode, nvim_dap_virtual_text_options): string?
---@class nvim_dap_virtual_text_options
---@field enabled boolean
---@field all_frames boolean
---@field clear_on_continue boolean
---@field commented boolean
---@field only_first_definition boolean
---@field all_references boolean
---@field highlight_changed_variables boolean
---@field highlight_new_as_changed boolean
---@field show_stop_reason boolean
---@field virt_text_pos '"eol"'|'"inline"'|'"eos"'|string
---@field virt_lines boolean
---@field virt_lines_above boolean
---@field virt_text_win_col? integer
---@field text_prefix string
---@field separator string
---@field error_prefix string
---@field info_prefix string
---@field filter_references_pattern? string
---@field display_callback DapDisplayCallback
---

---@type table<integer, dap.StackFrame>
--local last_frames = {}
---@type dap.StackFrame|nil
--local stopped_frame = nil
---@type string|nil
--local error_set = nil
---@type string|nil
--local info_set = nil

----@param scopes dap.Scope[]?
----@param lang string
----@return table<string, { value: dap.Variable, presentationHint: string|nil }>
--local function variables_from_scopes(scopes, lang) end
----@param lang string
----@param query_name string
----@return vim.treesitter.Query|nil
--local function get_query(lang, query_name)
--  return vim.treesitter.query.get(lang, query_name)
--end
