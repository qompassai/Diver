-- #################################################################
-- ~/.config/nvim/lua/formatters/refmt.lua
-- Qompass AI Diver refmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/reasonml/reasonml.github.io/blob/HEAD/docs/refmt.md
---
--- ELI5: refmt is the Reason language's parser and pretty-printer. With
--- no file names it reads Reason code from stdin and prints the
--- formatted code to stdout. `--parse=re --print=re` keeps it speaking
--- Reason (rather than OCaml syntax), and `--print-width=100` matches
--- the 100-column style.

---@type FormatterSpec
return {
    allow_empty = false,
    args = { '--parse=re', '--print=re', '--print-width=100' },
    automatic = true,
    cmd = 'refmt',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 're',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { 'bsconfig.json', '.git' },
}
