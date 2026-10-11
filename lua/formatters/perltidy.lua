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
    allow_empty = false,
    args = {},
    automatic = true,
    cmd = 'perltidy',
    exit_codes = { 0 },
    extension = 'pl',
    mode = 'stdin',
    output = 'stdout',
}
