-- #################################################################
-- ~/.config/nvim/lua/formatters/fprettify.lua
-- Native fprettify Formatter Spec — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/pseewald/fprettify
---
--- fprettify tidies modern Fortran code (whitespace, indentation,
--- spacing around operators). The `--silent` flag is the documented
--- editor-integration mode: it reads the code from stdin, prints the
--- pretty version to stdout, and stays quiet instead of narrating
--- what it did.

---@type FormatterSpec
return {
    cmd = 'fprettify',
    args = { '--silent' },
    mode = 'stdin',
    output = 'stdout',
    root_markers = { '.git' },
    env = { NO_COLOR = '1' },
    exit_codes = { 0 },
    automatic = true,
    allow_empty = false,
    extension = 'f90',
}
