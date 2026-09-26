-- #################################################################
-- ~/.config/nvim/lua/formatters/panache.lua
-- Qompass AI Diver Panache Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/jolars/panache
---
--- Panache formats Markdown, Quarto (.qmd) and R Markdown (.Rmd)
--- documents. `panache format` with piped input and no file argument
--- reads the document from stdin and prints the formatted document
--- to stdout.

---@type FormatterSpec
return {
    cmd = 'panache',
    args = { 'format' },
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'md',
}
