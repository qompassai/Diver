-- #################################################################
-- ~/.config/nvim/lua/formatters/perltidy.lua
-- Qompass AI Diver Perltidy Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://metacpan.org/dist/Perl-Tidy/view/bin/perltidy
---
--- perltidy is the classic Perl source formatter. With no input
--- filename it reads Perl source from stdin and prints the tidied
--- source to stdout, using its built-in defaults.

---@type FormatterSpec
return {
    cmd = 'perltidy',
    args = {},
    mode = 'stdin',
    output = 'stdout',
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'pl',
}
