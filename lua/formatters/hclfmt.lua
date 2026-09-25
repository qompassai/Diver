-- #################################################################
-- ~/.config/nvim/lua/formatters/hclfmt.lua
-- Qompass AI Diver Hclfmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://pkg.go.dev/github.com/haggishunk/hclfmt
---
--- A gofmt-like tidy-up robot for HCL (HashiCorp Configuration
--- Language) files. When called with no arguments it reads the
--- config from standard input and prints the tidied result to
--- standard output.

---@type FormatterSpec
return {
    cmd = 'hclfmt',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'hcl',
    decode = nil,
    pre_transform = nil,
}
