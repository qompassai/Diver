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
    allow_empty = false,
    args = {},
    automatic = true,
    cmd = 'schemat',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'scm',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { '.git' },
}
