-- #################################################################
-- ~/.config/nvim/lua/formatters/findent.lua
-- Native findent Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://pypi.org/project/findent/4.1.3/
---
--- findent tidies Fortran code. With no file arguments it reads the
--- code from stdin and prints the tidied code to stdout. The `-i4`
--- flag asks for four-space indentation, matching the tiger-style
--- used everywhere else in this config.

---@type FormatterSpec
return {
    cmd = 'findent',
    args = { '-i4' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'f90',
}
