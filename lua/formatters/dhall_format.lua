-- #################################################################
-- ~/.config/nvim/lua/formatters/dhall_format.lua
-- Native dhall format Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://hackage.haskell.org/package/dhall-1.42.2/docs/Dhall-Tutorial.html
---
--- Dhall is a configuration language, and the `dhall` program's
--- `format` command is its tidier. Think of it as a photocopier with
--- a "straighten" button: Dhall code goes in through stdin, and the
--- same code comes out of stdout with every indent and space put in
--- its proper place. (The adapter keeps the historical `dhall_format`
--- name; the binary it calls is `dhall`.)

---@type FormatterSpec
return {
    cmd = 'dhall',
    args = { 'format' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'dhall',
}
