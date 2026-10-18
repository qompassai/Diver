-- ~/.config/nvim/lua/formatters/panache.lua
-- Qompass AI Diver Panache Native Formatter Spec
---@module 'formatters.panache'
---@source https://github.com/jolars/panache
---
--- Panache formats Markdown, Quarto (.qmd) and R Markdown (.Rmd)
--- documents. `panache format` with piped input and no file argument
--- reads the document from stdin and prints the formatted document
--- to stdout.

---@type FormatterSpec
return {
    allow_empty = false,
    args = { 'format' },
    automatic = true,
    cmd = 'panache',
    exit_codes = { 0 },
    extension = 'md',
    mode = 'stdin',
    output = 'stdout',
}
