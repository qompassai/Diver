-- /qompassai/Diver/lua/types/core/lint.lua
-- Qompass AI Diver Native Linter Types
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- -------------------------------------------------------------------------
---@meta

---@class LintContext
---@field bufnr                                  integer Buffer receiving diagnostics.
---@field cwd string Default working directory for the linter process.
---@field filename string Normalized absolute buffer filename.
---@field filetype string Current Neovim buffer filetype.
---@field modified boolean Whether the buffer contains unsaved changes.
---@field root string Detected project root.

---@alias LintArgs string[]|fun(context: LintContext): string[]
---@alias LintBufferParser fun(output: string, bufnr: integer): vim.Diagnostic.Set[]
---@alias LintContextParser fun(output: string, context: LintContext): vim.Diagnostic.Set[]
---@alias LintCwd string|fun(context: LintContext): string
---@alias LintParser LintBufferParser|LintContextParser
---@alias LintStream 'both'|'stderr'|'stdout'

---@class Linter
---@field append_fname? boolean Append `context.filename`; defaults to true.
---@field args? LintArgs Static arguments or a context-aware argument callback.
---@field automatic? boolean Permit automatic buffer-event execution; defaults to true.
---@field cmd string|string[] Executable name or ordered executable candidates.
---@field cwd? LintCwd Static or context-aware process working directory.
---@field env? table<string, string> Additional process environment variables.
---@field errorformat? string|string[] Vim errorformat used when `parser` is absent.
---@field exit_codes? integer[]|table<integer, boolean> Accepted process exit codes.
---@field ignore_exitcode? boolean Accept every process exit code.
---@field parser? LintParser Diagnostic output parser.
---@field root_markers? string[] Project-root markers passed to `vim.fs.root()`.
---@field stdin? boolean Send the current buffer through standard input.
---@field stream? LintStream Diagnostic stream; defaults to stdout.
---@field timeout? integer Process timeout in milliseconds.

-- Compatibility for specifications that still use the nvim-lint-style name.
-- Runtime behavior remains defined by `Linter`; the additional fields below
-- preserve metadata used by older Qompass AI linter and report definitions.
---@class vim.lint.Config : Linter
---@field code? string Legacy diagnostic or report code.
---@field column? integer|string Legacy diagnostic column.
---@field file_name? string Legacy diagnostic filename.
---@field kind? string Legacy diagnostic kind.
---@field level? string Legacy diagnostic level.
---@field line? integer|string Legacy diagnostic line.
---@field message? string Legacy diagnostic message.
---@field msg? string Legacy diagnostic message alias.
---@field name? string Legacy linter or report name.
---@field path? string Legacy diagnostic path.
---@field severity? string Legacy textual severity.
---@field start_col? integer Legacy diagnostic starting column.

---@class vim.lint.Config.ReportItem
---@field column? integer
---@field file_name? string
---@field kind? string
---@field line? integer
---@field message? string
---@field path? string
---@field start_col? integer

---@alias vim.lint.Config.Report vim.lint.Config.ReportItem[]

---@class vim.lint.Diagnostic : vim.Diagnostic.Set

---@class vim.lint.LintProc
---@field bufnr? integer
---@field cancelled? boolean
---@field ns? integer
---@field proc? vim.SystemObj
---@field stream? LintStream

---@class lint.TSQueryConfig : vim.lint.Config
---@field name? string

-- Compatibility alias for older specifications. Neovim's canonical type is
-- `vim.diagnostic.Severity`.
---@alias vim.Diagnostic.SeverityValue vim.diagnostic.Severity