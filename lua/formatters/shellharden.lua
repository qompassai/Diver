-- #################################################################
-- ~/.config/nvim/lua/formatters/shellharden.lua
-- Qompass AI Diver shellharden Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/anordal/shellharden
---
--- ELI5: Shellharden rewrites shell scripts so their quoting is
--- ShellCheck-clean (unquoted `$vars` become `"$vars"`). Passing `''`
--- as the file name means "read from stdin", and `--transform` prints
--- the rewritten script to stdout instead of changing files.
--- Marked manual, not automatic: it changes quoting, which can change
--- what a script does -- run it on purpose, not on every save.

---@type FormatterSpec
return {
    cmd = 'shellharden',
    args = { '--transform', '' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = false,
    extension = 'sh',
    decode = nil,
    pre_transform = nil,
}
