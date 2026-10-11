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
    allow_empty = false,
    args = {},
    automatic = true,
    cmd = 'rubyfmt',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'rb',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { '.git' },
}
