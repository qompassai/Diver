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
    cmd = 'snakefmt',
    args = { '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'Snakefile', 'pyproject.toml', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'smk',
    decode = nil,
    pre_transform = nil,
}
