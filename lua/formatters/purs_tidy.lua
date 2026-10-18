-- ~/.config/nvim/lua/formatters/purs_tidy.lua
-- Qompass AI Diver purs-tidy Native Formatter Spec
---@module 'formatters.purs_tidy'
---@source https://github.com/i-am-the-slime/purescript-tidy
---
--- ELI5: purs-tidy is the tidy-up robot for PureScript code.
--- `purs-tidy format` reads your code from stdin and prints the
--- tidied code to stdout. It is opinionated on purpose: with no extra
--- flags it uses its built-in style (or your project's `.tidyrc.json`
--- when one exists), so no indent or width flags are forced here.

---@type FormatterSpec
return {
    allow_empty = false,
    args = { 'format' },
    automatic = true,
    cmd = 'purs-tidy',
    cwd = nil,
    decode = nil,
    env = {},
    exit_codes = { 0 },
    extension = 'purs',
    mode = 'stdin',
    output = 'stdout',
    pre_transform = nil,
    root_markers = { '.tidyrc.json', 'spago.yaml', 'spago.dhall', '.git' },
}
