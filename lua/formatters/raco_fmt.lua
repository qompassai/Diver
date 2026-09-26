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
    cmd = 'raco',
    args = { 'fmt', '--width', '100' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'info.rkt', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'rkt',
    decode = nil,
    pre_transform = nil,
}
