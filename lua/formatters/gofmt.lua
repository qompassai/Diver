-- #################################################################
-- ~/.config/nvim/lua/formatters/gofmt.lua
-- Qompass AI Diver Gofmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://manpages.debian.org/unstable/gccgo-go/gofmt.1.en.html
---
--- Go's own tidy-up robot: it reads your Go code and prints it back
--- in Go's one true style, so every Go file looks the same.
--- Given no file names, gofmt reads from standard input and writes
--- the tidied code to standard output (it only rewrites files when
--- you pass -w, which this spec never does).

---@type FormatterSpec
return {
    cmd = 'gofmt',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'go',
    decode = nil,
    pre_transform = nil,
}
