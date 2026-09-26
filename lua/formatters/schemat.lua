-- #################################################################
-- ~/.config/nvim/lua/formatters/schemat.lua
-- Qompass AI Diver schemat Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/raviqqe/schemat
---
--- ELI5: schemat tidies up Scheme-flavoured code (any S-expressions,
--- really). Its whole user manual is `schemat < in.scm > out.scm`: it
--- reads from stdin and writes the formatted code to stdout, no flags
--- needed.

---@type FormatterSpec
return {
    cmd = 'schemat',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'scm',
    decode = nil,
    pre_transform = nil,
}
