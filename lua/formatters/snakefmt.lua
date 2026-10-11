-- #################################################################
-- ~/.config/nvim/lua/formatters/snakefmt.lua
-- Qompass AI Diver snakefmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/snakemake/snakefmt
---
--- ELI5: snakefmt is the uncompromising formatter for Snakemake files.
--- Giving it `-` as the file name tells it to read your Snakefile
--- from stdin and print the formatted result to stdout, instead of
--- rewriting files in place (its default). Its own line-length and
--- sorting defaults are kept as-is.

---@type FormatterSpec
return {
    allow_empty = false,
    args = { '-' },
    automatic = true,
    cmd = 'snakefmt',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'smk',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'Snakefile', 'pyproject.toml', '.git' },
}
