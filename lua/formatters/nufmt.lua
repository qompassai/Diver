-- #################################################################
-- ~/.config/nvim/lua/formatters/nufmt.lua
-- Qompass AI Diver Nufmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/nushell/nufmt
---
--- nufmt is the official Nushell code formatter. `--stdin` makes it
--- read Nushell source from stdin and print the formatted source to
--- stdout. (The older psychollama/nufmt redirect points here; this
--- is the canonical nushell/nufmt binary.)

---@type FormatterSpec
return {
    cmd = 'nufmt',
    args = { '--stdin' },
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'nu',
}
