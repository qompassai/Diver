-- #################################################################
-- ~/.config/nvim/lua/formatters/raco_fmt.lua
-- Qompass AI Diver raco fmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://docs.racket-lang.org/fmt/index.html
---
--- ELI5: `raco fmt` is the Racket code formatter. Called with no file
--- arguments it reads your program from stdin and prints the formatted
--- program to stdout. `--width 100` keeps lines within 100 columns.
--- (`--indent` is left alone: it sets the first line's indentation,
--- not the normal nesting width.)

---@type FormatterSpec
return {
    allow_empty = false,
    args = { 'fmt', '--width', '100' },
    automatic = true,
    cmd = 'raco',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'rkt',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'info.rkt', '.git' },
}
