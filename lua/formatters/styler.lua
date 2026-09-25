-- #################################################################
-- ~/.config/nvim/lua/formatters/styler.lua
-- Qompass AI Diver styler Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/r-lib/styler
---
--- ELI5: styler is R's tidyverse-style formatter, but it is an R
--- package, not a command -- so the runner asks `Rscript` to run it.
--- The little R program below reads your code from stdin, styles it
--- with `styler::style_text()`, and prints the result back out.
--- `--vanilla` keeps your personal R settings out of the way. The R
--- code travels as one plain argument (never a shell string).

-- One R expression, passed to Rscript as a single -e argument.
local r_expression = "con <- file('stdin'); "
    .. 'out <- styler::style_text(readLines(con)); '
    .. "cat(paste(out, collapse = '\\n'), '\\n', sep = '')"

---@type FormatterSpec
return {
    cmd = 'Rscript',
    args = { '--vanilla', '-e', r_expression },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { 'DESCRIPTION', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'R',
    decode = nil,
    pre_transform = nil,
}
