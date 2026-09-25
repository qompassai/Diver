-- #################################################################
-- ~/.config/nvim/lua/formatters/purs_tidy.lua
-- Qompass AI Diver purs-tidy Native Formatter Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- #################################################################
---@source https://github.com/i-am-the-slime/purescript-tidy
---
--- ELI5: purs-tidy is the tidy-up robot for PureScript code.
--- `purs-tidy format` reads your code from stdin and prints the
--- tidied code to stdout. It is opinionated on purpose: with no extra
--- flags it uses its built-in style (or your project's `.tidyrc.json`
--- when one exists), so no indent or width flags are forced here.

---@type FormatterSpec
return {
    cmd = 'purs-tidy',
    args = { 'format' },
    mode = 'stdin',
    output = 'stdout',
    cwd = nil,
    env = {},
    root_markers = { '.tidyrc.json', 'spago.yaml', 'spago.dhall', '.git' },
    exit_codes = { 0 },
    allow_empty = false,
    automatic = true,
    extension = 'purs',
    decode = nil,
    pre_transform = nil,
}
