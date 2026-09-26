-- #################################################################
-- ~/.config/nvim/lua/formatters/hledger_fmt.lua
-- Qompass AI Diver hledger-fmt Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/mondeja/hledger-fmt/blob/HEAD/README.md
---
--- A tidy-up robot for hledger journal files: it lines up the
--- amounts in neat columns so your money ledger is easy to read.
--- The lone `-` tells it to read the journal from standard input
--- and print the tidied result to standard output.
--- `--no-diff` keeps it quiet (no patch printed), and
--- `--exit-zero-on-changes` makes it always exit 0 even when it
--- changed something, so we only ever see exit code 0 here.

---@type FormatterSpec
return {
    cmd = 'hledger-fmt',
    args = { '-', '--no-diff', '--exit-zero-on-changes' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = {},
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'journal',
    decode = nil,
    pre_transform = nil,
}
