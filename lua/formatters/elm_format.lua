-- #################################################################
-- ~/.config/nvim/lua/formatters/elm_format.lua
-- Native elm-format Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/avh4/elm-format/issues/560
---
--- elm-format tidies Elm code. The `--stdin` flag tells it to read the
--- code from the pipe and print the pretty version to stdout, so no
--- temporary files are needed: Elm in, prettier Elm out.

---@type FormatterSpec
return {
    cmd = 'elm-format',
    args = { '--stdin' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { 'elm.json', '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'elm',
}
