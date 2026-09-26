-- #################################################################
-- ~/.config/nvim/lua/formatters/just_fmt.lua
-- Qompass AI Diver Just Format Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/casey/just
---
--- The `just` command runner can tidy up its own justfiles:
--- `--fmt --unstable` switches on the built-in formatter, and
--- `--justfile -` makes it read the justfile from standard input
--- and print the tidied result to standard output.

---@type FormatterSpec
return {
    cmd = 'just',
    args = { '--fmt', '--unstable', '--justfile', '-' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'just',
    decode = nil,
    pre_transform = nil,
}
