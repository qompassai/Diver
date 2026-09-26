-- #################################################################
-- ~/.config/nvim/lua/formatters/rubyfmt.lua
-- Qompass AI Diver rubyfmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/fables-tales/rubyfmt
---
--- ELI5: rubyfmt formats Ruby code the way its authors like it -- no
--- knobs, no config file, no arguments to get wrong. It reads your
--- code from stdin and prints the formatted code to stdout.

---@type FormatterSpec
return {
    cmd = 'rubyfmt',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'rb',
    decode = nil,
    pre_transform = nil,
}
